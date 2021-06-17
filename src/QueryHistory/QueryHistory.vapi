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

namespace Synapse {
    [Compact (opaque = true)]
    [CCode (free_function = "synapse_query_history_free", cheader_filename = "queryHistory.h")]
    public class QueryHistory {
        public QueryHistory (string db_path, GLib.Cancellable? cancellable = null) throws GLib.Error;

        public GLib.HashTable<string, int> history_for_prefix (string prefix);

        public bool add_query (string query, string hash, GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
