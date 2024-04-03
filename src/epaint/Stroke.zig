const Color = @import("Color.zig");

/// Describes the width and color of a line.
///
/// The default stroke is the same as [`Stroke::NONE`].
pub const T = struct {
    width: f32,
    color: Color.Color32,

    /// True if width is zero or color is transparent
    pub fn isEmpty(self: T) bool {
        return self.width <= 0.0 or self.color.eql(Color.Color32.TRANSPARENT);
    }
};

pub const NONE = T{
    .width = 0.0,
    .color = Color.Color32.TRANSPARENT,
};
