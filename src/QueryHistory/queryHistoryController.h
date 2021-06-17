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

#ifndef SYNAPSE_QUERY_HISTORY_CONTROLLER_H
#define SYNAPSE_QUERY_HISTORY_CONTROLLER_H

#include <unordered_map>

#include <glib.h>
#include <gio/gio.h>
#include <libtracker-sparql/tracker-sparql.h>
#include <tsl/htrie_map.h>

namespace Synapse {
class QueryHistoryController {
public:
QueryHistoryController (const gchar *_data_dir_path)
{
  if (_data_dir_path)
    data_dir_path = g_strdup(_data_dir_path);
}

~QueryHistoryController ()
{
  if (history)
    delete history;
}

gboolean Initialize(GCancellable *cancellable, GError **error);
gboolean AddQuery(const gchar *key, const gchar *hash, GCancellable *cancellable, GError **error);
GHashTable* HistoryForPrefix(const gchar *prefix);

private:
const gchar *data_dir_path;
tsl::htrie_map<char, std::unordered_map<std::string, guint> > *history;
TrackerSparqlConnection *connection;
TrackerNotifier *notifier;
};
}

#endif /* SYNAPSE_QUERY_HISTORY_CONTROLLER_H */
