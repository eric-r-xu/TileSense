using Engine;

private static bool debug =
#if DEBUG
    true
#else
    false
#endif
;

private static bool multithread_rendering = false;

private static string? arg_search_dir = null;

private static string? make_absolute_path(string? path, string working_dir)
{
    if (path == null || path.strip().length == 0 || GLib.Path.is_absolute(path))
        return path;

    return GLib.Path.build_filename(working_dir, path);
}

private static void parse_args(string[] args)
{
    for (int i = 1; i < args.length; i++)
    {
        string arg = args[i];
        if (arg.length == 0 || arg[0] != '-')
            continue;
        arg = arg.substring(1);

        if (arg == "d" || arg == "-debug")
            debug = true;
        else if (arg == "-no-debug")
            debug = false;
        else if (arg == "-multithread-rendering")
            multithread_rendering = true;
        else if (arg == "-no-multithread-rendering")
            multithread_rendering = false;
        else if (arg == "-search-directory")
        {
            i++;

            if (i < args.length)
                arg_search_dir = args[i];
        }
    }
}

private static void show_error(string message)
{
    Environment.log(LogType.ERROR, "Main", message);
    show_error_message_box("TileSense (" + Environment.version_info.to_string() + ") startup error", message + "\n" + "Look at logs for more details");
}

public static int main(string[] args)
{
    EfficiencyLogging.enabled = true;

    // Environment.init() changes the working directory to the application
    // bundle's Resources directory on macOS. Resolve command-line paths first
    // so relative paths keep referring to the directory the user launched from.
    string launch_dir = GLib.Environment.get_current_dir();
    string? executable_dir = args.length > 0
        ? make_absolute_path(GLib.Path.get_dirname(args[0]), launch_dir)
        : null;
    string? built_search_dir = Build.SEARCH_DIR;

    parse_args(args);
    built_search_dir = make_absolute_path(built_search_dir, launch_dir);
    arg_search_dir = make_absolute_path(arg_search_dir, launch_dir);

    if (!Environment.init(debug))
    {
        show_error("Could not init environment");
        return -1;
    }

    FileLoader.init();
    FileLoader.add_search_path(executable_dir);
    FileLoader.add_search_path(built_search_dir);
    FileLoader.add_search_path(arg_search_dir);
    FileLoader.add_search_path(Environment.get_user_dir());

    if (FileLoader.find_directory("Data") == null)
    {
        show_error("Could not find Data directory in search paths");
        return -1;
    }

    while (true)
    {
        Options options = new Options.from_disk();
        int multisamples = options.anti_aliasing == OnOffEnum.ON ? 2 : 0;
        Size2i window_size = Size2i(options.window_width, options.window_height);
        Vec2i window_position = Vec2i(options.window_x, options.window_y);
        string window_name = EfficiencyLogging.enabled ? "TileSense Tile Efficiency" :
            "TileSense 2D";

        // Keep the training panel's top-left corner clear of renderer diagnostics.
        bool renderer_debug = debug && !EfficiencyLogging.enabled;
        SDLGLEngine engine = new SDLGLEngine(multithread_rendering,
            Environment.version_info.to_string(), renderer_debug);
        if (!engine.init(window_name, window_size, window_position, options.screen_type, multisamples))
        {
            show_error("Could not init engine");
            return -1;
        }

        MainWindow window = new MainWindow(engine.window, engine.renderer);

        window.show();
        engine.stop();

        if (!window.do_restart)
            break;
    }

    Environment.log(LogType.INFO, "Main", "Application stopped normally");

    return 0;
}
