/*
 * Copyright (c) 2021 Payson Wallach <payson@paysonwallach.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Synapse.RelevancyBackendAlpha {
    private class LanguageModel : Gee.HashMap<string, int> {}

    private static Gee.ArrayList<string> get_fields_for_match (Match match) {
        var results = new Gee.ArrayList<string> ();

        var type = Type.from_instance (match);
        var object_class = (ObjectClass) type.class_ref ();
        foreach (ParamSpec spec in object_class.list_properties ())
            if (spec.value_type == typeof (string))
                results.add (spec.name);

        return results;
    }

    public ResultSet merge_results (Gee.ArrayList<ResultSet> sets, string query) {
        var results = new ResultSet ();
        var set_relevancies = new Gee.HashMap<ResultSet, int> ();

        foreach (var set in sets)
            set_relevancies[set] = get_set_relevancy (set, query);

        var min_set_relevancy = int.MAX;
        var max_set_relevancy = int.MIN;
        foreach (var relevancy in set_relevancies.values) {
            if (relevancy < min_set_relevancy)
                min_set_relevancy = relevancy;
            else if (relevancy > max_set_relevancy)
                max_set_relevancy = relevancy;
        }

        foreach (var set in sets) {
            if (max_set_relevancy > 0 && max_set_relevancy != min_set_relevancy)
                set_relevancies[set] = (set_relevancies[set] - min_set_relevancy) / (max_set_relevancy - min_set_relevancy);
        }

        foreach (var set in sets) {
            foreach (var match in set) {
                var rank = (int) Math.round ((match.value + 0.4 * match.value * set_relevancies[set]) / 1.4);
                if (rank > 0)
                    results.add (match.key, rank);
            }
        }

        return results;
    }

    public int get_set_relevancy (ResultSet set, string query) {
        var query_terms = query.split (" ");
        var field_rankings = new Gee.ArrayList<int> ();
        var unigram_frequencies = new LanguageModel ();
        var unique_word_count = 0;
        var corpus_length = 0;
        var fields = get_fields_for_match (set.keys.to_array ()[0]);

        int ranking = 1;
        foreach (var field in fields) {
            foreach (var match in set.keys) {
                string field_value;
                match.@get (field, out field_value);
                if (field_value == null)
                    continue;
                foreach (var word in field_value.split (" ")) {
                    unigram_frequencies[word] += 1;
                    corpus_length += 1;
                }
            }
            unique_word_count = unigram_frequencies.size;

            foreach (var term in query_terms) {
                ranking *= (unigram_frequencies[term] / (corpus_length + unique_word_count));
            }
            field_rankings.add (ranking);
        }

        return field_rankings.fold<int>((a, g) => { return g + a; }, 0) / field_rankings.size;
    }

    private void normalize_match_scores (ResultSet set) {
        var min_match_relevancy = (int) MatchScore.HIGHEST;
        var max_match_relevancy = 0;
        foreach (var relevancy in set) {
            if (relevancy.value > 0)
                if (relevancy.value < min_match_relevancy)
                    min_match_relevancy = relevancy.value;
                else if (relevancy.value > max_match_relevancy)
                    max_match_relevancy = relevancy.value;
        }

        foreach (var match in set) {
            if (max_match_relevancy != min_match_relevancy)
                match.value = (match.value - min_match_relevancy) / (max_match_relevancy - min_match_relevancy) * max_match_relevancy;
            else
                match.value = min_match_relevancy;
        }
    }

}
