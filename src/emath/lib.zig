const std = @import("std");

pub const Pos2 = @import("Pos2.zig");
pub const Rangef = @import("Rangef.zig");
pub const Rect = @import("Rect.zig");
pub const Rot2 = @import("Rot2.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Vec2b = @import("Vec2b.zig");

// CONSIDER: Specialize to `Rangef` and move to `Rangef.zig`?
pub fn remap(T: type, x: T, from_start: T, from_end_incl: T, to_start: T, to_end_incl: T) T {
    std.debug.assert(from_start != from_end_incl);
    const t = (x - from_start) / (from_end_incl - from_start);
    return std.math.lerp(to_start, to_end_incl, t);
}
