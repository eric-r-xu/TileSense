// The 3D stick model was removed with the rest of the 3D renderer. Only the
// StickType enum is still referenced (by the flat scoring views), so it is kept
// here under the original RenderStick.StickType name.
public class RenderStick : Object
{
    public enum StickType
    {
        STICK_100,
        STICK_1000,
        STICK_5000,
        STICK_10000
    }
}
