class Synapse.QueryHistoryInspector : Object {
    public QueryHistoryInspector () {
        warning ("1");
        var query_history = new QueryHistory (Path.build_filename (
                                                  Environment.get_user_data_dir (),
                                                  Config.APP_ID, "queryHistory.data"));
        string[] prefixes = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" };
        foreach (var prefix in prefixes) {
            warning (prefix);
            var history = query_history.history_for_prefix (prefix);
            history.for_each ((k, v) => {
                warning (@"$k: $v");
            });
        }
    }

    public static void main () {
        var inspector = new QueryHistoryInspector ();
    }

}
