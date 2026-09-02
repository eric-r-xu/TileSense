using Engine;
using Gee;

public class ScoringStickNumberView : View2D
{
    private RenderStick.StickType stick_type;
    private bool left_text;
    private int _number = 0;

    private LabelControl? label;
    private ScoringStickView? stick;

    public ScoringStickNumberView(RenderStick.StickType stick_type, bool left_text)
    {
        this.stick_type = stick_type;
        this.left_text = left_text;
    }

    protected override void added()
    {
        label = new LabelControl();
        add_child(label);
        label.inner_anchor = Vec2(left_text ? 0 : 1, 0.5f);
        label.outer_anchor = Vec2(left_text ? 0 : 1, 0.5f);

        stick = new ScoringStickView(stick_type);
        add_child(stick);
        stick.inner_anchor = Vec2(left_text ? 1 : 0, 0.5f);
        stick.outer_anchor = Vec2(left_text ? 1 : 0, 0.5f);

        number = _number;
    }

    protected override void resized()
    {
        if (stick != null && label != null)
            stick.size = Size2(size.width - label.size.width, size.height);
    }

    public float alpha
    {
        get { return label.alpha; }
        set
        {
            label.alpha = value;
            stick.alpha = value;
        }
    }

    public int number
    {
        get { return _number; }
        set
        {
            _number = value;
            label.text = left_text ? (value.to_string() + "x") : ("x" + value.to_string());
            resized();
        }
    }
}
