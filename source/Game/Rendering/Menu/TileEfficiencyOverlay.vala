using Engine;
using Gee;

class TileEfficiencyOverlay : Control
{
    private const float PADDING = 12;
    private const float TEXT_SIZE = 14;
    private const float TILE_SIZE = 42;
    // Keep only the top hand summary compact; recommendation tiles below must
    // remain large enough to identify at a glance.
    private const float HAND_TILE_SIZE = TILE_SIZE * 0.5f;
    private const float LINE_HEIGHT = 30;
    private const float EMPTY_LINE_HEIGHT = 6;

    private RectangleControl background;
    private ArrayList<LabelControl> labels = new ArrayList<LabelControl>();
    private string results = "Tile Efficiency Guide\n\nWaiting for your next turn...";
    private bool minimized = false;
    private float expanded_height;

    public override void added()
    {
        resize_style = ResizeStyle.ABSOLUTE;
        inner_anchor = Vec2(0, 1);
        outer_anchor = Vec2(0, 1);
        position = Vec2(12, -12);
        size = Size2(
            float.min(680, float.max(460, window_size.width * 0.48f)),
            float.min(820, float.max(360, window_size.height - 24)));
        expanded_height = size.height;
        selectable = true;

        background = new RectangleControl();
        add_child(background);
        background.resize_style = ResizeStyle.RELATIVE;
        // Keep the guide readable without covering the table underneath it.
        background.color = Color(0, 0, 0, 0);

        scissor = true;
        scissor_box = rect;
        rebuild();
    }

    public void show_results(string new_results)
    {
        results = new_results;
        if (!minimized)
            rebuild();
    }

    public void show_waiting()
    {
        results = "TILE EFFICIENCY GUIDE\n\nWaiting for your next turn...";
        if (!minimized)
            rebuild();
    }

    public void toggle_minimized()
    {
        minimized = !minimized;
        size = Size2(size.width, minimized ? 44 : expanded_height);
        rebuild();
    }

    protected override void resized()
    {
        scissor_box = rect;
    }

    private void rebuild()
    {
        foreach (LabelControl label in labels)
            remove_child(label);
        labels.clear();

        if (minimized)
        {
            string heading = results.has_prefix("ACTION EFFICIENCY GUIDE") ?
                "ACTION EFFICIENCY GUIDE — Click to expand" :
                "TILE EFFICIENCY GUIDE — Click to expand";
            add_rich_line(heading, PADDING, 7,
                size.width - PADDING * 2);
            return;
        }

        string[] lines = results.split("\n");
        if (results.has_prefix("ACTION EFFICIENCY GUIDE"))
        {
            float action_y = PADDING;
            for (int i = 0; i < lines.length; i++)
                action_y = add_rich_line(lines[i], PADDING, action_y,
                    size.width - PADDING * 2, false);
            return;
        }

        int defense_start = lines.length;
        for (int i = 0; i < lines.length; i++)
            if (lines[i] == "DEFENSIVE PLAY")
            {
                defense_start = i;
                break;
            }

        float y = PADDING;
        int common_lines = int.min(3, defense_start);
        for (int i = 0; i < common_lines; i++)
            y = add_rich_line(lines[i], PADDING, y, size.width - PADDING * 2,
                i == 0);

        float section_y = y + 2;
        // Efficiency rows are short. Giving them half of the overlay created a
        // large dead column before the defensive advice, especially on wide
        // windows. Keep that column compact and give the remaining width to
        // defensive text.
        float column_gap = 10;
        float column_width = float.min(150, size.width * 0.27f);
        float left_y = section_y;
        for (int i = common_lines; i < defense_start; i++)
            left_y = add_rich_line(lines[i], PADDING, left_y, column_width);

        if (defense_start < lines.length)
        {
            float right_x = PADDING + column_width + column_gap;
            float right_width = size.width - right_x - PADDING;
            float right_y = section_y;
            for (int i = defense_start; i < lines.length; i++)
                right_y = add_rich_line(lines[i], right_x, right_y, right_width);
        }
    }

    private float add_rich_line(string line, float start_x, float y,
        float max_width, bool compact_tiles = false)
    {
        if (line.length == 0)
            return y + EMPTY_LINE_HEIGHT;

        float x = start_x;
        foreach (string token in line.split(" "))
        {
            if (token.length == 0)
                continue;

            bool tile = is_tile_emoji(token);
            LabelControl label = new LabelControl();
            add_child(label);
            labels.add(label);
            label.scissor = true;
            label.scissor_box = rect;
            label.inner_anchor = Vec2(0, 1);
            label.outer_anchor = Vec2(0, 1);
            label.font_size = tile ?
                (compact_tiles ? HAND_TILE_SIZE : TILE_SIZE) : TEXT_SIZE;
            // The engine trims normal text bitmaps vertically. Blank lines give
            // full-height Mahjong glyphs enough transparent padding to avoid it.
            label.text = tile ? "\n%s\n".printf(token) : token;

            if (x > start_x && x + label.size.width > start_x + max_width)
            {
                x = start_x;
                y += LINE_HEIGHT;
            }

            float tile_padding = tile ? label.size.height / 5 : 0;
            float vertical_position = tile
                ? -(y - tile_padding)
                : -(y + (LINE_HEIGHT - TEXT_SIZE) / 2);
            label.position = Vec2(x, vertical_position);
            x += label.size.width + (tile ? 4 : 5);
        }

        return y + LINE_HEIGHT;
    }

    private static bool is_tile_emoji(string token)
    {
        const string symbols = "🀇🀈🀉🀊🀋🀌🀍🀎🀏🀙🀚🀛🀜🀝🀞🀟🀠🀡🀐🀑🀒🀓🀔🀕🀖🀗🀘🀀🀁🀂🀃🀆🀅🀄";
        return token.char_count() == 1 && symbols.contains(token);
    }

}
