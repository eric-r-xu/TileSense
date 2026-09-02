using Engine;

public class RenderTable : WorldObject
{
    private GameRenderContext context;
    private float field_rotation;
    private RoundScoreState score;
    private WorldTableObject table;

    public RenderTable(GameRenderContext context, RenderTile[] tiles, float field_rotation, RoundScoreState score)
    {
        this.context = context;
        this.tiles = tiles;
        this.field_rotation = field_rotation;
        this.score = score;
    }

    protected override void added()
    {
        float hand_offset = 8;

        RenderTableCenterPiece center = new RenderTableCenterPiece(context.tile_size, field_rotation, score);
        add_object(center);

        players = new RenderPlayer[4];
        for (int i = 0; i < players.length; i++)
        {
            players[i] = new RenderPlayer(context, i, i == context.dealer, hand_offset, center.riichi_offset, i == context.observer_index, INT_TO_WIND(i - context.dealer));
            add_object(players[i]);
            players[i].rotation = Quat.from_euler(i / 2.0f, 0, 0);
        }
        
        wall = new RenderWall(context, tiles);
        add_object(wall);

        reload(QualityEnum.HIGH, "");
    }

    public void reload(QualityEnum quality, string table_texture_path)
    {
        if (table == null)
        {
            table = new WorldTableObject();
            add_object(table);
            table.rotation = Quat.from_euler(field_rotation / 2, 0, 0);
        }

        table.load(quality, table_texture_path);
    }

    public void split_dead_wall(AnimationTime time)
    {
        wall.split_dead_wall(time);
    }

    public RenderPlayer[] players { get; private set; }
    public RenderTile[] tiles { get; private set; }
    public RenderWall wall { get; private set; }
    //public Vec3 tile_size { get; private set; }
    //public float player_offset { get; private set; }
    //public float wall_offset { get; private set; }
}

public class WorldTableObject : WorldObject
{
    private RenderGeometry3D table;
    private RenderObject3D field;

    public void load(QualityEnum quality, string table_texture_path)
    {
        string extension = quality_enum_to_string(quality);
        table = store.load_geometry_3D("table_" + extension, true);
        field = store.create_plane();

        RenderTexture? texture = store.load_texture_path(table_texture_path);
        if (texture == null)
            texture = store.load_texture("field_" + extension);

        var spec = field.material.spec;
        spec.specular_color = UniformType.NONE;
        field.material = store.load_material(spec);
        field.material.textures[0] = texture;

        table.transform.position = Vec3(0, -0.163f, 0);
        table.transform.scale = Vec3(10, 10, 10);
        table.transform.change_parent(transform);
        field.transform.scale = Vec3(9.6f, 1, 9.6f);
        field.transform.change_parent(transform);
    }

	public override void do_add_to_scene(RenderScene3D scene)
    {
        scene.add_object(table);
        scene.add_object(field);
    }
}

private class RenderTableCenterPiece : WorldObjectTransformable
{
    private Vec3 tile_size;
    private float field_rotation;
    private RoundScoreState score;
    private RenderObject3D center_piece;
    private WorldLabel round_wind_label;
    private RenderTablePlayerNameField[] names;

    public RenderTableCenterPiece(Vec3 tile_size, float field_rotation, RoundScoreState score)
    {
        this.tile_size = tile_size;
        this.field_rotation = field_rotation;
        this.score = score;
    }

    protected override void added()
    {
        center_piece = store.load_geometry_3D("table_center", true).geometry[0] as RenderObject3D;
        set_object(center_piece);

        var spec = center_piece.material.spec;
        spec.specular_color = UniformType.STATIC;
        spec.static_specular_color = Color(0.3f, 0.3f, 0.3f, 1);

        var material = center_piece.material.textures[0];
        center_piece.material = store.load_material(spec);
        center_piece.material.textures[0] = material;

        float scale = tile_size.x * 2.9f;
        this.scale = Vec3(scale, scale, scale);

        names = new RenderTablePlayerNameField[score.players.length];

        Vec3 center_size = center_piece.obb;
        center_size = Vec3(center_size.x, center_size.y * 1.1f, center_size.z);
        riichi_offset = Vec3(0, center_size.y, center_size.x / 2 * scale * 0.8f);

        round_wind_label = new WorldLabel();
        add_object(round_wind_label);
        round_wind_label.bold = true;
        round_wind_label.rotation = Quat.from_euler(field_rotation / 2, 0, 0);
        round_wind_label.text = WIND_TO_KANJI(score.round_wind);
        round_wind_label.color = Color(0.1f, 0.3f, 1, 1);
        float s = 1.9f;
        round_wind_label.scale = Vec3(s, s, s);
        round_wind_label.font_size = 260;
        round_wind_label.position = Vec3(0, center_size.y, 0);

        for (int i = 0; i < names.length; i++)
        {
            WorldObject wrap = new WorldObject();
            add_object(wrap);
            wrap.rotation = Quat.from_euler(i / 2.0f, 0, 0);
            names[i] = new RenderTablePlayerNameField(score.players[i].name, score.players[i].wind, center_size);
            wrap.add_object(names[i]);
            wrap.position = Vec3(0, center_size.y, 0);
        }
    }

    public Vec3 riichi_offset { get; private set; }
}

private class RenderTablePlayerNameField : WorldObject
{
    private string name;
    private Wind wind;
    private Vec3 center_size;

    public RenderTablePlayerNameField(string name, Wind wind, Vec3 center_size)
    {
        this.name = name;
        this.wind = wind;
        this.center_size = center_size;
    }

    protected override void added()
    {
        // Two short, centered rows stay within each edge of the console. This
        // avoids long player strings crossing the large round-wind character.
        WorldLabel identity_label = new WorldLabel();
        add_object(identity_label);
        identity_label.bold = true;
        identity_label.text = "%s  %s".printf(WIND_TO_KANJI(wind), name);
        identity_label.color = Color(0.78f, 0.9f, 1, 1);
        identity_label.font_size = 260;
        float identity_scale = 0.58f;
        identity_label.scale = Vec3(identity_scale, identity_scale, identity_scale);
        identity_label.position = Vec3(0, 0, center_size.z * 0.30f);

    }
}
