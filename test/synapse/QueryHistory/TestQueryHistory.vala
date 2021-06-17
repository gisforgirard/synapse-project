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

class Synapse.TestQueryHistory : ValaUnit.TestCase {
    private QueryHistory? query_history = null;

    public TestQueryHistory () {
        base ("TestQueryHistory");

        add_test ("add_query", add_query);
        add_test ("history_for_prefix", history_for_prefix);
        add_test ("history_for_prefix2", history_for_prefix2);
    }

    public override void set_up () throws Error {
        query_history = new QueryHistory (
            Path.build_filename (
                Environment.get_home_dir (), "queryHistory.xml"));
    }

    public override void tear_down () throws Error {
        query_history = null;
    }

    public void add_query () throws Error {
        assert_true (
            query_history.add_query ("foo", "bar"),
            "query was not added");
    }

    public void history_for_prefix () throws Error {
        query_history.add_query ("foo", "bar");
        query_history.add_query ("fo", "bar");

        var actual = query_history.history_for_prefix ("fo");
        var actual_val = actual.get ("bar").to_string ();

        assert_equal (actual_val, "2", "results differ");
    }

    public void history_for_prefix2 () throws Error {
        query_history.add_query ("foo", "bar");
        query_history.add_query ("fo", "bar");
        query_history.add_query ("foo", "baz");

        var actual = query_history.history_for_prefix ("fo");
        var actual_val = actual.get ("bar").to_string ();
        var actual_val2 = actual.get ("baz").to_string ();

        assert_equal (actual_val, "2", "`bar` value differs");
        assert_equal (actual_val2, "1", "`baz` value differs");
    }

}
