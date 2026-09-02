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
    private bool[] pending_riichi_discard = new bool[4];
    private int[] riichi_discard_index = new int[4];
    // Per player: the ID of the tile most recently drawn (and not yet
    // discarded), and, parallel to ponds[], whether each discard was a tedashi.
    private int[] last_drawn_id = new int[4];
    private ArrayList<bool>[] pond_tedashi = new ArrayList<bool>[4];

    private int observer_index;
    private int dealer_index;
    private int wall_remaining = 70;
    private bool active;
    private bool loaded_sent;
    private bool score_screen_visible;
    private bool score_reveal_ura;
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
    private Tile2DDisplay[] opponent_hand_buttons = new Tile2DDisplay[42];
    // Do not render Mahjong tiles as Unicode. Noto Sans CJK does not contain the
    // Mahjong Tiles block, so systems fall back to a broken/tofu glyph.  Use the
    // same PNG faces as the 3D renderer instead.
    private Tile2DDisplay[] pond_buttons = new Tile2DDisplay[96];
    private Tile2DDisplay[] dead_wall_buttons = new Tile2DDisplay[14];
    private Tile2DDisplay[] meld_buttons = new Tile2DDisplay[64];
    private RiichiStick2D[] riichi_sticks = new RiichiStick2D[4];
    private float meld_tile_width = 22;
    private float meld_tile_height = 30;
    private float[] meld_offsets = new float[64];
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
            riichi_discard_index[i] = -1;
            last_drawn_id[i] = -1;
            pond_tedashi[i] = new ArrayList<bool>();
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
        // Use the same inset dark-green frame as the score overlay. Keeping
        // this independent of the smaller pond geometry prevents the table
        // surface from changing size as discards accumulate.
        table_center.color = Color.with_alpha(0.45f);
        table_center.visible = true;

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
        // Top and bottom summaries share the pond center. Side summaries stay
        // outside the ponds, with the left one clear of the advisor panel.
        top_label = make_label(24, Vec2(0, -205), Vec2(0.5f, 1), Vec2(0.5f, 1));
        left_label = make_label(23, Vec2(0, 0), Vec2(0, 0.5f), Vec2(0, 0.5f));
        right_label = make_label(23, Vec2(-360, 0), Vec2(0, 0.5f), Vec2(1, 0.5f));
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
        for (int i = 0; i < opponent_hand_buttons.length; i++)
        {
            opponent_hand_buttons[i] = new Tile2DDisplay(texture_type);
            add_child(opponent_hand_buttons[i]);
            opponent_hand_buttons[i].set_back();
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
        for (int i = 0; i < riichi_sticks.length; i++)
        {
            riichi_sticks[i] = new RiichiStick2D();
            add_child(riichi_sticks[i]);
            riichi_sticks[i].visible = false;
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
        float table_offset = table_x_offset();
        // A full-size interactive hand dominated the lower third of the 2D
        // table. Keep it at 80% of the former dimensions, preserving enough
        // detail for selection while leaving the player summary unobstructed.
        float tile_width = float.min(62, (size.width - 48) / 14.0f) * 0.8f;
        float start = -(tile_width * 13) / 2;
        for (int i = 0; i < hand_buttons.length; i++)
        {
            hand_buttons[i].size = Size2(tile_width - 2, 76 * 0.8f);
            hand_buttons[i].position = Vec2(table_offset + start + i * tile_width, 92);
        }

        float table_width = float.min(620, size.width * 0.48f);
        table_center.size = Size2(size.width * 0.90f, size.height * 0.90f);
        table_center.position = Vec2(0, 0);
        center_plate.size = Size2(160, 160);
        center_plate.position = Vec2(table_offset, 0);
        // Nudged toward the top edge so a full third row of the across pond no
        // longer runs through the name/points line.
        top_label.position = Vec2(table_offset, -232);
        float score_frame_inset = size.width * 0.05f;
        // Mirror TileEfficiencyOverlay's responsive width and place the label
        // just beyond its right edge. This remains correct below desktop size,
        // where a fixed fraction could put the label underneath the panel.
        float guide_width = float.min(680,
            float.max(460, size.width * 0.48f));
        // The East summary previously sat just past the guide's right edge,
        // where the left player's stacked discard rows grew into it. The guide
        // is translucent now, so pull the label well left over its right
        // margin—clear of even a full three-row East pond.
        left_label.position = Vec2(float.max(24, 12 + guide_width - 210), 0);
        right_label.position = Vec2(-360 - score_frame_inset, 0);
        // Move the one-line name/points summary clear of both the compact hand
        // and any local open melds, and below a full third row of the own pond.
        bottom_label.position = Vec2(table_offset, 165);
        bottom_calls.position = Vec2(table_offset, 220);
        center_top_wind.position = Vec2(table_offset, 60);
        center_left_wind.position = Vec2(table_offset - 62, 0);
        center_right_wind.position = Vec2(table_offset + 62, 0);
        center_bottom_wind.position = Vec2(table_offset, -60);

        // At widths below roughly 30 pixels the detailed PNG faces collapse to
        // pale blocks under texture minification. Keep public information large
        // enough to read, with a black edge and room for a turned riichi tile.
        float display_width = float.min(34, float.max(28, (size.width - 430) / 30));
        float display_height = display_width * 1.35f;
        // A six-tile row spans roughly 220 px at desktop scale. The former
        // 84 px radius forced every horizontal pond through both side ponds.
        // This radius leaves a consistent gap even when a riichi tile turns.
        float pond_inner_radius = 145;
        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        int[] players = { observer_index, right, top, left };
        for (int seat = 0; seat < 4; seat++)
        {
            for (int i = 0; i < 24; i++)
            {
                Tile2DDisplay tile = pond_buttons[seat * 24 + i];
                int column = i % 6;
                int row = i / 6;
                tile.size = Size2(display_width - 2, display_height - 2);
                tile.inner_anchor = Vec2(0.5f, 0.5f);
                tile.outer_anchor = Vec2(0.5f, 0.5f);
                // RenderObject2D rotation is measured in half turns: +0.5 is
                // 90 degrees. Opposite side pools must face in opposite
                // directions so their tile bottoms point toward their player.
                bool declaration = i == riichi_discard_index[players[seat]];
                float base_rotation = seat == 1 ? 0.5f :
                    (seat == 2 ? 1.0f : (seat == 3 ? -0.5f : 0));
                tile.rotation = base_rotation + (declaration ? 0.5f : 0);

                // Match RenderPond's fixed six-column origin. Partial rows grow
                // from the same edge instead of sliding back to center after
                // every discard. A sideways declaration tile consumes its
                // visible height and shifts only the following tiles.
                int row_start = row * 6;
                float cursor = -3 * (display_width + 3);
                for (int j = 0; j < column; j++)
                    cursor += (row_start + j == riichi_discard_index[players[seat]] ?
                        display_height : display_width) + 3;
                float visible_width = declaration ? display_height : display_width;
                float across = cursor + visible_width / 2;
                float outward = pond_inner_radius + row * (display_height + 5);
                if (seat == 0)
                    tile.position = Vec2(table_offset + across, -outward);
                else if (seat == 2)
                    tile.position = Vec2(table_offset - across, outward);
                else if (seat == 1)
                    tile.position = Vec2(table_offset + outward, across);
                else
                    tile.position = Vec2(table_offset - outward, -across);
            }
        }

        // Keep the sizing code available for state/layout parity, but concealed
        // opponent hands are intentionally not drawn in the flat 2D view.
        float back_width = float.max(22, display_width - 10);
        float back_height = back_width * 1.35f;
        for (int seat = 1; seat < 4; seat++)
            for (int i = 0; i < 14; i++)
            {
                Tile2DDisplay tile = opponent_hand_buttons[(seat - 1) * 14 + i];
                tile.size = Size2(back_width, back_height);
                tile.inner_anchor = Vec2(0.5f, 0.5f);
                tile.rotation = seat == 1 ? 0.5f :
                    (seat == 2 ? 1.0f : (seat == 3 ? -0.5f : 0));
                float spread = (i - 6.5f) * (back_width + 2);
                if (seat == 2)
                {
                    // Use the same window-relative top anchor as top_label.
                    // A center anchor inverted this row into the local player's
                    // half of the table, where it resembled a stray wall.
                    tile.outer_anchor = Vec2(0.5f, 1);
                    tile.position = Vec2(table_offset + spread, -250);
                }
                else if (seat == 1)
                {
                    tile.outer_anchor = Vec2(0.5f, 0.5f);
                    tile.position = Vec2(table_offset + table_width / 2 + 42, spread);
                }
                else
                {
                    tile.outer_anchor = Vec2(0.5f, 0.5f);
                    tile.position = Vec2(table_offset - table_width / 2 - 42, -spread);
                }
            }

        // Place each riichi stick just inside its owner's pond. This reads as a
        // declaration by that player rather than an element of the console.
        const float RIICHI_STICK_RADIUS = 116;
        for (int seat = 0; seat < 4; seat++)
        {
            RiichiStick2D stick = riichi_sticks[seat];
            stick.size = Size2(66, 11);
            stick.inner_anchor = Vec2(0.5f, 0.5f);
            stick.outer_anchor = Vec2(0.5f, 0.5f);
            stick.rotation = seat == 1 ? 0.5f :
                (seat == 2 ? 1.0f : (seat == 3 ? -0.5f : 0));
            if (seat == 0)
                stick.position = Vec2(table_offset, -RIICHI_STICK_RADIUS);
            else if (seat == 2)
                stick.position = Vec2(table_offset, RIICHI_STICK_RADIUS);
            else if (seat == 1)
                stick.position = Vec2(table_offset + RIICHI_STICK_RADIUS, 0);
            else
                stick.position = Vec2(table_offset - RIICHI_STICK_RADIUS, 0);
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
        // Open information should be compact relative to the wall and ponds.
        // Three-quarter scale also lets several melds remain a single cluster.
        meld_tile_width = float.max(16, display_width * 0.75f);
        meld_tile_height = meld_tile_width * 1.35f;
        layout_melds();
    }

    private float table_x_offset()
    {
#if EFFICIENCY_LOGGING
        // Normal play and the scoring overlay must share one coordinate system;
        // otherwise the ponds jump left as soon as a round ends.
        return float.min(120, size.width * 0.07f);
#else
        return 0;
#endif
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
        Tile drawn = wall.draw_wall();
        hands[player_index].add(drawn);
        last_drawn_id[player_index] = drawn.ID;
        wall_remaining--;
        refresh();
    }

    public void dead_tile_draw(int player_index)
    {
        // Mirror GameScene.action_draw_dead_wall(): every successful kan first
        // exposes the next dora indicator, then draws/replenishes the dead wall.
        wall.flip_dora();
        Tile drawn = wall.draw_dead_wall();
        hands[player_index].add(drawn);
        last_drawn_id[player_index] = drawn.ID;
        wall_remaining--;
        refresh();
    }

    private void tile_discard(int player_index, int tile_ID)
    {
        Tile? tile = remove_tile(hands[player_index], tile_ID);
        if (tile != null)
        {
            ponds[player_index].add(tile);
            // A discard that is not the tile just drawn (including any discard
            // after a call, when nothing was drawn) came from the hand.
            pond_tedashi[player_index].add(tile_ID != last_drawn_id[player_index]);
            last_drawn_id[player_index] = -1;
            if (pending_riichi_discard[player_index])
            {
                riichi_discard_index[player_index] = ponds[player_index].size - 1;
                pending_riichi_discard[player_index] = false;
            }
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
        // The server announces riichi immediately before the declaration
        // discard. Remember that transition so the correct pond tile—not the
        // previously discarded tile—is turned sideways.
        pending_riichi_discard[player_index] = true;
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
        int removed_index = find_tile_index(ponds[discarder], tile_ID);
        Tile? tile = remove_tile(ponds[discarder], tile_ID);
        if (tile != null)
        {
            calls[player].add(tile);
            if (removed_index >= 0 && removed_index < pond_tedashi[discarder].size)
                pond_tedashi[discarder].remove_at(removed_index);
            if (removed_index == riichi_discard_index[discarder])
            {
                // If the declaration tile is called, the next discard remains
                // the visual declaration marker, matching the 3D pond logic.
                riichi_discard_index[discarder] = -1;
                pending_riichi_discard[discarder] = true;
            }
            else if (removed_index >= 0 &&
                removed_index < riichi_discard_index[discarder])
                riichi_discard_index[discarder]--;
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

    private static int find_tile_index(ArrayList<Tile> list, int tile_ID)
    {
        for (int i = 0; i < list.size; i++)
            if (list[i].ID == tile_ID)
                return i;
        return -1;
    }

    private void game_finished(RoundFinishResult results)
    {
        active = false;
        score_screen_visible = true;
        score_reveal_ura = false;
        if (results.result == RoundFinishResult.RoundResultEnum.RON ||
            results.result == RoundFinishResult.RoundResultEnum.TSUMO)
            foreach (Scoring scoring in results.scores)
                if (scoring.ura_dora)
                {
                    score_reveal_ura = true;
                    break;
                }
        call_decision_active = false;
        discard_attention_on = false;
        center_label.text = results.result == RoundFinishResult.RoundResultEnum.DRAW ?
            "ROUND DRAW" : (results.result == RoundFinishResult.RoundResultEnum.RON ? "RON" : "TSUMO");

        // The scoring menu is intentionally layered over the table so the four
        // public discard ponds remain visible.  Everything else belongs to the
        // live-play presentation and otherwise collides with score cards.
        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        refresh_tile_pools(top, left, right);
        refresh_hand();
        refresh_dead_wall();
        apply_score_screen_visibility();
        // Re-layout after hiding live-only objects without changing the table's
        // established normal-play alignment.
        resized();
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

        round_label.text = "%s %d  •  Wall %d".printf(
            WIND_TO_STRING(score.round_wind), score.current_round + 1, wall_remaining);
        center_label.text = "Round: %s %d  •  Dora / Dead Wall".printf(
            WIND_TO_STRING(score.round_wind), score.current_round + 1);
        center_counters.text = "Honba: %d  •  Riichi sticks: %d".printf(
            score.renchan, score.riichi_count + current_round_riichi_count());
        refresh_dead_wall();
        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        top_label.text = opponent_summary(top);
        left_label.text = opponent_summary(left);
        right_label.text = opponent_summary(right);
        bottom_label.text = player_summary(observer_index);
        bottom_calls.text = "";
        center_top_wind.text = center_seat_text(top);
        center_left_wind.text = center_seat_text(left);
        center_right_wind.text = center_seat_text(right);
        center_bottom_wind.text = center_seat_text(observer_index);
        refresh_tile_pools(top, left, right);
        refresh_opponent_hands(top, left, right);
        refresh_melds();
        refresh_hand();
        if (score_screen_visible)
            apply_score_screen_visibility();
        // Discard row centering and declaration-tile rotation depend on the
        // current pond sizes, so state changes need the same geometry pass as
        // a window resize.
        resized();
    }

    private void apply_score_screen_visibility()
    {
        // Retain the four public ponds, but remove the live-play mat behind
        // them. The scoring view provides its own centered background.
        table_center.visible = false;
        center_plate.visible = false;
        top_label.visible = false;
        left_label.visible = false;
        right_label.visible = false;
        bottom_label.visible = false;
        bottom_calls.visible = false;

        foreach (Tile2DButton button in hand_buttons)
            button.visible = false;
        // The dora/dead-wall block is a persistent round-status element. Keep
        // it in the same upper-right location while the score layer is open.
        // Open melds are public information and remain visible beneath the
        // translucent score overlay, just like each player's discard pond.
        foreach (Tile2DDisplay button in opponent_hand_buttons)
            button.visible = false;
        foreach (RiichiStick2D stick in riichi_sticks)
            stick.visible = false;
    }

    private void refresh_dead_wall()
    {
        for (int i = 0; i < dead_wall_buttons.length; i++)
        {
            Tile? tile = wall.get_dead_wall_tile(i);
            if (tile == null)
                dead_wall_buttons[i].visible = false;
            else if (wall.dead_wall_tile_revealed(i,
                score_screen_visible && score_reveal_ura))
                dead_wall_buttons[i].set_tile(tile);
            else
                dead_wall_buttons[i].set_back();
        }
    }

    private void refresh_melds()
    {
        for (int i = 0; i < meld_buttons.length; i++)
            meld_buttons[i].visible = false;

        int top = (observer_index + 2) % 4;
        int left = (observer_index + 3) % 4;
        int right = (observer_index + 1) % 4;
        int[] players = { observer_index, right, top, left };

        // meld_offsets holds each tile's centre position along the meld axis.
        // Space consecutive centres by the two tiles' half-footprints (a
        // sideways called tile is wider along the axis than an upright one)
        // plus one fixed gap, so every gap is equal and nothing overlaps.
        float tile_gap = 2;
        float meld_gap = 6;
        for (int seat = 0; seat < 4; seat++)
        {
            int slot = 0;
            float cursor = 0;
            float prev_half = 0;
            bool placed = false;
            float pending_gap = tile_gap;
            foreach (Meld2D meld in melds[players[seat]])
            {
                ArrayList<Tile> ordered = ordered_meld_tiles(meld);
                for (int i = 0; i < ordered.size && slot < 16; i++, slot++)
                {
                    int button_index = seat * 16 + slot;
                    Tile2DDisplay button = meld_buttons[button_index];
                    bool turned = ordered[i].ID == meld.called_tile_ID ||
                        ordered[i].ID == meld.added_tile_ID;
                    bool concealed_back = meld.closed && (i == 0 || i == ordered.size - 1);
                    if (concealed_back)
                        button.set_back();
                    else
                        button.set_tile(ordered[i]);
                    float base_rotation = seat == 1 ? 0.5f :
                        (seat == 2 ? 1.0f : (seat == 3 ? -0.5f : 0));
                    button.rotation = base_rotation + (turned ? 0.5f : 0);

                    float half = (turned ? meld_tile_height : meld_tile_width) / 2;
                    if (placed)
                        cursor += prev_half + half + pending_gap;
                    meld_offsets[button_index] = cursor;
                    prev_half = half;
                    placed = true;
                    pending_gap = tile_gap;
                }
                pending_gap = meld_gap;
            }
        }
        layout_melds();
    }

    private void refresh_opponent_hands(int top, int left, int right)
    {
        for (int group = 0; group < 3; group++)
            for (int i = 0; i < 14; i++)
            {
                Tile2DDisplay tile = opponent_hand_buttons[group * 14 + i];
                tile.visible = false;
            }

        int[] seats = { observer_index, right, top, left };
        for (int seat = 0; seat < 4; seat++)
            riichi_sticks[seat].visible = !score_screen_visible &&
                riichi_players[seats[seat]];
    }

    private ArrayList<Tile> ordered_meld_tiles(Meld2D meld)
    {
        ArrayList<Tile> ordered = new ArrayList<Tile>();
        Tile? called = null;
        foreach (Tile tile in meld.tiles)
            if (tile.ID == meld.called_tile_ID)
                called = tile;
            else
                ordered.add(tile);

        if (called == null)
        {
            ordered.clear();
            ordered.add_all(meld.tiles);
            return ordered;
        }

        int relative_source = (meld.discarder - meld.player + 4) % 4;
        int called_slot = relative_source == 3 ? 0 :
            (relative_source == 2 ? 1 : ordered.size);
        ordered.insert(int.min(called_slot, ordered.size), called);
        return ordered;
    }

    private void layout_melds()
    {
        if (meld_buttons[0] == null)
            return;
        float table_offset = table_x_offset();
        for (int seat = 0; seat < 4; seat++)
            for (int slot = 0; slot < 16; slot++)
            {
                int index = seat * 16 + slot;
                Tile2DDisplay tile = meld_buttons[index];
                tile.size = Size2(meld_tile_width, meld_tile_height);
                tile.inner_anchor = Vec2(0.5f, 0.5f);
                float tile_offset = meld_offsets[index];
                if (seat == 0)
                {
                    tile.outer_anchor = Vec2(0.5f, 0);
                    tile.position = Vec2(table_offset + 310 - tile_offset, 190);
                }
                else if (seat == 2)
                {
                    tile.outer_anchor = Vec2(0.5f, 1);
                    tile.position = Vec2(table_offset - 310 + tile_offset, -190);
                }
                else if (seat == 1)
                {
                    tile.outer_anchor = Vec2(1, 0.5f);
                    tile.position = Vec2(table_offset - 285, -210 + tile_offset);
                }
                else
                {
                    tile.outer_anchor = Vec2(0, 0.5f);
                    tile.position = Vec2(table_offset + 285, 210 - tile_offset);
                }
            }
    }

    private void refresh_tile_pools(int top, int left, int right)
    {
        int[] players = { observer_index, right, top, left };
        for (int seat = 0; seat < 4; seat++)
            for (int i = 0; i < 24; i++)
            {
                Tile2DDisplay button = pond_buttons[seat * 24 + i];
                button.set_attention(false);
                bool present = i < ponds[players[seat]].size;
                button.set_tile(present ? ponds[players[seat]][i] : null);
                // Only the three opponents get the tedashi pip; the observer
                // already knows which of their own discards came from hand.
                button.set_tedashi(present && seat != 0 &&
                    i < pond_tedashi[players[seat]].size &&
                    pond_tedashi[players[seat]][i]);
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
            // Late inactive/selection actions can arrive while the scoring
            // overlay is opening. Never let those refreshes restore the live
            // hand after game_finished() has switched presentation states.
            bool shown = !score_screen_visible && i < sorted.size;
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
        int points = score.players[player].points;
        if (riichi_players[player])
            points -= 1000;
        return "%s%s  •  %d".printf(
            player_name(player),
            riichi_players[player] ? "  RIICHI" : "",
            points);
    }

    private string opponent_summary(int player)
    {
        return player_summary(player);
    }

    private string player_name(int player)
    {
        GameScorePlayer p = score.players[player];
        return "%s %s  %s".printf(
            WIND_TO_KANJI(p.wind),
            WIND_TO_STRING(p.wind).substring(0, 1),
            p.name);
    }

}

private class Meld2D : Object
{
    public Meld2D(int player, int discarder, int called_tile_ID, bool closed)
    {
        this.player = player;
        this.discarder = discarder;
        this.called_tile_ID = called_tile_ID;
        this.closed = closed;
        tiles = new ArrayList<Tile>();
    }

    public int player { get; private set; }
    public int discarder { get; private set; }
    public int called_tile_ID { get; private set; }
    public int added_tile_ID { get; set; default = -1; }
    public bool closed { get; private set; }
    public ArrayList<Tile> tiles { get; private set; }
}

private class RotatableLabelControl : LabelControl
{
    public float rotation
    {
        set
        {
            RenderObject2D? object_2d = get_obj();
            if (object_2d != null)
                object_2d.rotation = value;
        }
    }
}

private class TileNotation : Control
{
    // A single thin glyph, kept crisp rather than fake-bolded by stacked
    // offset copies. TileNotation is added after the face image, so it stays
    // above the artwork for hands, ponds, melds, and the dead wall.
    private RotatableLabelControl[] labels = new RotatableLabelControl[1];
    private float text_size;
    private Vec2 text_position;
    private float current_rotation;

    public TileNotation(float text_size, Vec2 text_position)
    {
        this.text_size = text_size;
        this.text_position = text_position;
        resize_style = ResizeStyle.RELATIVE;
    }

    public override void pre_added()
    {
        for (int i = 0; i < labels.length; i++)
        {
            labels[i] = new RotatableLabelControl();
            add_child(labels[i]);
            labels[i].font_size = text_size;
            // A saturated, near-pure red reads more sharply against the cream
            // face than the former muddier tone at these small sizes.
            labels[i].color = Color(0.85f, 0.0f, 0.0f, 1);
            labels[i].scissor = true;
        }
        apply_orientation();
    }

    protected override void resized()
    {
        apply_orientation();
        update_clip();
    }

    private void update_clip()
    {
        if (labels[0] == null)
            return;
        // Clip the marker to the inset white face. A side tile's
        // render geometry is rotated while its control rect is not, so swap the
        // face dimensions for quarter turns before constructing the clip.
        float normalized = current_rotation % 2;
        if (normalized < 0)
            normalized += 2;
        bool quarter_turn = (normalized > 0.25f && normalized < 0.75f) ||
            (normalized > 1.25f && normalized < 1.75f);
        float face_width = (quarter_turn ? rect.height : rect.width) * 0.86f;
        float face_height = (quarter_turn ? rect.width : rect.height) * 0.90f;
        Rectangle face_clip = Rectangle(
            rect.x + (rect.width - face_width) / 2,
            rect.y + (rect.height - face_height) / 2,
            face_width, face_height);
        foreach (RotatableLabelControl label in labels)
            if (label != null)
                label.scissor_box = face_clip;
    }

    public string text
    {
        set
        {
            foreach (RotatableLabelControl label in labels)
                label.text = value;
            // Label dimensions change with the glyph (for example "1" versus
            // "W"), so recompute the face-relative corner after assignment.
            apply_orientation();
        }
    }

    public float rotation
    {
        set
        {
            current_rotation = value;
            foreach (RotatableLabelControl label in labels)
                label.rotation = value;
            apply_orientation();
            update_clip();
        }
    }

    private void apply_orientation()
    {
        if (labels[0] == null)
            return;
        float normalized = current_rotation % 2;
        if (normalized < 0)
            normalized += 2;

        // Marker corner, in screen space (+x right, +y up). The own hand reads
        // top-right like a card index; the three rotated ponds put it along the
        // bottom edge, angled toward the table centre so it stays readable from
        // the observer's seat: right-seat pond bottom-left, across-seat pond
        // bottom-left, left-seat pond bottom-right. Snap to whole pixels.
        float inset_x = text_position.x.abs();
        float inset_y = text_position.y.abs();
        float base_x = float.max(0, rect.width / 2 - labels[0].size.width / 2 - inset_x);
        float base_y = float.max(0, rect.height / 2 - labels[0].size.height / 2 - inset_y);
        Vec2 base_position;
        if (normalized > 0.25f && normalized < 0.75f)
            base_position = Vec2(-base_x, -base_y);     // right seat -> bottom-left
        else if (normalized > 0.75f && normalized < 1.25f)
            base_position = Vec2(-base_x, -base_y);     // across seat -> bottom-left
        else if (normalized > 1.25f && normalized < 1.75f)
            base_position = Vec2(base_x, -base_y);      // left seat -> bottom-right
        else
            base_position = Vec2(base_x, base_y);       // own hand -> top-right
        base_position = Vec2(
            Math.roundf(base_position.x), Math.roundf(base_position.y));

        Vec2[] weight_offsets = { Vec2(0, 0) };
        for (int i = 0; i < labels.length; i++)
        {
            labels[i].inner_anchor = Vec2(0.5f, 0.5f);
            labels[i].outer_anchor = Vec2(0.5f, 0.5f);
            labels[i].position = base_position.plus(weight_offsets[i]);
        }
    }
}

private class Tile2DButton : Control
{
    private RectangleControl edge;
    private RectangleControl face;
    private ImageControl image;
    private TileNotation notation;
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
        face.relative_size = Size2(0.92f, 0.94f);
        face.inner_anchor = Vec2(0.5f, 0.5f);
        face.outer_anchor = Vec2(0.5f, 0.5f);

        image = new ImageControl.empty();
        add_child(image);
        image.resize_style = ResizeStyle.RELATIVE;
        image.relative_size = face.relative_size;
        image.inner_anchor = Vec2(0.5f, 0.5f);
        image.outer_anchor = Vec2(0.5f, 0.5f);

        notation = new TileNotation(14, Vec2(-3, -3));
        add_child(notation);
        notation.scissor = true;
    }

    public void set_tile(Tile tile, bool permitted)
    {
        current_tile = tile;
        this.permitted = permitted;
        // The 2D shader adds diffuse RGB to the sampled texture. A zero-RGB
        // color preserves the original ink exactly; white would wash it out.
        image.diffuse_color = Color.with_alpha(1);
        image.set_texture(store.load_texture(tile_texture_name(tile, texture_type)));
        notation.text = tile_notation(tile.tile_type);
        face.color = permitted ? Color(0.94f, 0.88f, 0.55f, 1) : Color(0.96f, 0.96f, 0.93f, 1);
    }

    protected override void resized()
    {
        if (notation != null)
            notation.scissor_box = rect;
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

private class RiichiStick2D : Control
{
    private RectangleControl edge;
    private RectangleControl body;
    private RotatableLabelControl dot;

    public RiichiStick2D()
    {
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void pre_added()
    {
        edge = new RectangleControl();
        add_child(edge);
        edge.resize_style = ResizeStyle.RELATIVE;
        edge.color = Color(0.02f, 0.02f, 0.02f, 1);

        body = new RectangleControl();
        add_child(body);
        body.resize_style = ResizeStyle.RELATIVE;
        body.relative_size = Size2(0.96f, 0.78f);
        body.inner_anchor = Vec2(0.5f, 0.5f);
        body.outer_anchor = Vec2(0.5f, 0.5f);
        body.color = Color(0.96f, 0.96f, 0.93f, 1);

        // A riichi declaration stick has one centered red mark. Using a label
        // avoids the two-dot source texture being stretched into a red bar.
        dot = new RotatableLabelControl();
        add_child(dot);
        dot.text = "●";
        dot.font_size = 11;
        dot.color = Color(0.78f, 0.02f, 0.02f, 1);
        dot.inner_anchor = Vec2(0.5f, 0.5f);
        dot.outer_anchor = Vec2(0.5f, 0.5f);
    }

    public float rotation
    {
        set
        {
            edge.rotation = value;
            body.rotation = value;
            dot.rotation = value;
        }
    }
}

private class Tile2DDisplay : Control
{
    private TileTextureEnum texture_type;
    private ImageControl image;
    private RectangleControl edge;
    private RectangleControl face;
    private RectangleControl tedashi_mark;
    private TileNotation notation;

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
        face.color = Color(0.96f, 0.96f, 0.93f, 1);

        image = new ImageControl.empty();
        add_child(image);
        image.resize_style = ResizeStyle.RELATIVE;
        image.relative_size = face.relative_size;
        image.inner_anchor = Vec2(0.5f, 0.5f);
        image.outer_anchor = Vec2(0.5f, 0.5f);

        notation = new TileNotation(11, Vec2(-4, -4));
        add_child(notation);
        notation.scissor = true;

        // A small corner pip marks a tedashi discard (a tile that was already
        // in the player's hand) so it can be told apart from a tsumogiri (the
        // tile just drawn). Added last so it stays above the face artwork.
        tedashi_mark = new RectangleControl();
        add_child(tedashi_mark);
        tedashi_mark.resize_style = ResizeStyle.ABSOLUTE;
        tedashi_mark.size = Size2(6, 6);
        tedashi_mark.inner_anchor = Vec2(0, 1);
        tedashi_mark.outer_anchor = Vec2(0, 1);
        tedashi_mark.position = Vec2(3, -3);
        tedashi_mark.color = Color(1, 0.55f, 0.05f, 1);
        tedashi_mark.visible = false;
    }

    public void set_tedashi(bool tedashi)
    {
        tedashi_mark.visible = tedashi;
    }

    public void set_tile(Tile? tile)
    {
        visible = tile != null;
        if (tile == null)
            return;
        image.visible = true;
        notation.visible = true;
        tedashi_mark.visible = false;
        edge.color = Color(0.01f, 0.01f, 0.01f, 1);
        face.color = Color(0.96f, 0.96f, 0.93f, 1);
        // OpenGL2DShaderBuilder uses diffuse RGB as an additive tint. Keep the
        // RGB channels at zero to render the same unmodified face texture used
        // by RenderTile in the 3D pond.
        image.diffuse_color = Color.with_alpha(1);
        image.set_texture(store.load_texture(tile_texture_name(tile, texture_type)));
        notation.text = tile_notation(tile.tile_type);
    }

    public void set_back()
    {
        visible = true;
        image.visible = false;
        notation.visible = false;
        tedashi_mark.visible = false;
        face.color = Color(0.02f, 0.42f, 0.66f, 1);
        edge.color = Color(0.01f, 0.12f, 0.18f, 1);
    }

    public void set_attention(bool attention)
    {
        edge.color = attention ?
            Color(1, 0.82f, 0.08f, 1) : Color(0.01f, 0.01f, 0.01f, 1);
        // Flash the border only. The shader adds diffuse RGB to the texture, so
        // Color.white() would saturate every discard face to white on refresh.
        image.diffuse_color = Color.with_alpha(1);
    }

    public float rotation
    {
        set
        {
            edge.rotation = value;
            face.rotation = value;
            image.rotation = value;
            notation.rotation = value;
        }
    }

    protected override void resized()
    {
        if (notation != null)
            notation.scissor_box = rect;
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
    // White dragon is "B" (blank) so it is never confused with the west wind.
    if (type == TileType.HAKU) return "B";
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
