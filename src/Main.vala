/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 */

namespace Synapse {
    public class Application : Gtk.Application {
        /*
         * determine whether to show UI upon activation
         */
        private static bool is_startup = false;

        /* *INDENT-OFF* */
        private const OptionEntry[] ENTRIES = {
            { "startup", 's', OptionFlags.NONE, OptionArg.NONE, ref is_startup, "Startup mode (hide the UI until activated).", null },
            { null }
        };
        /* *INDENT-ON* */

        private Gui.SettingsWindow settings;
        private DataSink data_sink;
        private PluginRegistry registry;
        private Gui.KeyComboConfig key_combo_config;
        private Gui.CategoryConfig category_config;
        private string current_shortcut;
        private ConfigService config;
#if HAVE_INDICATOR
        private AppIndicator.Indicator indicator;
#else
        private Gtk.StatusIcon status_icon;
#endif
        private Gui.IController controller;

        static void handle_shortcut (string key, void * data) {
            ((Application) data).show_ui ();
        }

        public Application () {
            Object (
                application_id: Config.APP_ID,
                flags : ApplicationFlags.HANDLES_COMMAND_LINE);
        }

        public override void activate () {
            if (controller == null) {
                config = ConfigService.get_default ();
                data_sink = new DataSink ();
                registry = PluginRegistry.get_default ();

                key_combo_config = (Gui.KeyComboConfig)config.bind_config ("ui", "shortcuts", typeof (Gui.KeyComboConfig));
                category_config = (Gui.CategoryConfig)config.get_config ("ui", "categories", typeof (Gui.CategoryConfig));

                key_combo_config.update_bindings ();
                register_plugins ();

                settings = new Gui.SettingsWindow (data_sink, key_combo_config);
                settings.keybinding_changed.connect (this.change_keyboard_shortcut);
                settings.theme_selected.connect (init_ui);

                Keybinder.init ();
                bind_keyboard_shortcut ();

                controller = GLib.Object.new (typeof (Gui.Controller),
                                              "data-sink", data_sink,
                                              "key-combo-config", key_combo_config,
                                              "category-config", category_config) as Gui.IController;

                controller.show_settings_requested.connect (() => {
                    settings.show ();
                    uint32 timestamp = Gtk.get_current_event_time ();
                    /* Make sure that the settings window is showed */
                    settings.deiconify ();
                    settings.present_with_time (timestamp);
                    settings.get_window ().raise ();
                    settings.get_window ().focus (timestamp);
                    controller.summon_or_vanish ();
                });
                controller.quit.connect (this.quit);

                init_ui (settings.get_current_theme ());
                init_indicator ();

                if (!is_startup)
                    controller.summon_or_vanish ();

                Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
                Gdk.Window.process_all_updates ();
                Gtk.main ();
            }
            if (is_startup)
                return;

            show_ui ();
        }

        public override int command_line (ApplicationCommandLine command_line) {
            hold ();
            var result = _command_line (command_line);
            release ();

            return result;
        }

        private int _command_line (ApplicationCommandLine command_line) {
            string[] args = command_line.get_arguments ();
            string *[] _args = new string[args.length];

            for (int i = 0 ; i < args.length ; i++)
                _args[i] = args[i];

            try {
                var context = new OptionContext (null);

                context.add_main_entries (ENTRIES, null);
                context.add_group (Gtk.get_option_group (true));

                unowned string[] tmp = _args;

                context.parse (ref tmp);
            } catch (Error err) {
                warning ("%s", err.message);
                return 1;
            }

            activate ();

            return 0;
        }

        private void register_plugins () {
            foreach (var plugin_info in registry.get_plugins ()) {
                data_sink.register_static_plugin (plugin_info.plugin_type);
            }
        }

        private void bind_keyboard_shortcut () {
            current_shortcut = key_combo_config.activate;
            message ("Binding activation to %s", current_shortcut);
            settings.set_keybinding (current_shortcut, false);
            Keybinder.bind (current_shortcut, handle_shortcut, this);
        }

        private void change_keyboard_shortcut (string key) {
            Keybinder.unbind (current_shortcut, handle_shortcut);
            current_shortcut = key;
            Keybinder.bind (current_shortcut, handle_shortcut, this);
        }

        private void init_ui (Type t) {
            controller.set_view (t);
        }

        private void init_indicator () {
            var indicator_menu = new Gtk.Menu ();
            var activate_item = new Gtk.ImageMenuItem.with_label (_("Activate"));

            activate_item.set_image (new Gtk.Image.from_stock (Gtk.Stock.EXECUTE, Gtk.IconSize.MENU));
            activate_item.activate.connect (() => {
                show_ui ();
            });
            indicator_menu.append (activate_item);

            var settings_item = new Gtk.ImageMenuItem.from_stock (Gtk.Stock.PREFERENCES, null);

            settings_item.activate.connect (() => {
                settings.show ();
            });
            indicator_menu.append (settings_item);
            indicator_menu.append (new Gtk.SeparatorMenuItem ());

            var quit_item = new Gtk.ImageMenuItem.from_stock (Gtk.Stock.QUIT, null);

            quit_item.activate.connect (quit);
            indicator_menu.append (quit_item);
            indicator_menu.show_all ();

#if HAVE_INDICATOR
            // Why Category.OTHER? See
            // https://bugs.launchpad.net/synapse-project/+bug/685634/comments/13
            indicator = new AppIndicator.Indicator ("synapse", "synapse",
                                                    AppIndicator.IndicatorCategory.OTHER);

            indicator.set_menu (indicator_menu);

            if (settings.indicator_active)
                indicator.set_status (AppIndicator.IndicatorStatus.ACTIVE);

            settings.notify["indicator-active"].connect (() => {
                indicator.set_status (settings.indicator_active ?
                                      AppIndicator.IndicatorStatus.ACTIVE : AppIndicator.IndicatorStatus.PASSIVE);
            });
#else
            status_icon = new Gtk.StatusIcon.from_icon_name ("synapse");

            status_icon.popup_menu.connect ((icon, button, event_time) => {
                indicator_menu.popup (null, null, status_icon.position_menu, button, event_time);
            });
            status_icon.activate.connect (() => {
                show_ui ();
            });
            status_icon.set_visible (settings.indicator_active);

            settings.notify["indicator-active"].connect (() => {
                status_icon.set_visible (settings.indicator_active);
            });
#endif
        }

        private void show_ui () {
            if (this.controller == null)
                return;

            this.controller.summon_or_vanish ();
        }

    }
}

public static int main (string[] argv) {
    Synapse.Utils.Logger.initialize ();

    message ("starting up...");
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE,
                         Path.build_filename (Config.DATA_DIR, "locale"));
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    Environment.set_application_name (Config.APP_NAME);
    Notify.init (Config.APP_ID);

    var app = new Synapse.Application ();

    return app.run (argv);
}
