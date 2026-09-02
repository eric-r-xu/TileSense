using Engine;
using Gee;

class TileEfficiencyOverlay : Control
{
    private const float PADDING = 12;
    private const float TEXT_SIZE = 14;
    private const float TILE_SIZE = 42;
    private const float LINE_HEIGHT = 30;
    private const float EMPTY_LINE_HEIGHT = 6;
    private const float CELL_PADDING = 3;
    private const float GRID_THICKNESS = 1;
    // Tile glyph shown, centred, in the first column of the gridded tables.
    private const float TABLE_TILE_SIZE = TILE_SIZE * 0.82f;

    private RectangleControl background;
    private ArrayList<LabelControl> labels = new ArrayList<LabelControl>();
    private ArrayList<RectangleControl> grid_lines = new ArrayList<RectangleControl>();
    private string results = "EXPECTED VALUE / EFFICIENCY\n\nWaiting for your next turn...";
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
        // The expandable guide is deliberately half-transparent so the table
        // behind it stays readable; the gridlines on the EV and defence
        // sections keep those rows legible over whatever shows through.
        background.color = Color(0.012f, 0.065f, 0.07f, 0.5f);

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
        results = "EXPECTED VALUE / EFFICIENCY\n\nWaiting for your next turn...";
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
        foreach (RectangleControl line in grid_lines)
            remove_child(line);
        grid_lines.clear();

        if (minimized)
        {
            string heading = results.has_prefix("ACTION EFFICIENCY GUIDE") ?
                "ACTION EFFICIENCY GUIDE — Click to expand" :
                "GUIDE — Click to expand";
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
        int legend_start = lines.length;
        for (int i = 0; i < lines.length; i++)
        {
            if (lines[i] == "DEFENSIVE PLAY" && defense_start == lines.length)
                defense_start = i;
            if (lines[i] == "LEGEND")
            {
                legend_start = i;
                break;
            }
        }

        float section_y = PADDING;
        int content_start = 0;
        // The autoplay choice sits on its own row across the top; both tables
        // start well below it so the tall inline tile glyph has clear headroom
        // and never overlaps the headings.
        if (lines.length > 0 && lines[0].has_prefix("AUTOPLAY CHOICE:"))
        {
            add_rich_line(lines[0], PADDING, PADDING + 34,
                size.width - PADDING * 2, false, LINE_HEIGHT);
            section_y = PADDING + 34 + LINE_HEIGHT + 24;
            content_start = 1;
        }

        // The recommendation side and defensive side remain independent so
        // neither section can flow underneath the other.
        float column_gap = 10;
        // The efficiency/EV field is roughly half its former width; the
        // defensive table is pulled in close beside it rather than left in a
        // wide dead gap.
        float column_width = float.min(210, size.width * 0.32f);
        render_column(lines, content_start, int.min(defense_start, legend_start),
            PADDING, section_y, column_width);

        if (defense_start < legend_start)
        {
            float right_x = PADDING + column_width + column_gap;
            float right_width = size.width - right_x - PADDING;
            render_column(lines, defense_start, legend_start, right_x,
                section_y, right_width);
        }

        // The acronym key is pinned to the bottom-left of the panel, one size.
        if (legend_start + 1 < lines.length)
        {
            float footer_lh = LINE_HEIGHT * 0.72f;
            int footer_count = lines.length - (legend_start + 1);
            float footer_y = float.max(section_y,
                size.height - PADDING - footer_count * footer_lh);
            for (int i = legend_start + 1; i < lines.length; i++)
                footer_y = add_rich_line(lines[i], PADDING, footer_y,
                    size.width - PADDING * 2, false, footer_lh);
        }
    }

    // Render a slice of the guide. A contiguous run of tab-separated lines is
    // drawn as a bordered two-column table (DISCARD / detail); every other
    // line is plain rich text, exactly as before.
    private void render_column(string[] lines, int start, int end,
        float x, float y, float width)
    {
        int i = start;
        while (i < end)
        {
            if (lines[i].contains("\t"))
            {
                int run_end = i;
                while (run_end < end && lines[run_end].contains("\t"))
                    run_end++;
                y = add_table(lines, i, run_end, x, y, width);
                i = run_end;
            }
            else
            {
                bool heading = lines[i] == "EXPECTED VALUE / EFFICIENCY" ||
                    lines[i] == "DEFENSIVE PLAY";
                float next_y = add_rich_line(lines[i], x, y, width, false,
                    LINE_HEIGHT);
                if (heading)
                {
                    float rule_y = y + (LINE_HEIGHT - TEXT_SIZE) / 2 +
                        TEXT_SIZE + 2;
                    float rule_w = float.min(width,
                        lines[i].length * TEXT_SIZE * 0.62f);
                    add_grid_line(x, rule_y, rule_w, GRID_THICKNESS);
                }
                y = next_y;
                i++;
            }
        }
    }

    private float add_table(string[] lines, int start, int end,
        float start_x, float y, float width)
    {
        bool safety_table = lines[start].has_prefix("DISCARD\tSAFETY");
        float first_col_width = float.min(84, width * 0.26f);
        // The safety detail sits in a deliberately narrow column so its
        // score and description wrap onto separate lines.
        float detail_width = safety_table ?
            float.min(width - first_col_width, 128) : width - first_col_width;
        float table_width = first_col_width + detail_width;
        float[] col_x = { start_x, start_x + first_col_width };
        float[] col_w = { first_col_width, detail_width };

        float table_top = y;
        float[] row_tops = new float[end - start + 1];
        float row_y = y;
        for (int r = start; r < end; r++)
        {
            row_tops[r - start] = row_y;
            string[] cells = lines[r].split("\t");
            bool tile_row = cells.length > 0 && first_token_is_tile(cells[0]);
            float row_height = tile_row ? TABLE_TILE_SIZE + 4 : LINE_HEIGHT * 0.7f;
            float row_bottom = row_y + row_height;
            for (int c = 0; c < 2 && c < cells.length; c++)
            {
                // First column: the tile glyph, centred in its cell.
                float cell_bottom = add_rich_line(cells[c],
                    col_x[c] + CELL_PADDING, row_y + CELL_PADDING,
                    col_w[c] - CELL_PADDING * 2, c == 0,
                    c == 0 ? row_height : 15, TEXT_SIZE, c == 0);
                row_bottom = float.max(row_bottom, cell_bottom + CELL_PADDING);
            }
            row_y = row_bottom;
        }
        row_tops[end - start] = row_y;

        // A rule above every row plus a closing rule, and the three column
        // edges, so each cell is fully boxed.
        for (int r = 0; r <= end - start; r++)
            add_grid_line(start_x, row_tops[r], table_width, GRID_THICKNESS);
        add_grid_line(start_x, table_top, GRID_THICKNESS, row_y - table_top);
        add_grid_line(start_x + first_col_width, table_top, GRID_THICKNESS,
            row_y - table_top);
        add_grid_line(start_x + table_width - GRID_THICKNESS, table_top,
            GRID_THICKNESS, row_y - table_top);

        return row_y + 2;
    }

    private void add_grid_line(float x, float y, float w, float h)
    {
        RectangleControl line = new RectangleControl();
        add_child(line);
        grid_lines.add(line);
        line.resize_style = ResizeStyle.ABSOLUTE;
        line.inner_anchor = Vec2(0, 1);
        line.outer_anchor = Vec2(0, 1);
        line.scissor = true;
        line.scissor_box = rect;
        line.color = Color(0.34f, 0.46f, 0.49f, 0.85f);
        line.size = Size2(float.max(GRID_THICKNESS, w), float.max(GRID_THICKNESS, h));
        line.position = Vec2(x, -y);
    }

    private static bool first_token_is_tile(string cell)
    {
        foreach (string token in cell.split(" "))
            if (token.length > 0)
                return is_tile_emoji(token);
        return false;
    }

    private float add_rich_line(string line, float start_x, float y,
        float max_width, bool compact_tiles = false,
        float line_height = LINE_HEIGHT, float text_size = TEXT_SIZE,
        bool center = false)
    {
        if (line.length == 0)
            return y + EMPTY_LINE_HEIGHT;

        float tile_size = compact_tiles ? TABLE_TILE_SIZE : TILE_SIZE;

        // Build every token first so a centred line can be measured before it
        // is positioned.
        ArrayList<LabelControl> tokens = new ArrayList<LabelControl>();
        ArrayList<bool> token_is_tile = new ArrayList<bool>();
        float run_width = 0;
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
            label.font_size = tile ? tile_size : text_size;
            // The engine trims normal text bitmaps vertically. Blank lines give
            // full-height Mahjong glyphs enough transparent padding to avoid it.
            label.text = tile ? "\n%s\n".printf(token) : token;
            tokens.add(label);
            token_is_tile.add(tile);
            run_width += label.size.width + (tile ? 4 : 5);
        }

        float x = start_x;
        if (center && run_width < max_width)
            x = start_x + (max_width - run_width) / 2;

        for (int t = 0; t < tokens.size; t++)
        {
            LabelControl label = tokens[t];
            bool tile = token_is_tile[t];

            if (!center && x > start_x &&
                x + label.size.width > start_x + max_width)
            {
                x = start_x;
                y += line_height;
            }

            // A padded glyph label is taller than the visible tile. The default
            // lifts it by a fifth; inside a table row, centre it on the row
            // instead so the tile sits within its gridlines.
            float tile_padding = !tile ? 0 :
                (compact_tiles ? label.size.height / 2 - line_height / 2
                               : label.size.height / 5);
            float vertical_position = tile
                ? -(y - tile_padding)
                : -(y + (line_height - text_size) / 2);
            label.position = Vec2(x, vertical_position);
            x += label.size.width + (tile ? 4 : 5);
        }

        return y + line_height;
    }

    private static bool is_tile_emoji(string token)
    {
        const string symbols = "🀇🀈🀉🀊🀋🀌🀍🀎🀏🀙🀚🀛🀜🀝🀞🀟🀠🀡🀐🀑🀒🀓🀔🀕🀖🀗🀘🀀🀁🀂🀃🀆🀅🀄";
        return token.char_count() == 1 && symbols.contains(token);
    }

}
