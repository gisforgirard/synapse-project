/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 */

namespace Synapse {
    public class DataSink : Object, SearchProvider {
        private class DataSinkConfiguration : ConfigObject {
            // vala keeps array lengths, and therefore doesn't support setting arrays
            // via automatic public properties
            private string[] _disabled_plugins = null;
            public string[] disabled_plugins {
                get {
                    return _disabled_plugins;
                }
                set {
                    _disabled_plugins = value;
                }
            }

            public void set_plugin_enabled (Type t, bool enabled) {
                if (enabled)
                    enable_plugin (t.name ());
                else
                    disable_plugin (t.name ());
            }

            public bool is_plugin_enabled (Type t) {
                if (_disabled_plugins == null)
                    return true;

                unowned string plugin_name = t.name ();

                foreach (string s in _disabled_plugins) {
                    if (s == plugin_name)
                        return false;
                }

                return true;
            }

            private void enable_plugin (string name) {
                if (_disabled_plugins == null)
                    return;

                if (!(name in _disabled_plugins))
                    return;

                string[] cpy = {};

                foreach (string s in _disabled_plugins) {
                    if (s != name)
                        cpy += s;
                }

                _disabled_plugins = (owned) cpy;
            }

            private void disable_plugin (string name) {
                if (_disabled_plugins == null || !(name in _disabled_plugins))
                    _disabled_plugins += name;
            }

        }

        public DataSink () {}

        ~DataSink () {
            debug ("DataSink died...");
        }

        private DataSinkConfiguration config;
        private Gee.Set<ItemProvider> item_plugins;
        private Gee.Set<ActionProvider> action_plugins;
        private uint query_id;
        // data sink will keep reference to the name cache, so others will get this
        // instance on call to get_default()
        private DBusService dbus_name_cache;
        private DesktopFileService desktop_file_service;
        private PluginRegistry registry;
        private RelevancyService relevancy_service;
        private VolumeService volume_service;
        private Type[] plugin_types;

        construct {
            item_plugins = new Gee.HashSet<ItemProvider> ();
            action_plugins = new Gee.HashSet<ActionProvider> ();
            plugin_types = {};
            query_id = 0;

            var cfg = ConfigService.get_default ();
            config = (DataSinkConfiguration)
                     cfg.get_config ("data-sink", "global", typeof (DataSinkConfiguration));

            // TODO: should these be singletons ?
            registry = PluginRegistry.get_default ();
            relevancy_service = RelevancyService.get_default ();
            volume_service = VolumeService.get_default ();
            info ("initializing caches...");
            initialize_caches.begin ();

            register_static_plugin (typeof (CommonActions));
        }

        private async void initialize_caches () {
            Idle.add (initialize_caches.callback, Priority.LOW);
            yield;

            int initialized_components = 0;
            int NUM_COMPONENTS = 2;

            dbus_name_cache = DBusService.get_default ();
            dbus_name_cache.initialize.begin (() => {
                initialized_components++;

                if (initialized_components >= NUM_COMPONENTS)
                    initialize_caches.callback ();
            });

            desktop_file_service = DesktopFileService.get_default ();

            desktop_file_service.initialize.begin (() => {
                initialized_components++;

                if (initialized_components >= NUM_COMPONENTS)
                    initialize_caches.callback ();
            });

            yield;

            Idle.add (() => {
                this.load_plugins ();
                return Source.REMOVE;
            });
        }

        public bool has_empty_handlers { get; set; default = false; }
        public bool has_unknown_handlers { get; set; default = false; }

        private bool plugins_loaded = false;

        public signal void plugin_registered (Object plugin);

        protected void register_plugin (Object plugin) {
            if (plugin is ActionProvider) {
                unowned ActionProvider action_plugin = (ActionProvider) plugin;

                action_plugins.add (action_plugin);
                has_unknown_handlers |= action_plugin.handles_unknown ();
            }

            if (plugin is ItemProvider) {
                unowned ItemProvider item_plugin = (ItemProvider) plugin;

                item_plugins.add (item_plugin);
                has_empty_handlers |= item_plugin.handles_empty_query ();
            }

            plugin_registered (plugin);
        }

        private void update_has_unknown_handlers () {
            bool tmp = false;

            foreach (var action in action_plugins) {
                if (action.enabled && action.handles_unknown ()) {
                    tmp = true;
                    break;
                }
            }

            has_unknown_handlers = tmp;
        }

        private void update_has_empty_handlers () {
            bool tmp = false;

            foreach (var item_plugin in item_plugins) {
                if (item_plugin.enabled && item_plugin.handles_empty_query ()) {
                    tmp = true;
                    break;
                }
            }

            has_empty_handlers = tmp;
        }

        private Object? create_plugin (Type t) {
            var obj_class = (ObjectClass) t.class_ref ();

            if (obj_class != null && obj_class.find_property ("data-sink") != null)
                return Object.new (t, "data-sink", this, null);
            else
                return Object.new (t, null);
        }

        private async void load_plugins () {
            foreach (Type t in plugin_types) {
                t.class_ref (); // makes the plugin register itself into PluginRegistry

                PluginInfo? info = registry.get_plugin_info_for_type (t);
                bool skip = info != null && info.runnable == false;

                if (config.is_plugin_enabled (t) && !skip) {
                    var plugin = create_plugin (t);

                    register_plugin (plugin);
                    ((Activatable) plugin).activate ();
                }
            }

            plugins_loaded = true;
        }

        /* This needs to be called right after instantiation,
         * if plugins_loaded == true, it won't have any effect. */
        public void register_static_plugin (Type plugin_type) {
            if (plugin_type in plugin_types)
                return;

            plugin_types += plugin_type;
        }

        public unowned Object? get_plugin (string name) {
            unowned Object? result = null;

            foreach (var plugin in item_plugins) {
                if (plugin.get_type ().name () == name) {
                    result = plugin;
                    break;
                }
            }

            return result;
        }

        public bool is_plugin_enabled (Type plugin_type) {
            foreach (var plugin in item_plugins) {
                if (plugin.get_type () == plugin_type) return plugin.enabled;
            }

            foreach (var action in action_plugins) {
                if (action.get_type () == plugin_type) return action.enabled;
            }

            return false;
        }

        public void set_plugin_enabled (Type plugin_type, bool enabled) {
            // save it into our config object
            config.set_plugin_enabled (plugin_type, enabled);
            ConfigService.get_default ().set_config ("data-sink", "global", config);

            foreach (var plugin in item_plugins) {
                if (plugin.get_type () == plugin_type) {
                    plugin.enabled = enabled;

                    if (enabled)
                        plugin.activate ();
                    else
                        plugin.deactivate ();

                    update_has_empty_handlers ();

                    return;
                }
            }

            foreach (var action in action_plugins) {
                if (action.get_type () == plugin_type) {
                    action.enabled = enabled;

                    if (enabled)
                        action.activate ();
                    else
                        action.deactivate ();

                    update_has_unknown_handlers ();

                    return;
                }
            }

            // plugin isn't instantiated yet
            if (enabled) {
                var new_instance = create_plugin (plugin_type);

                register_plugin (new_instance);
                ((Activatable) new_instance).activate ();
            }
        }

        [Signal (detailed = true)]
        public signal void search_done (ResultSet rs, uint query_id);

        private Gee.HashMap<string, ResultSet> results_sets = new Gee.HashMap<string, ResultSet> ();
        private RelevancyBackendAlpha relevancy_backend = new RelevancyBackendAlpha ();
        public async Gee.List<Match> search (string query,
                                             QueryFlags flags,
                                             ResultSet? dest_result_set,
                                             Cancellable? cancellable = null) throws SearchError {
            // wait for our initialization
            while (!plugins_loaded) {
                Timeout.add (100, search.callback);
                yield;

                if (cancellable != null && cancellable.is_cancelled ())
                    throw new SearchError.SEARCH_CANCELLED ("Cancelled");
            }

            var q = Query (query_id++, query, flags);
            string query_stripped = query.strip ();

            var cancellables = new GLib.List<Cancellable> ();

            var current_result_set = dest_result_set ?? new ResultSet ();
            int search_size = item_plugins.size;
            bool waiting = false;

            foreach (var data_plugin in item_plugins) {
                bool skip = !data_plugin.enabled ||
                            (query.length == 0 && !data_plugin.handles_empty_query ()) ||
                            !data_plugin.handles_query (q);
                if (skip) {
                    search_size--;
                    continue;
                }
                // we need to pass separate cancellable to each plugin, because we're
                // running them in parallel
                var c = new Cancellable ();
                cancellables.prepend (c);
                q.cancellable = c;
                // magic comes here
                data_plugin.search.begin (q, (src_obj, res) => {
                    unowned ItemProvider? plugin = src_obj as ItemProvider;
                    return_if_fail (plugin != null);

                    try {
                        var results = plugin.search.end (res);
                        var plugin_identifier = plugin.get_type ().name ();

                        this.search_done[plugin_identifier](results, q.query_id);
                        // current_result_set.add_all (results);
                        var results_set = new Gee.ArrayList<ResultSet> ();
                        results_sets[plugin_identifier] = results;
                        foreach (var set in results_sets.values) {
                            if (set != null && set.size > 0)
                                results_set.add (set);
                        }
                        // if (current_result_set.size > 0)
                        //     results_set.add (current_result_set);
                        // if (results.size > 0)
                        //     results_set.add (results);
                        current_result_set = relevancy_backend.merge_results (results_set, q.query_string);
                    } catch (SearchError err) {
                        if (!(err is SearchError.SEARCH_CANCELLED))
                            warning ("%s returned error: %s",
                                     plugin.get_type ().name (), err.message);
                    }

                    if (--search_size == 0 && waiting)
                        search.callback ();
                });
            }

            cancellables.reverse ();

            if (cancellable != null)
                cancellable.connect (() => {
                    foreach (var c in cancellables) c.cancel ();
                });

            waiting = true;
            if (search_size > 0)
                yield;

            if (cancellable != null && cancellable.is_cancelled ())
                throw new SearchError.SEARCH_CANCELLED ("Cancelled");

            if (has_unknown_handlers && query_stripped != "") {
                var unknown_match = new UnknownMatch (query);
                bool add_to_rs = false;

                if (QueryFlags.ACTIONS in flags || QueryFlags.TEXT in flags) {
                    // FIXME: maybe we should also check here if there are any matches
                    add_to_rs = true;
                } else {
                    // check whether any of the actions support this category
                    var unknown_match_actions = find_actions_for_unknown_match (unknown_match, flags);
                    if (unknown_match_actions.size > 0)
                        add_to_rs = true;
                }

                if (add_to_rs)
                    current_result_set.add (unknown_match, 0);
            }

            return current_result_set.get_sorted_list ();
        }

        // protected Gee.List<Match> get_sorted_list () {
        //
        // }

        protected Gee.List<Match> find_actions_for_unknown_match (Match match,
                                                                  QueryFlags flags) {
            var rs = new ResultSet ();
            var q = Query (0, "", flags);

            foreach (var action_plugin in action_plugins) {
                if (!action_plugin.enabled)
                    continue;

                if (!action_plugin.handles_unknown ())
                    continue;

                rs.add_all (action_plugin.find_for_match (ref q, match));
            }

            return rs.get_sorted_list ();
        }

        public Gee.List<Match> find_actions_for_match (Match match, string? query,
                                                       QueryFlags flags) {
            var rs = new ResultSet ();
            var q = Query (0, query ?? "", flags);

            foreach (var action_plugin in action_plugins) {
                if (!action_plugin.enabled)
                    continue;

                rs.add_all (action_plugin.find_for_match (ref q, match));
            }

            return rs.get_sorted_list ();
        }

    }
}
