const std = @import("std");

const Vec2 = @import("Vec2.zig");

/// A position on screen.
///
/// Normally given in points (logical pixels).
///
/// Mathematically this is known as a "point", but the term position was chosen so not to
/// conflict with the unit (one point = X physical pixels).
pub const T = @Vector(2, f32);

/// The zero position, the origin.
/// The top left corner in a GUI.
/// Same as `Pos2::default()`.
pub const ZERO = T{ 0, 0 };

pub fn distance(p1: T, p2: T) f32 {
    return Vec2.length(p1 - p2);
}

pub fn distanceSq(p1: T, p2: T) f32 {
    return Vec2.lengthSq(p1 - p2);
}

/// True if all members are also finite.
pub fn isFinite(p: T) bool {
    return Vec2.isFinite(p);
}

/// True if any member is NaN.
pub fn anyNan(p: T) bool {
    return Vec2.anyNan(p);
}

pub fn clamp(p: T, min: T, max: T) T {
    return Vec2.clamp(p, min, max);
}

/// Linearly interpolate towards another point, so that `0.0 => self, 1.0 => other`.
pub fn lerp(p1: T, p2: T, t: f32) T {
    return std.math.lerp(p1, p2, T{ t, t });
}
