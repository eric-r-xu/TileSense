using Engine;

class TileEfficiencyWindow : Object
{
    private static bool gtk_initialized = false;
    private static bool gtk_available = false;

    private Gtk.Window? window = null;
    private Gtk.TextView? text_view = null;

    public TileEfficiencyWindow()
    {
        if (!init_gtk())
        {
            Environment.log(LogType.ERROR, "TileEfficiencyWindow", "Could not initialize the separate GTK guide window");
            return;
        }

        window = new Gtk.Window();
        window.title = "OpenRiichi Tile Efficiency Guide";
        window.set_default_size(540, 520);
        window.set_keep_above(true);
        window.delete_event.connect(on_delete);

        Gtk.CssProvider colors = new Gtk.CssProvider();
        try
        {
            colors.load_from_data(
                ".tile-efficiency-guide, .tile-efficiency-guide text {" +
                " background-color: #000000; color: #f2f2f2; }" +
                ".tile-efficiency-scroll { background-color: #000000; }");
        }
        catch (Error error)
        {
            Environment.log(LogType.ERROR, "TileEfficiencyWindow",
                "Could not load guide colors: %s".printf(error.message));
        }

        text_view = new Gtk.TextView();
        text_view.editable = false;
        text_view.cursor_visible = false;
        text_view.monospace = true;
        text_view.wrap_mode = Gtk.WrapMode.NONE;
        text_view.left_margin = 14;
        text_view.right_margin = 14;
        text_view.top_margin = 12;
        text_view.bottom_margin = 12;
        text_view.get_style_context().add_class("tile-efficiency-guide");
        text_view.get_style_context().add_provider(colors, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Pango.FontDescription font = text_view.get_style_context()
            .get_font(Gtk.StateFlags.NORMAL).copy();
        int current_size = font.get_size();
        font.set_family("monospace");
        font.set_size((current_size > 0 ? current_size : 10 * Pango.SCALE) + 2 * Pango.SCALE);
        text_view.override_font(font);

        Gtk.ScrolledWindow scroll = new Gtk.ScrolledWindow(null, null);
        scroll.get_style_context().add_class("tile-efficiency-scroll");
        scroll.get_style_context().add_provider(colors, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        scroll.add(text_view);
        window.add(scroll);
    }

    public void show_results(string results)
    {
        if (window == null || text_view == null)
            return;

        text_view.buffer.text = results;
        if (!window.visible)
            window.show_all();
    }

    public void show_waiting()
    {
        if (text_view != null && window != null && window.visible)
            text_view.buffer.text = "Tile Efficiency Guide\n\nWaiting for your next turn...";
    }

    public void process_events()
    {
        if (!gtk_available)
            return;

        while (Gtk.events_pending())
            Gtk.main_iteration_do(false);
    }

    public void close()
    {
        if (window != null)
        {
            window.destroy();
            window = null;
            text_view = null;
            process_events();
        }
    }

    private bool on_delete(Gdk.EventAny event)
    {
        window.hide();
        return true;
    }

    private static bool init_gtk()
    {
        if (!gtk_initialized)
        {
            unowned string[]? args = null;
            gtk_available = Gtk.init_check(ref args);
            gtk_initialized = true;
        }
        return gtk_available;
    }
}
