sources = files(
  'QueryHistory/TestQueryHistory.vala',
  'TestSynapse.vala'
)

dependencies = [
  glib_dep,
  query_history_dep,
  vala_unit_dep,
  vala_unit_base_deps,
  config_dep,
  vala.find_library(
    'QueryHistory',
    dirs: query_history_vapi_dir
  )
]

synapse_test_bin = executable(
  'test-synapse',
  sources,
  dependencies: dependencies,
  include_directories: config_inc_dir
)

# executable(
#   'inspector',
#   'QueryHistory/QueryHistoryInspector.vala',
#   dependencies: dependencies,
#   include_directories: config_inc_dir
# )

test(
  'synapse-tests',
  synapse_test_bin
)
