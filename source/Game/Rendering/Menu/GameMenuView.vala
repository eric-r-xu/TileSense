using Engine;
using Gee;

class GameMenuView : View2D
{
    private ScoringView? score_view = null;
    private ArrayList<MenuTextButton> buttons = new ArrayList<MenuTextButton>();
    private ArrayList<MenuTextButton> observer_buttons = new ArrayList<MenuTextButton>();

    private GameRenderContext context;
    private ServerSettings settings;
    private bool observing;

    private Sound hint_sound;
    private float start_time;
    private LabelControl timer;
    private LabelControl timer_title;
    private LabelControl furiten;
    private TileEfficiencyOverlay? efficiency_overlay = null;
    private MenuTextButton? autoplay_button = null;
    private LabelControl? autoplay_status = null;
    private bool autoplay_enabled;

    private MenuTextButton chii;
    private MenuTextButton pon;
    private MenuTextButton kan;
    private MenuTextButton riichi;
    private MenuTextButton open_riichi;
    private MenuTextButton tsumo;
    private MenuTextButton ron;
    private MenuTextButton conti;
    private MenuTextButton void_hand;

    private MenuTextButton next;
    private MenuTextButton prev;

    public signal void chii_pressed();
    public signal void pon_pressed();
    public signal void kan_pressed();
    public signal void riichi_pressed(bool open);
    public signal void tsumo_pressed();
    public signal void ron_pressed();
    public signal void continue_pressed();
    public signal void void_hand_pressed();
    public signal void display_score_pressed();
    public signal void score_finished();
    public signal void autoplay_changed(bool enabled);

    public signal void observe_next_pressed();
    public signal void observe_prev_pressed();

    private void press_chii() { chii_pressed(); }
    private void press_pon() { pon_pressed(); }
    private void press_kan() { kan_pressed(); }
    private void press_riichi()
    {
        bool state = open_riichi.enabled;
        riichi_pressed(false);
        if (state)
            open_riichi.enabled = false;
    }
    private void press_open_riichi()
    {
        bool state = riichi.enabled;
        riichi_pressed(true);
        if (state)
            riichi.enabled = false;
    }
    private void press_tsumo() { tsumo_pressed(); }
    private void press_ron() { ron_pressed(); }
    private void press_continue() { continue_pressed(); }
    private void press_void_hand() { void_hand_pressed(); }

#if TWO_DIMENSIONAL
    private void press_autoplay()
    {
        set_autoplay(!autoplay_enabled);
        autoplay_changed(autoplay_enabled);
    }
#endif

    private void press_next() { observe_next_pressed(); score_view.next(); }
    private void press_prev() { observe_prev_pressed(); score_view.prev(); }

    public GameMenuView(GameRenderContext context, ServerSettings settings, int player_index, bool observing)
    {
        this.context = context;
        this.settings = settings;
        this.player_index = player_index;
        this.observing = observing;

        score_view = new ScoringView(context, player_index);
        score_view.score_finished.connect(do_score_finished);
    }

    public override void added()
    {
        hint_sound = store.audio_player.load_sound("hint");

        int padding = 30;
        timer = new LabelControl();
        add_child(timer);
        timer.inner_anchor = Vec2(1, 0);
        timer.outer_anchor = Vec2(1, 0);
        timer.position = Vec2(-padding, padding / 2);
        timer.font_size = 60;
        timer.visible = false;

        timer_title = new LabelControl();
        add_child(timer_title);
        timer_title.text = "Countdown Timer";
        timer_title.font_size = 18;
        timer_title.inner_anchor = Vec2(1, 0);
        timer_title.outer_anchor = Vec2(1, 0);
        // The timer has no text yet, so its measured height is zero here.
        // Use its configured font height to keep this title reliably above the
        // number from the first visible frame onward.
        timer_title.position = Vec2(-padding, padding / 2 + timer.font_size + 14);
        timer_title.visible = false;

        furiten = new LabelControl();
        add_child(furiten);
        furiten.inner_anchor = Vec2(0, 0);
        furiten.outer_anchor = Vec2(0, 0);
        furiten.position = Vec2(padding, padding / 2);
        furiten.font_size = 30;
        furiten.visible = false;
        furiten.text = "Furiten";
        furiten.color = Color.red();

        chii = new MenuTextButton("MenuButtonSmall", "Chii");
        pon = new MenuTextButton("MenuButtonSmall", "Pon");
        kan = new MenuTextButton("MenuButtonSmall", "Kan");
        riichi = new MenuTextButton("MenuButtonSmall", "Riichi");
        open_riichi = new MenuTextButton("MenuButtonSmall", "Open Riichi");
        tsumo = new MenuTextButton("MenuButtonSmall", "Tsumo");
        ron = new MenuTextButton("MenuButtonSmall", "Ron");
        conti = new MenuTextButton("MenuButtonSmall", "Continue");
        void_hand = new MenuTextButton("MenuButtonSmall", "Void Hand");

        next = new MenuTextButton("MenuButtonSmall", "Next");
        prev = new MenuTextButton("MenuButtonSmall", "Previous");

        chii.clicked.connect(press_chii);
        pon.clicked.connect(press_pon);
        kan.clicked.connect(press_kan);
        riichi.clicked.connect(press_riichi);
        open_riichi.clicked.connect(press_open_riichi);
        tsumo.clicked.connect(press_tsumo);
        ron.clicked.connect(press_ron);
        conti.clicked.connect(press_continue);
        void_hand.clicked.connect(press_void_hand);

        next.clicked.connect(press_next);
        prev.clicked.connect(press_prev);

        buttons.add(chii);
        buttons.add(pon);
        buttons.add(kan);
        buttons.add(riichi);
        buttons.add(open_riichi);
        buttons.add(tsumo);
        buttons.add(ron);
        buttons.add(conti);
        buttons.add(void_hand);

        observer_buttons.add(prev);
        observer_buttons.add(next);

        foreach (var button in buttons)
        {
            add_child(button);
            button.enabled = false;
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.font_size = 24;
            button.visible = !observing;
        }

        foreach (var button in observer_buttons)
        {
            add_child(button);
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.font_size = 24;
            button.visible = observing;
        }

        void_hand.visible = false;
        open_riichi.visible = open_riichi.visible && settings.open_riichi == OnOffEnum.ON;
        position_buttons(buttons);
        position_buttons(observer_buttons);

        add_child(score_view);

        if (EfficiencyLogging.enabled && EfficiencyLogging.singleplayer_session && !observing)
        {
            efficiency_overlay = new TileEfficiencyOverlay();
            add_child(efficiency_overlay);
            efficiency_overlay.clicked.connect(toggle_tile_efficiency);

#if TWO_DIMENSIONAL
            autoplay_button = new MenuTextButton("MenuButtonSmall", "Autoplay");
            add_child(autoplay_button);
            autoplay_button.inner_anchor = Vec2(0.5f, 1);
            autoplay_button.outer_anchor = Vec2(0.5f, 1);
            autoplay_button.position = Vec2(260, -24);
            autoplay_button.font_size = 20;
            autoplay_button.clicked.connect(press_autoplay);

            autoplay_status = new LabelControl();
            add_child(autoplay_status);
            autoplay_status.inner_anchor = Vec2(0.5f, 1);
            autoplay_status.outer_anchor = Vec2(0.5f, 1);
            autoplay_status.position = Vec2(260, -88);
            autoplay_status.font_size = 16;
            set_autoplay(autoplay_enabled);
#endif
        }
    }

    private void position_buttons(ArrayList<MenuTextButton> buttons)
    {
        float p = 0;
        float width = 0;
        float table_offset = 0;
#if TWO_DIMENSIONAL
#if EFFICIENCY_LOGGING
        table_offset = float.min(120, size.width * 0.07f);
#endif
#endif

        foreach (var button in buttons)
            if (button.visible)
                width += button.size.width / 2;

        foreach (var button in buttons)
        {
            if (!button.visible)
                continue;

            button.position = Vec2(table_offset + button.size.width / 2 - width + p, 0);
            p += button.size.width;
        }
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        key.handled = true;

        if (key.scancode == ScanCode.TAB && !key.repeat)
        {
            if (key.down)
                display_score();
            else
                hide_score();
        }
        else
            key.handled = false;
    }

    public void set_chii(bool enabled)
    {
        chii.enabled = enabled;
    }

    public void set_pon(bool enabled)
    {
        pon.enabled = enabled;
    }

    public void set_kan(bool enabled)
    {
        kan.enabled = enabled;
    }

    public void set_riichi(bool enabled)
    {
        riichi.enabled = enabled;
        open_riichi.enabled = enabled;
    }

    public void set_tsumo(bool enabled)
    {
        tsumo.enabled = enabled;
    }

    public void set_ron(bool enabled)
    {
        ron.enabled = enabled;
    }

    public void set_continue(bool enabled)
    {
        if (enabled)
            hint_sound.play();
        conti.enabled = enabled;
    }

    public void set_void_hand(bool enabled)
    {
        void_hand.visible = enabled;
        void_hand.enabled = enabled;
        position_buttons(buttons);
    }

    public void set_furiten(bool enabled)
    {
        furiten.visible = enabled;
    }

    public void set_move_timer(bool enabled)
    {
        if (timer.visible && enabled)
            return;

        start_time = 0;
        timer.visible = enabled;
        timer_title.visible = enabled;
    }

    public void set_tile_efficiency(string results)
    {
        if (efficiency_overlay != null)
            efficiency_overlay.show_results(results);
    }

    public void hide_tile_efficiency()
    {
        if (efficiency_overlay != null)
            efficiency_overlay.show_waiting();
    }

    public void set_autoplay(bool enabled)
    {
        autoplay_enabled = enabled;
        if (autoplay_status == null)
            return;
        autoplay_status.text = enabled ?
            "ON · EV + defense" : "OFF · click to enable (EV + defense)";
        autoplay_status.color = enabled ? Color.green() : Color.white();
    }

    private void toggle_tile_efficiency(Control control, Vec2 position)
    {
        if (efficiency_overlay != null)
            efficiency_overlay.toggle_minimized();
    }

    public void update_scores(RoundScoreState[] scores)
    {
        score_view.update_scores(scores);
    }

    public void game_over()
    {
        hide_autoplay();
        score_view.display(true);
    }

    public void round_finished()
    {
        hide_tile_efficiency();
        hide_autoplay();
        score_view.display(true);

        foreach (var button in observer_buttons)
            button.enabled = false;
    }

    private void hide_autoplay()
    {
        if (autoplay_button != null)
            autoplay_button.visible = false;
        if (autoplay_status != null)
            autoplay_status.visible = false;
    }

    public void display_score()
    {
        score_view.display(false);
    }

    public void hide_score()
    {
        score_view.hide();
    }

    public void display_disconnected()
    {
        InformationMenuView view = new InformationMenuView("Connection to server lost");
        add_child(view);
        view.back.connect(info_menu_finished);
    }

    public void display_player_left(string name)
    {
        InformationMenuView view = new InformationMenuView(name + " has left the game");
        add_child(view);
        view.back.connect(info_menu_finished);
    }

    private void info_menu_finished(MenuSubView view)
    {
        remove_child(view);
    }

    private void do_score_finished()
    {
        score_finished();
    }

    protected override void process(DeltaArgs delta)
    {
        if (start_time == 0)
            start_time = delta.time;

        if (!timer.visible)
            return;

        int t = int.max((int)(start_time + context.server_times.decision_time - delta.time), 0);
        if (t == context.server_times.decision_time)
            t--;

        if (t < 0)
        {
            timer.visible = false;
            timer_title.visible = false;
            return;
        }

        timer.color = t < 3 ? Color.red() : Color.white();

        string str = t.to_string();

        if (str != timer.text)
            timer.text = str;
    }

    public int player_index { get; set; }

}
