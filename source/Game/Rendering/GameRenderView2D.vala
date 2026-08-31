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
    private ArrayList<Meld2D>[] melds = new ArrayList<Meld2D>[4];
    private bool[] riichi_players = new bool[4];

    private int observer_index;
    private int dealer_index;
    private int wall_remaining = 70;
    private bool active;
    private bool loaded_sent;
    private bool call_decision_active;
    private bool discard_attention_on;
    private int last_discard_player = -1;
    private int last_discard_index = -1;
    private ArrayList<TileSelectionGroup>? select_groups;

    private RectangleControl background;
    private RectangleControl table_center;
    private RectangleControl center_plate;
    private LabelControl round_label;
    private LabelControl center_label;
    private LabelControl center_top_wind;
    private LabelControl center_left_wind;
    private LabelControl center_right_wind;
    private LabelControl center_bottom_wind;
    private LabelControl center_counters;
    private LabelControl top_label;
    private LabelControl left_label;
    private LabelControl right_label;
    private LabelControl bottom_label;
    private LabelControl bottom_calls;
    private Tile2DButton[] hand_buttons = new Tile2DButton[14];
    // Do not render Mahjong tiles as Unicode. Noto Sans CJK does not contain the
    // Mahjong Tiles block, so systems fall back to a broken/tofu glyph.  Use the
    // same PNG faces as the 3D renderer instead.
    private Tile2DDisplay[] pond_buttons = new Tile2DDisplay[96];
    private Tile2DDisplay[] dead_wall_buttons = new Tile2DDisplay[14];
    private Tile2DDisplay[] meld_buttons = new Tile2DDisplay[64];
    private TileTextureEnum texture_type;
    private GameStartInfo game_start;
    private RoundScoreState score;

    public GameRenderView(int observer_index, int dealer_index, GameStartInfo game_start,
        RoundStartInfo info, Options options, RoundScoreState score)
    {
        this.observer_index = observer_index == -1 ? 0 : observer_index;
        this.dealer_index = dealer_index;
        this.game_start = game_start;
        this.score = score;
        texture_type = options.tile_textures;
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
            melds[i] = new ArrayList<Meld2D>();
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

        table_center = new RectangleControl();
        add_child(table_center);
        table_center.resize_style = ResizeStyle.ABSOLUTE;
        table_center.inner_anchor = Vec2(0.5f, 0.5f);
        table_center.outer_anchor = Vec2(0.5f, 0.5f);
        table_center.color = Color(0.018f, 0.19f, 0.17f, 1);

        center_plate = new RectangleControl();
        add_child(center_plate);
        center_plate.resize_style = ResizeStyle.ABSOLUTE;
        center_plate.inner_anchor = Vec2(0.5f, 0.5f);
        center_plate.outer_anchor = Vec2(0.5f, 0.5f);
        center_plate.color = Color(0.025f, 0.055f, 0.06f, 1);
        center_plate.visible = false;

        // The efficiency guide owns the upper-left corner. Keep round and wall
        // state visible in the opposite corner instead of underneath the hand.
        round_label = make_label(24, Vec2(-24, -20), Vec2(1, 1), Vec2(1, 1));
        // The central console is expressed as an English status block in the
        // upper-right, alongside the complete dead wall.
        center_label = make_label(18, Vec2(-24, -51), Vec2(1, 1), Vec2(1, 1));
        center_top_wind = make_center_label(14, Vec2(0, 60));
        center_left_wind = make_center_label(14, Vec2(-62, 0));
        center_right_wind = make_center_label(14, Vec2(62, 0));
        center_bottom_wind = make_center_label(14, Vec2(0, -60));
        center_top_wind.visible = false;
        center_left_wind.visible = false;
        center_right_wind.visible = false;
        center_bottom_wind.visible = false;
        center_counters = make_label(16, Vec2(-24, -77), Vec2(1, 1), Vec2(1, 1));
        top_label = make_label(24, Vec2(0, -205), Vec2(0.5f, 1), Vec2(0.5f, 1));
        left_label = make_label(23, Vec2(220, 0), Vec2(0, 0.5f), Vec2(0, 0.5f));
        right_label = make_label(23, Vec2(-220, 0), Vec2(1, 0.5f), Vec2(1, 0.5f));
        bottom_label = make_label(24, Vec2(0, 175), Vec2(0.5f, 0), Vec2(0.5f, 0));
        bottom_calls = make_label(18, Vec2(0, 205), Vec2(0.5f, 0), Vec2(0.5f, 0));

        for (int i = 0; i < hand_buttons.length; i++)
        {
            hand_buttons[i] = new Tile2DButton(texture_type);
            add_child(hand_buttons[i]);
            hand_buttons[i].chosen.connect(tile_button_chosen);
            // The OpenGL 2D projection is vertically inverted relative to
            // Container anchors. Use the top anchor here so the local hand is
            // presented at the bottom of the window.
            hand_buttons[i].outer_anchor = Vec2(0.5f, 0);
            hand_buttons[i].inner_anchor = Vec2(0.5f, 0);
        }

        for (int i = 0; i < pond_buttons.length; i++)
        {
            pond_buttons[i] = new Tile2DDisplay(texture_type);
            add_child(pond_buttons[i]);
        }
        for (int i = 0; i < dead_wall_buttons.length; i++)
        {
            dead_wall_buttons[i] = new Tile2DDisplay(texture_type);
            add_child(dead_wall_buttons[i]);
        }
        for (int i = 0; i < meld_buttons.length; i++)
        {
            meld_buttons[i] = new Tile2DDisplay(texture_type);
            add_child(meld_buttons[i]);
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

    private LabelControl make_center_label(float font_size, Vec2 position)
    {
        LabelControl label = make_label(font_size, position,
            Vec2(0.5f, 0.5f), Vec2(0.5f, 0.5f));
        label.color = Color(0.78f, 0.9f, 1, 1);
        return label;
    }

    protected override void process(DeltaArgs args)
    {
        if (!loaded_sent)
        {
            loaded_sent = true;
            game_loaded();
        }

        if (call_decision_active)
        {
            bool attention = ((int)(args.time * 4) % 2) == 0;
            if (attention != discard_attention_on)
            {
                discard_attention_on = attention;
                update_discard_attention();
            }
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
            hand_buttons[i].position = Vec2(start + i * tile_width, 92);
        }

        float table_width = float.min(620, size.width * 0.48f);
        float table_height = float.min(470, size.height * 0.53f);
        table_center.size = Size2(table_width, table_height);
        center_plate.size = Size2(160, 160);

        // Four compact discard pools surround the center plate. Side pools are
        // rotated and grow outward, preventing all four grids from occupying
        // the same central rectangle.
        float display_width = float.min(26, float.max(18, (size.width - 430) / 28));
        float display_height = display_width * 1.35f;
        for (int player = 0; player < 4; player++)
        {
            for (int i = 0; i < 24; i++)
            {
                Tile2DDisplay tile = pond_buttons[player * 24 + i];
                int column = i % 6;
                int row = i / 6;
                tile.size = Size2(display_width - 2, display_height - 2);
                tile.inner_anchor = Vec2(0.5f, 0.5f);
                tile.outer_anchor = Vec2(0.5f, 0.5f);
                // RenderObject2D rotation is measured in half turns: +0.5 is
                // 90 degrees. Opposite side pools must face in opposite
                // directions so their tile bottoms point toward their player.
                tile.rotation = player == 1 ? 0.5f :
                    (player == 3 ? -0.5f : 0);

                bool side = player == 1 || player == 3;
                float across_step = side ? display_width + 4 : display_width;
                float outward_step = side ? display_height + 7 : display_height + 4;
                float across = (column - 2.5f) * across_step;
                float outward = 108 + row * outward_step;
                if (player == 0)
                    tile.position = Vec2(across, -outward);
                else if (player == 2)
                    tile.position = Vec2(-across, outward);
                else if (player == 1)
                    tile.position = Vec2(outward, across);
                else
                    tile.position = Vec2(-outward, -across);
            }
        }

        float dead_width = float.max(20, display_width - 2);
        float dead_height = dead_width * 1.35f;
        for (int i = 0; i < dead_wall_buttons.length; i++)
        {
            int column = i / 2;
            int row = i % 2;
            dead_wall_buttons[i].size = Size2(dead_width, dead_height);
            dead_wall_buttons[i].position = Vec2(
                -24 - column * (dead_width + 3),
                -108 - row * (dead_height + 3));
            dead_wall_buttons[i].inner_anchor = Vec2(1, 1);
            dead_wall_buttons[i].outer_anchor = Vec2(1, 1);
        }
        layout_melds(display_width, display_height);
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
        {
            ponds[player_index].add(tile);
            last_discard_player = player_index;
            last_discard_index = ponds[player_index].size - 1;
        }
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
        {
            calls[player_index].add(tile);
            bool upgraded = false;
            foreach (Meld2D meld in melds[player_index])
                if (!meld.closed && meld.tiles.size == 3 &&
                    meld.tiles[0].tile_type == tile.tile_type)
                {
                    meld.tiles.add(tile);
                    meld.added_tile_ID = tile.ID;
                    upgraded = true;
                    break;
                }
            if (!upgraded)
            {
                Meld2D meld = new Meld2D(player_index, -1, -1, false);
                meld.tiles.add(tile);
                melds[player_index].add(meld);
            }
        }
        refresh();
    }

    private void closed_kan(int player_index, TileType type)
    {
        Meld2D meld = new Meld2D(player_index, player_index, -1, true);
        for (int i = hands[player_index].size - 1; i >= 0; i--)
            if (hands[player_index][i].tile_type == type)
            {
                Tile tile = hands[player_index].remove_at(i);
                calls[player_index].add(tile);
                meld.tiles.add(tile);
            }
        if (meld.tiles.size > 0)
            melds[player_index].add(meld);
        refresh();
    }

    private void open_kan(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID, int tile_3_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        move_hand_tile(player_index, tile_3_ID);
        record_open_meld(player_index, discard_player_index, tile_ID,
            new int[] { tile_ID, tile_1_ID, tile_2_ID, tile_3_ID });
        dead_tile_draw(player_index);
    }

    private void pon(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        record_open_meld(player_index, discard_player_index, tile_ID,
            new int[] { tile_ID, tile_1_ID, tile_2_ID });
        refresh();
    }

    private void chii(int player_index, int discard_player_index, int tile_ID,
        int tile_1_ID, int tile_2_ID)
    {
        move_call_tile(discard_player_index, player_index, tile_ID);
        move_hand_tile(player_index, tile_1_ID);
        move_hand_tile(player_index, tile_2_ID);
        record_open_meld(player_index, discard_player_index, tile_ID,
            new int[] { tile_ID, tile_1_ID, tile_2_ID });
        refresh();
    }

    private void record_open_meld(int player, int discarder, int called_tile_ID,
        int[] tile_IDs)
    {
        Meld2D meld = new Meld2D(player, discarder, called_tile_ID, false);
        foreach (int tile_ID in tile_IDs)
            foreach (Tile tile in calls[player])
                if (tile.ID == tile_ID)
                {
                    meld.tiles.add(tile);
                    break;
                }
        if (meld.tiles.size > 0)
            melds[player].add(meld);
    }

    private void move_call_tile(int discarder, int player, int tile_ID)
    {
        Tile? tile = remove_tile(ponds[discarder], tile_ID);
        if (tile != null)
        {
            calls[player].add(tile);
            if (discarder == last_discard_player)
            {
                last_discard_player = -1;
                last_discard_index = -1;
            }
        }
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

    public void set_call_decision_state(bool active)
    {
        call_decision_active = active;
        discard_attention_on = active;
        update_discard_attention();
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

        round_label.text = "%s %d  •  Wall %d  •  Dora".printf(
            WIND_TO_STRING(score.round_wind), score.current_round + 1, wall_remaining);
        for (int i = 0; i < dora_buttons.length; i++)
            dora_buttons[i].set_tile(i < wall.dora.size ? wall.dora[i] : null);
        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        top_label.text = opponent_summary(top);
        left_label.text = opponent_summary(left);
        right_label.text = opponent_summary(right);
        bottom_label.text = player_summary(observer_index);
        bottom_calls.text = calls[observer_index].size == 0 ? "" : "Calls: " + calls[observer_index].size.to_string();
        center_label.text = WIND_TO_KANJI(score.round_wind) + " " + (score.current_round + 1).to_string();
        center_top_wind.text = center_seat_text(top);
        center_left_wind.text = center_seat_text(left);
        center_right_wind.text = center_seat_text(right);
        center_bottom_wind.text = center_seat_text(observer_index);
        center_counters.text = "本場 %d  •  供託 %d".printf(
            score.renchan, score.riichi_count + current_round_riichi_count());
        refresh_tile_pools(top, left, right);
        refresh_hand();
    }

    private void refresh_tile_pools(int top, int left, int right)
    {
        int[] players = { observer_index, right, top, left };
        for (int seat = 0; seat < 4; seat++)
            for (int i = 0; i < 24; i++)
            {
                pond_buttons[seat * 24 + i].set_attention(false);
                pond_buttons[seat * 24 + i].set_tile(
                    i < ponds[players[seat]].size ? ponds[players[seat]][i] : null);
            }
        update_discard_attention();
    }

    private void update_discard_attention()
    {
        if (pond_buttons[0] == null || last_discard_player < 0 ||
            last_discard_index < 0 || last_discard_index >= 24)
            return;

        int seat = (last_discard_player - observer_index + 4) % 4;
        pond_buttons[seat * 24 + last_discard_index].set_attention(
            call_decision_active && discard_attention_on);
    }

    private string center_seat_text(int player)
    {
        // Compass initials are intentionally independent of screen side: the
        // player mapping above determines placement while the score state
        // determines the actual seat wind.
        return WIND_TO_STRING(score.players[player].wind).substring(0, 1);
    }

    private int current_round_riichi_count()
    {
        int count = 0;
        foreach (bool declared in riichi_players)
            if (declared)
                count++;
        return count;
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

    private string player_summary(int player)
    {
        return player_name(player) + (riichi_players[player] ? "  RIICHI" : "");
    }

    private string opponent_summary(int player)
    {
        return player_summary(player) + "  •  Hand " + hands[player].size.to_string();
    }

    private string player_name(int player)
    {
        GameScorePlayer p = score.players[player];
        return "%s  %s".printf(WIND_TO_KANJI(p.wind), p.name);
    }

}

private class Tile2DButton : Control
{
    private RectangleControl edge;
    private RectangleControl face;
    private ImageControl image;
    private LabelControl notation;
    private Tile? current_tile;
    private bool permitted;
    public signal void chosen(Tile tile);

    private TileTextureEnum texture_type;

    public Tile2DButton(TileTextureEnum texture_type)
    {
        this.texture_type = texture_type;
    }

    public override void pre_added()
    {
        resize_style = ResizeStyle.ABSOLUTE;
        size = Size2(58, 76);
        selectable = true;

        edge = new RectangleControl();
        add_child(edge);
        edge.resize_style = ResizeStyle.RELATIVE;
        edge.color = Color(0.01f, 0.01f, 0.01f, 1);

        face = new RectangleControl();
        add_child(face);
        face.resize_style = ResizeStyle.RELATIVE;
        face.relative_size = Size2(0.94f, 0.96f);
        face.inner_anchor = Vec2(0.5f, 0.5f);
        face.outer_anchor = Vec2(0.5f, 0.5f);

        image = new ImageControl.empty();
        add_child(image);
        image.resize_style = ResizeStyle.RELATIVE;
        image.relative_size = face.relative_size;
        image.inner_anchor = Vec2(0.5f, 0.5f);
        image.outer_anchor = Vec2(0.5f, 0.5f);

        notation = new LabelControl();
        add_child(notation);
        notation.font_size = 14;
        notation.color = Color.red();
        notation.inner_anchor = Vec2(1, 1);
        notation.outer_anchor = Vec2(1, 1);
        notation.position = Vec2(-4, -3);
    }

    public void set_tile(Tile tile, bool permitted)
    {
        current_tile = tile;
        this.permitted = permitted;
        image.set_texture(store.load_texture(tile_texture_name(tile, texture_type)));
        notation.text = tile_notation(tile.tile_type);
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

private class Tile2DDisplay : Control
{
    private TileTextureEnum texture_type;
    private ImageControl image;
    private RectangleControl edge;
    private RectangleControl face;
    private LabelControl notation;

    public Tile2DDisplay(TileTextureEnum texture_type)
    {
        this.texture_type = texture_type;
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void pre_added()
    {
        // A dark full-size layer remains visible around the inset face. This is
        // more reliable than texture filtering for crisp edges at small pond
        // sizes and remains correct when side discards are rotated.
        edge = new RectangleControl();
        add_child(edge);
        edge.resize_style = ResizeStyle.RELATIVE;
        edge.color = Color(0.01f, 0.01f, 0.01f, 1);

        face = new RectangleControl();
        add_child(face);
        face.resize_style = ResizeStyle.RELATIVE;
        face.relative_size = Size2(0.88f, 0.92f);
        face.inner_anchor = Vec2(0.5f, 0.5f);
        face.outer_anchor = Vec2(0.5f, 0.5f);
        face.color = Color(0.96f, 0.93f, 0.76f, 1);

        image = new ImageControl.empty();
        add_child(image);
        image.resize_style = ResizeStyle.RELATIVE;
        image.relative_size = face.relative_size;
        image.inner_anchor = Vec2(0.5f, 0.5f);
        image.outer_anchor = Vec2(0.5f, 0.5f);

        notation = new LabelControl();
        add_child(notation);
        notation.font_size = 10;
        notation.color = Color.red();
        notation.inner_anchor = Vec2(1, 1);
        notation.outer_anchor = Vec2(1, 1);
        notation.position = Vec2(-2, -1);
    }

    public void set_tile(Tile? tile)
    {
        visible = tile != null;
        if (tile == null)
            return;
        image.set_texture(store.load_texture(tile_texture_name(tile, texture_type)));
        notation.text = tile_notation(tile.tile_type);
    }

    public void set_attention(bool attention)
    {
        edge.color = attention ?
            Color(1, 0.82f, 0.08f, 1) : Color(0.01f, 0.01f, 0.01f, 1);
        image.diffuse_color = attention ?
            Color(1, 1, 1, 0.38f) : Color.white();
    }

    public float rotation
    {
        set
        {
            edge.rotation = value;
            face.rotation = value;
            image.rotation = value;
        }
    }
}

private static string tile_notation(TileType type)
{
    int value = (int)type;
    if (type >= TileType.MAN1 && type <= TileType.MAN9)
        return (value - (int)TileType.MAN1 + 1).to_string();
    if (type >= TileType.PIN1 && type <= TileType.PIN9)
        return (value - (int)TileType.PIN1 + 1).to_string();
    if (type >= TileType.SOU1 && type <= TileType.SOU9)
        return (value - (int)TileType.SOU1 + 1).to_string();
    if (type == TileType.TON) return "E";
    if (type == TileType.NAN) return "S";
    if (type == TileType.SHAA) return "W";
    if (type == TileType.PEI) return "N";
    if (type == TileType.HAKU) return "W";
    if (type == TileType.HATSU) return "G";
    if (type == TileType.CHUN) return "R";
    return "";
}

private static string tile_texture_name(Tile tile, TileTextureEnum texture_type)
{
    string texture = tile_texture_enum_to_string(texture_type);
    texture = texture[0].toupper().to_string() + texture.substring(1);
    string name = "Tiles/" + texture + "/" + TILE_TYPE_TO_STRING(tile.tile_type);
    return tile.dora ? name + "-Dora" : name;
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
