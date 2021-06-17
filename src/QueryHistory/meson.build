query_history_vapi_dir = meson.current_source_dir()

query_history_dependencies = [
  dependency('tracker-sparql-3.0'),
  glib_dep,
  hat_trie_dep
]

query_history_sources = files(
  'queryHistoryController.cpp',
  'queryHistoryController.h',
  'queryHistory.cpp',
  'queryHistory.h'
)

query_history = static_library(
  'QueryHistory',
  query_history_sources,
  dependencies: query_history_dependencies,
  gnu_symbol_visibility: 'hidden'
)

query_history_dep = declare_dependency(
  link_with: query_history,
  include_directories: include_directories('.')
)
