synapse_ui_sources = files(
  'Category.vala',
  'Controller.vala',
  'DataSink.vala',
  'IconCacheService.vala',
  'Interfaces.vala',
  'Keybindings.vala',
  'Main.vala',
  'MatchListViewWidgets.vala',
  'Model.vala',
  'PluginRegistry.vala',
  'SearchEntry.vala',
  'Settings.vala',
  'Widgets.vala',
  'Utils.vala'
)

hat_trie_subproject = subproject('hat-trie')
hat_trie_dep = hat_trie_subproject.get_variable('hat_trie_dep')

subdir('QueryHistory')
subdir('Themes')
subdir('TileView')

synapse_ui_dependencies = [
  gdk_dep,
  gee_dep,
  gio_dep,
  glib_dep,
  gmodule_dep,
  gtk_dep,
  keybinder_dep,
  m_dep,
  notify_dep,
  synapse_dep,
  query_history_dep,
  vala.find_library(
    'QueryHistory',
    dirs: query_history_vapi_dir
  ),
  config_dep
]

executable(
  meson.project_name(),
  synapse_ui_sources,
  synapse_themes_sources,
  include_directories: config_inc_dir,
  dependencies: synapse_ui_dependencies,
  install: true,
)
