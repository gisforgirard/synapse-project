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

#include "queryHistory.h"
#include "queryHistoryController.h"

SynapseQueryHistory*
synapse_query_history_new(const gchar   *data_dir_path,
                          GCancellable  *cancellable,
                          GError       **error)
{
  Synapse::QueryHistoryController *controller;
  GError *inner_error;

  controller = new Synapse::QueryHistoryController(data_dir_path);
  inner_error = NULL;

  controller->Initialize(cancellable, &inner_error);

  if (inner_error)
    {
      delete controller;
      g_propagate_error(error, inner_error);
      return NULL;
    }

  return (SynapseQueryHistory*)controller;
}

void
synapse_query_history_free(SynapseQueryHistory* query_history)
{
  g_return_if_fail(query_history != NULL);

  delete (Synapse::QueryHistoryController*)query_history;
}

GHashTable*
synapse_query_history_history_for_prefix(SynapseQueryHistory *query_history,
                                         const gchar         *prefix)
{
  Synapse::QueryHistoryController* controller;

  controller = (Synapse::QueryHistoryController*)query_history;

  return controller->HistoryForPrefix(prefix);
}

gboolean
synapse_query_history_add_query(SynapseQueryHistory *query_history,
                                const gchar         *query,
                                const gchar         *hash,
                                GCancellable        *cancellable,
                                GError             **error)
{
  Synapse::QueryHistoryController* controller;

  controller = (Synapse::QueryHistoryController*)query_history;

  return controller->AddQuery(query, hash, cancellable, error);
}
