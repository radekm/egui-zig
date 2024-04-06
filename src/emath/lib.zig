const std = @import("std");

pub const Pos2 = @import("Pos2.zig");
pub const Rangef = @import("Rangef.zig");
pub const Rect = @import("Rect.zig");
pub const RectTransform = @import("RectTransform.zig");
pub const Rot2 = @import("Rot2.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Vec2b = @import("Vec2b.zig");

pub fn remap(x: f32, from: Rangef.T, to: Rangef.T) f32 {
    std.debug.assert(from.min != from.max);
    const t = (x - from.min) / (from.max - from.min);
    return std.math.lerp(to.min, to.max, t);
}

/// Like [`remap`], but also clamps the value so that the returned value is always in the `to` range.
pub fn remapClamp(x: f32, from: Rangef.T, to: Rangef.T) f32 {
    if (from.max < from.min)
        return remapClamp(
            x,
            .{ .min = from.max, .max = from.min },
            .{ .min = to.max, .max = to.min },
        );

    if (x <= from.min) {
        return to.min;
    } else if (from.max <= x) {
        return to.max;
    } else {
        std.debug.assert(from.min != from.max);

        const t = (x - from.min) / (from.max - from.min);
        // Ensure no numerical inaccuracies sneak in:
        return if (1.0 <= t)
            to.max
        else
            std.math.lerp(to.min, to.max, t);
    }
}
