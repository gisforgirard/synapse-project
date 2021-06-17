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

#include "queryHistoryController.h"

namespace Synapse {
static void tracker_notifier_event_cb(TrackerNotifier *notifier,
                                      const gchar     *service,
                                      const gchar     *graph,
                                      GPtrArray       *events,
                                      gpointer user_data)
{
  tsl::htrie_map<char, std::unordered_map<std::string, guint> > *history = (tsl::htrie_map<char, std::unordered_map<std::string, guint> >*)user_data;

  for (unsigned i = 0; i < events->len; i++)
    {
      TrackerNotifierEvent *event = (TrackerNotifierEvent*)g_ptr_array_index(events, i);
      if (tracker_notifier_event_get_event_type(event) == TRACKER_NOTIFIER_EVENT_CREATE)
        {
          auto selection = tracker_resource_new(tracker_notifier_event_get_urn(event));
          auto query = tracker_resource_get_first_relation(selection, "synapse:hasQuery");
          auto match = tracker_resource_get_first_relation(selection, "synapse:hasMatch");

          auto key = tracker_resource_get_first_string(query, "synapse:queryString");
          auto hash = tracker_resource_get_first_string(match, "synapse:hash");

          auto it = history->find(key);
          if (it != history->end())
            {
              it.value()[hash] += 1;
            }
          else
            {
              std::unordered_map<std::string, guint> map = { { hash, 1 } };
              history->insert(key, map);
            }
        }
    }
}

gboolean QueryHistoryController::Initialize(GCancellable  *cancellable,
                                            GError       **error)
{
  GFile *store, *ontology;
  GError *inner_error = NULL;

  store = g_file_new_build_filename(data_dir_path, "store", NULL);
  ontology = g_file_new_build_filename(data_dir_path, "ontologies", NULL);
  connection = tracker_sparql_connection_new(TRACKER_SPARQL_CONNECTION_FLAGS_NONE,
                                             store,
                                             ontology,
                                             cancellable,
                                             &inner_error);
  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  TrackerNamespaceManager *namespace_manager = tracker_namespace_manager_get_default();

  tracker_namespace_manager_add_prefix(namespace_manager,
                                       "synapse",    // NAMESPACE_PREFIX,
                                       "http://paysonwallach.com/synapse#");    //NAMESPACE_URL);

  notifier = tracker_sparql_connection_create_notifier(connection);
  g_signal_connect(notifier, "events", G_CALLBACK(tracker_notifier_event_cb), (gpointer)history);

  history = new tsl::htrie_map<char, std::unordered_map<std::string, guint> > ();

  auto query = ("SELECT"
                "  ?qs ?mh count(?selection)"
                "WHERE {"
                "  ?query synapse:queryString ?qs ."
                "  ?query synapse:hasSelection ?selection ."
                "  ?selection synapse:hasMatch ?match ."
                "  ?match synapse:hash ?mh"
                "} GROUP BY ?match");
  auto cursor = tracker_sparql_connection_query(connection,
                                                query,
                                                cancellable,
                                                &inner_error);

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  while (tracker_sparql_cursor_next(cursor, cancellable, &inner_error))
    {
      auto key = tracker_sparql_cursor_get_string(cursor, 0, NULL);
      auto hash = tracker_sparql_cursor_get_string(cursor, 1, NULL);
      auto count = tracker_sparql_cursor_get_integer(cursor, 2);

      std::unordered_map<std::string, guint> map = { { hash, count } };
      history->insert(key, map);
    }

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  return TRUE;
}

gboolean QueryHistoryController::AddQuery(const gchar   *key,
                                          const gchar   *hash,
                                          GCancellable  *cancellable,
                                          GError       **error)
{
  TrackerResource * query_resource, *selection_resource, *match_resource;
  gchar *identifier = NULL;
  gchar *query;
  GError *inner_error = NULL;

  query = g_strdup_printf("SELECT ?q "
                          "WHERE {"
                          "  ?q a synapse:Query ."
                          "  ?q synapse:queryString \"%s\""
                          "}",
                          key);

  auto cursor = tracker_sparql_connection_query(connection,
                                                query,
                                                cancellable,
                                                &inner_error);

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  if (tracker_sparql_cursor_next(cursor, NULL, NULL))
    identifier = g_strdup(tracker_sparql_cursor_get_string(cursor, 0, NULL));

  query_resource = tracker_resource_new(identifier);

  if (identifier == NULL)
    {
      tracker_resource_add_uri(query_resource, "rdf:type", "synapse:Query");
      tracker_resource_add_string(query_resource, "synapse:queryString", key);
    }

  selection_resource = tracker_resource_new(NULL);

  tracker_resource_add_uri(selection_resource, "rdf:type", "synapse:Selection");
  tracker_resource_add_string(selection_resource, "synapse:selectionDate",
                              g_date_time_format_iso8601(g_date_time_new_now_local()));

  identifier = NULL;
  query = g_strdup_printf("SELECT ?m "
                          "WHERE {"
                          "  ?m a synapse:Match ."
                          "  ?m synapse:hash \"%s\""
                          "}",
                          hash);
  cursor = tracker_sparql_connection_query(connection,
                                           query,
                                           cancellable,
                                           &inner_error);

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  if (tracker_sparql_cursor_next(cursor, NULL, NULL))
    identifier = g_strdup(tracker_sparql_cursor_get_string(cursor, 0, NULL));

  match_resource = tracker_resource_new(identifier);

  if (identifier == NULL)
    {
      tracker_resource_add_uri(match_resource, "rdf:type", "synapse:Match");
      tracker_resource_add_string(match_resource, "synapse:hash", hash);

      tracker_sparql_connection_update_resource(connection,
                                                NULL,
                                                match_resource,
                                                cancellable,
                                                &inner_error);

      if (inner_error)
        {
          g_propagate_error(error, inner_error);
          return FALSE;
        }
    }

  tracker_resource_add_relation(selection_resource, "synapse:hasMatch", match_resource);
  tracker_resource_add_relation(query_resource, "synapse:hasSelection", selection_resource);

  tracker_sparql_connection_update_resource(connection,
                                            NULL,
                                            selection_resource,
                                            cancellable,
                                            &inner_error);

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  tracker_sparql_connection_update_resource(connection,
                                            NULL,
                                            query_resource,
                                            cancellable,
                                            &inner_error);

  if (inner_error)
    {
      g_propagate_error(error, inner_error);
      return FALSE;
    }

  return TRUE;
}

GHashTable* QueryHistoryController::HistoryForPrefix(const gchar *prefix)
{
  auto retval = g_hash_table_new(g_str_hash, g_str_equal);
  auto prefix_range = history->equal_prefix_range(prefix);

  for (auto prefix_iter = prefix_range.first; prefix_iter != prefix_range.second; prefix_iter++)
    {
      for (auto &it : *prefix_iter)
        {
          auto frequency = GPOINTER_TO_UINT(g_hash_table_lookup(retval, it.first.c_str()));
          g_hash_table_replace(retval, g_strdup(it.first.c_str()), GUINT_TO_POINTER(frequency + it.second));
        }
    }

  return retval;
}
}
