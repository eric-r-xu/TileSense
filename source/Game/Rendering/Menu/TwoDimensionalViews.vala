#if TWO_DIMENSIONAL
using Engine;
using Gee;

public class ScoringHandView : View2D
{
    private Scoring score;
    private LabelControl label;

    public ScoringHandView(GameRenderContext context, Scoring score)
    {
        this.score = score;
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void added()
    {
        label = new LabelControl();
        add_child(label);
        label.font_size = 42;
        label.text = hand_text();
    }

    private string hand_text()
    {
        ArrayList<Tile> sorted = Tile.sort_tiles_type(score.player.hand);
        string text = "";
        foreach (Tile tile in sorted)
            text += TILE_TYPE_TO_EMOJI_2D(tile.tile_type);
        text += "  " + TILE_TYPE_TO_EMOJI_2D(score.round.win_tile.tile_type);

        foreach (RoundStateCall call in score.player.calls)
        {
            text += "   ";
            foreach (Tile tile in call.tiles)
                text += TILE_TYPE_TO_EMOJI_2D(tile.tile_type);
        }
        return text;
    }

    public float alpha
    {
        get { return label.alpha; }
        set { label.alpha = value; }
    }
}

public class ScoringDoraView : View2D
{
    private ArrayList<Tile> tile_list;
    private int front_tiles;
    private int back_tiles;
    private LabelControl label;

    public ScoringDoraView(ArrayList<Tile> tile_list, int front_tiles, int back_tiles)
    {
        this.tile_list = tile_list;
        this.front_tiles = front_tiles;
        this.back_tiles = back_tiles;
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void added()
    {
        label = new LabelControl();
        add_child(label);
        label.font_size = 36;
        string text = "";
        for (int i = 0; i < front_tiles; i++)
            text += "🀫";
        foreach (Tile tile in tile_list)
            text += tile.tile_type == TileType.BLANK ? "🀫" : TILE_TYPE_TO_EMOJI_2D(tile.tile_type);
        for (int i = 0; i < back_tiles; i++)
            text += "🀫";
        label.text = text;
    }

    public float alpha
    {
        get { return label.alpha; }
        set { label.alpha = value; }
    }
}

public class ScoringStickView : View2D
{
    private RenderStick.StickType stick_type;
    private LabelControl label;
    private float _alpha = 1;

    public ScoringStickView(RenderStick.StickType stick_type)
    {
        this.stick_type = stick_type;
    }

    public override void added()
    {
        label = new LabelControl();
        add_child(label);
        label.font_size = 24;
        label.text = stick_type == RenderStick.StickType.STICK_1000 ? "━━●━━" : "━━━●━━━";
        label.alpha = _alpha;
    }

    public float alpha
    {
        get { return _alpha; }
        set
        {
            _alpha = value;
            if (label != null)
                label.alpha = value;
        }
    }
}
#endif
