#if TWO_DIMENSIONAL
using Engine;
using Gee;

public class GameRenderView : View2D, IGameRenderer
{
    public GameRenderContext context { get; private set; }
    public signal void game_loaded();

    private RoundStateWall wall;
    private Tile[] tiles = new Tile[136];
    private ArrayList<Tile>[] hands = new ArrayList<Tile>[4];
    private ArrayList<Tile>[] ponds = new ArrayList<Tile>[4];
    private ArrayList<Tile>[] calls = new ArrayList<Tile>[4];
    private bool[] riichi_players = new bool[4];

    private int observer_index;
    private int dealer_index;
    private int wall_remaining = 70;
    private bool active;
    private bool loaded_sent;
    private ArrayList<TileSelectionGroup>? select_groups;

    private RectangleControl background;
    private LabelControl round_label;
    private LabelControl center_label;
    private LabelControl top_label;
    private LabelControl left_label;
    private LabelControl right_label;
    private LabelControl bottom_calls;
    private Tile2DButton[] hand_buttons = new Tile2DButton[14];
    private GameStartInfo game_start;
    private RoundScoreState score;

    public GameRenderView(int observer_index, int dealer_index, GameStartInfo game_start,
        RoundStartInfo info, Options options, RoundScoreState score)
    {
        this.observer_index = observer_index == -1 ? 0 : observer_index;
        this.dealer_index = dealer_index;
        this.game_start = game_start;
        this.score = score;
        context = new GameRenderContext(game_start.timings, 1, Vec3(1, 1, 1),
            observer_index, dealer_index, info.wall_index);

        wall = new RoundStateWall(dealer_index, info.wall_index);
        for (int i = 0; i < 136; i++)
            tiles[i] = wall.get_tile(i);
        for (int i = 0; i < 4; i++)
        {
            hands[i] = new ArrayList<Tile>();
            ponds[i] = new ArrayList<Tile>();
            calls[i] = new ArrayList<Tile>();
        }

        // The logical wall uses the same ID ordering as the server and the 3D renderer.
        for (int packet = 0; packet < 16; packet++)
        {
            int count = packet < 12 ? 4 : 1;
            int player = (packet + dealer_index) % 4;
            for (int t = 0; t < count; t++)
                hands[player].add(wall.draw_wall());
        }
    }

    public override void added()
    {
        background = new RectangleControl();
        add_child(background);
        background.resize_style = ResizeStyle.RELATIVE;
        background.color = Color(0.015f, 0.08f, 0.09f, 1);

        round_label = make_label(24, Vec2(24, 20), Vec2(0, 0), Vec2(0, 0));
        center_label = make_label(28, Vec2(0, 0), Vec2(0.5f, 0.5f), Vec2(0.5f, 0.5f));
        top_label = make_label(30, Vec2(0, 28), Vec2(0.5f, 0), Vec2(0.5f, 0));
        left_label = make_label(25, Vec2(28, 0), Vec2(0, 0.5f), Vec2(0, 0.5f));
        right_label = make_label(25, Vec2(-28, 0), Vec2(1, 0.5f), Vec2(1, 0.5f));
        bottom_calls = make_label(25, Vec2(0, -190), Vec2(0.5f, 1), Vec2(0.5f, 1));

        for (int i = 0; i < hand_buttons.length; i++)
        {
            hand_buttons[i] = new Tile2DButton();
            add_child(hand_buttons[i]);
            hand_buttons[i].chosen.connect(tile_button_chosen);
            hand_buttons[i].outer_anchor = Vec2(0.5f, 1);
            hand_buttons[i].inner_anchor = Vec2(0.5f, 1);
        }

        refresh();
        resized();
    }

    private LabelControl make_label(float font_size, Vec2 position, Vec2 inner, Vec2 outer)
    {
        LabelControl label = new LabelControl();
        add_child(label);
        label.font_size = font_size;
        label.position = position;
        label.inner_anchor = inner;
        label.outer_anchor = outer;
        return label;
    }

    protected override void process(DeltaArgs args)
    {
        if (!loaded_sent)
        {
            loaded_sent = true;
            game_loaded();
        }
    }

    protected override void resized()
    {
        if (hand_buttons[0] == null)
            return;
        float tile_width = float.min(62, (size.width - 48) / 14.0f);
        float start = -(tile_width * 13) / 2;
        for (int i = 0; i < hand_buttons.length; i++)
        {
            hand_buttons[i].size = Size2(tile_width - 3, 76);
            hand_buttons[i].position = Vec2(start + i * tile_width, -92);
        }
    }

    public void load_options(Options options) {}

    public void observe_next()
    {
        observer_index = (observer_index + 1) % 4;
        refresh();
    }

    public void observe_prev()
    {
        observer_index = (observer_index + 3) % 4;
        refresh();
    }

    private void tile_assignment(Tile tile)
    {
        tiles[tile.ID].tile_type = tile.tile_type;
        tiles[tile.ID].dora = tile.dora;
        refresh();
    }

    private void tile_draw(int player_index)
    {
        hands[player_index].add(wall.draw_wall());
        wall_remaining--;
        refresh();
    }

    public void dead_tile_draw(int player_index)
    {
        hands[player_index].add(wall.draw_dead_wall());
        wall_remaining--;
        refresh();
    }

    private void tile_discard(int player_index, int tile_ID)
    {
        Tile? tile = remove_tile(hands[player_index], tile_ID);
        if (tile != null)
            ponds[player_index].add(tile);
        refresh();
    }

    private void flip_dora()
    {
        wall.flip_dora();
        refresh();
    }

    private void riichi(int player_index, bool open)
    {
        riichi_players[player_index] = true;
        refresh();
    }

    private void late_kan(int player_index, int tile_ID)
    {
        Tile? tile = remove_tile(hands[player_index], tile_ID);
        if (tile != null)
            calls[player_index].add(tile);
        refresh();
    }

    private void closed_kan(int player_index, TileType type)
    {
        for (int i = hands[player_index].size - 1; i >= 0; i--)
            if (hands[player_index][i].tile_type == type)
                calls[player_index].add(hands[player_index].remove_at(i));
        refresh();
    }

    private void open_kan(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID, int tile_3_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        move_hand_tile(player_index, tile_3_ID);
        dead_tile_draw(player_index);
    }

    private void pon(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        refresh();
    }

    private void chii(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        refresh();
    }

    private void move_call_tile(int discarder, int player, int tile_ID)
    {
        Tile? tile = remove_tile(ponds[discarder], tile_ID);
        if (tile != null)
            calls[player].add(tile);
    }

    private void move_hand_tile(int player, int tile_ID)
    {
        Tile? tile = remove_tile(hands[player], tile_ID);
        if (tile != null)
            calls[player].add(tile);
    }

    private static Tile? remove_tile(ArrayList<Tile> list, int tile_ID)
    {
        for (int i = 0; i < list.size; i++)
            if (list[i].ID == tile_ID)
                return list.remove_at(i);
        return null;
    }

    private void game_finished(RoundFinishResult results)
    {
        active = false;
        center_label.text = results.result == RoundFinishResult.RoundResultEnum.DRAW ?
            "ROUND DRAW" : (results.result == RoundFinishResult.RoundResultEnum.RON ? "RON" : "TSUMO");
        refresh_hand();
    }

    public void set_active(bool active)
    {
        this.active = active;
        if (!active)
            select_groups = null;
        refresh_hand();
    }

    public void set_tile_select_groups(ArrayList<TileSelectionGroup>? groups)
    {
        select_groups = groups;
        refresh_hand();
    }

    private void tile_button_chosen(Tile tile)
    {
        if (active && is_selectable(tile))
            tile_selected(tile);
    }

    private bool is_selectable(Tile tile)
    {
        if (select_groups == null)
            return false;
        foreach (TileSelectionGroup group in select_groups)
            foreach (Tile candidate in group.selection_tiles)
                if (candidate.ID == tile.ID)
                    return true;
        return false;
    }

    private void refresh()
    {
        if (round_label == null)
            return;

        string dora = "";
        foreach (Tile tile in wall.dora)
            dora += TILE_TYPE_TO_EMOJI_2D(tile.tile_type);
        round_label.text = "%s %d  •  Wall %d  •  Dora %s".printf(
            WIND_TO_STRING(score.round_wind), score.current_round + 1, wall_remaining, dora);

        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        top_label.text = player_summary(top, false, false);
        left_label.text = player_summary(left, false, true);
        right_label.text = player_summary(right, false, true);
        bottom_calls.text = calls_text(observer_index);

        string ponds_text = "";
        for (int p = 0; p < 4; p++)
        {
            ponds_text += player_name(p) + (riichi_players[p] ? "  RIICHI" : "") + "\n";
            ponds_text += tiles_text(ponds[p], true, 6) + "\n\n";
        }
        center_label.text = ponds_text;
        refresh_hand();
    }

    private void refresh_hand()
    {
        if (hand_buttons[0] == null)
            return;
        ArrayList<Tile> sorted = Tile.sort_tiles_type(hands[observer_index]);
        for (int i = 0; i < hand_buttons.length; i++)
        {
            bool shown = i < sorted.size;
            hand_buttons[i].visible = shown;
            if (!shown)
                continue;
            Tile tile = sorted[i];
            bool selectable = active && is_selectable(tile);
            hand_buttons[i].set_tile(tile, selectable);
        }
    }

    private string player_summary(int player, bool reveal, bool vertical)
    {
        string hand = tiles_text(hands[player], reveal, vertical ? 1 : 20);
        return player_name(player) + (riichi_players[player] ? "  RIICHI" : "") + "\n" +
            hand + (calls[player].size > 0 ? "\nCalls " + calls_text(player) : "");
    }

    private string player_name(int player)
    {
        GameScorePlayer p = score.players[player];
        return "%s  %s  %d".printf(WIND_TO_KANJI(p.wind), p.name, p.points);
    }

    private string calls_text(int player)
    {
        return calls[player].size == 0 ? "" : "Calls  " + tiles_text(calls[player], true, 20);
    }

    private static string tiles_text(ArrayList<Tile> list, bool reveal, int per_line)
    {
        string text = "";
        for (int i = 0; i < list.size; i++)
        {
            if (i > 0 && i % per_line == 0)
                text += "\n";
            text += reveal && list[i].tile_type != TileType.BLANK ?
                TILE_TYPE_TO_EMOJI_2D(list[i].tile_type) : "🀫";
        }
        return text;
    }
}

private class Tile2DButton : Control
{
    private RectangleControl face;
    private LabelControl glyph;
    private Tile? current_tile;
    private bool permitted;
    public signal void chosen(Tile tile);

    public override void pre_added()
    {
        resize_style = ResizeStyle.ABSOLUTE;
        size = Size2(58, 76);
        selectable = true;

        face = new RectangleControl();
        add_child(face);
        face.resize_style = ResizeStyle.RELATIVE;

        glyph = new LabelControl();
        add_child(glyph);
        glyph.font_size = 47;
        glyph.color = Color(0.02f, 0.02f, 0.025f, 1);
    }

    public void set_tile(Tile tile, bool permitted)
    {
        current_tile = tile;
        this.permitted = permitted;
        glyph.text = TILE_TYPE_TO_EMOJI_2D(tile.tile_type);
        face.color = permitted ? Color(0.94f, 0.88f, 0.55f, 1) : Color(0.96f, 0.96f, 0.93f, 1);
    }

    public override void pre_render(RenderState state, RenderScene2D scene)
    {
        if (hovering && permitted)
            face.color = mouse_pressed ? Color(1, 0.68f, 0.18f, 1) : Color(1, 0.84f, 0.35f, 1);
        else
            face.color = permitted ? Color(0.94f, 0.88f, 0.55f, 1) : Color(0.96f, 0.96f, 0.93f, 1);
    }

    protected override void on_click(Vec2 position)
    {
        if (permitted && current_tile != null)
            chosen(current_tile);
    }
}

public static string TILE_TYPE_TO_EMOJI_2D(TileType type)
{
    string[] glyphs = {
        "🀫", "🀇", "🀈", "🀉", "🀊", "🀋", "🀌", "🀍", "🀎", "🀏",
        "🀙", "🀚", "🀛", "🀜", "🀝", "🀞", "🀟", "🀠", "🀡",
        "🀐", "🀑", "🀒", "🀓", "🀔", "🀕", "🀖", "🀗", "🀘",
        "🀀", "🀁", "🀂", "🀃", "🀆", "🀅", "🀄"
    };
    int index = (int)type;
    return index >= 0 && index < glyphs.length ? glyphs[index] : "🀫";
}
#endif
