const std = @import("std");

/// A vector has a direction and length.
/// A [`Vec2`] is often used to represent a size.
///
/// emath represents positions using [`crate::Pos2`].
///
/// Normally the units are points (logical pixels).
pub const T = @Vector(2, f32);

pub const X = T{ 1, 0 };
pub const Y = T{ 0, 1 };
pub const RIGHT = T{ 1, 0 };
pub const LEFT = T{ -1, 0 };
pub const UP = T{ 0, -1 };
pub const DOWN = T{ 0, 1 };
pub const ZERO = T{ 0, 0 };
pub const INFINITY = T{ std.math.inf(f32), std.math.inf(f32) };

pub fn isZero(v: T) bool {
    return v[0] == 0 and v[1] == 0;
}

/// Set both `x` and `y` to the same value.
pub fn splat(v: f32) T {
    return @splat(v);
}

/// Safe normalize: returns zero if input is zero.
pub fn normalize(v: T) T {
    const len = length(v);
    return if (len <= 0.0)
        v
    else
        v / splat(len);
}

/// Rotates the vector by 90°, i.e positive X to positive Y
/// (clockwise in egui coordinates).
pub fn rot90(v: T) T {
    return T{ v[1], -v[0] };
}

pub fn length(v: T) f32 {
    return @sqrt(lengthSq(v));
}

pub fn lengthSq(v: T) f32 {
    return @reduce(.Add, v * v);
}

/// Measures the angle of the vector.
///
/// ```
/// # use emath::Vec2;
/// use std::f32::consts::TAU;
///
/// assert_eq!(Vec2::ZERO.angle(), 0.0);
/// assert_eq!(Vec2::angled(0.0).angle(), 0.0);
/// assert_eq!(Vec2::angled(1.0).angle(), 1.0);
/// assert_eq!(Vec2::X.angle(), 0.0);
/// assert_eq!(Vec2::Y.angle(), 0.25 * TAU);
///
/// assert_eq!(Vec2::RIGHT.angle(), 0.0);
/// assert_eq!(Vec2::DOWN.angle(), 0.25 * TAU);
/// assert_eq!(Vec2::UP.angle(), -0.25 * TAU);
/// ```
pub fn angle(v: T) f32 {
    return std.math.atan2(v[1], v[0]);
}

/// Create a unit vector with the given CW angle (in radians).
/// * An angle of zero gives the unit X axis.
/// * An angle of 𝞃/4 = 90° gives the unit Y axis.
///
/// ```
/// # use emath::Vec2;
/// use std::f32::consts::TAU;
///
/// assert_eq!(Vec2::angled(0.0), Vec2::X);
/// assert!((Vec2::angled(0.25 * TAU) - Vec2::Y).length() < 1e-5);
/// ```
pub fn angled(a: f32) T {
    return T{ @cos(a), @sin(a) };
}

/// True if all members are also finite.
pub fn isFinite(v: T) bool {
    return std.math.isFinite(v[0]) and std.math.isFinite(v[1]);
}

/// True if any member is NaN.
pub fn anyNan(v: T) bool {
    return std.math.isNan(v[0]) or std.math.isNan(v[1]);
}

/// The dot-product of two vectors.
pub fn dot(u: T, v: T) f32 {
    return @reduce(.Add, u * v);
}

/// Swizzle the axes.
pub fn yx(v: T) T {
    return T{ v[1], v[0] };
}

pub fn clamp(v: T, min: T, max: T) T {
    return @min(@max(v, min), max);
}

test "basics" {
    try std.testing.expectEqual(0, angle(ZERO));
    try std.testing.expectEqual(0, angle(angled(0.0)));
    try std.testing.expectEqual(1, angle(angled(1.0)));
    try std.testing.expectEqual(0, angle(X));
    try std.testing.expectEqual(0.25 * std.math.tau, angle(Y));
    try std.testing.expectEqual(0, angle(RIGHT));
    try std.testing.expectEqual(0.25 * std.math.tau, angle(DOWN));
    try std.testing.expectEqual(0.5 * std.math.tau, angle(LEFT));
    try std.testing.expectEqual(-0.25 * std.math.tau, angle(UP));

    var assignment = T{ 1, 2 };
    assignment += T{ 3, 4 };
    try std.testing.expectEqual(T{ 4, 6 }, assignment);

    assignment = T{ 4, 6 };
    assignment -= T{ 1.0, 2.0 };
    try std.testing.expectEqual(T{ 3, 4 }, assignment);

    assignment = T{ 1, 2 };
    assignment *= splat(2);
    try std.testing.expectEqual(T{ 2, 4 }, assignment);

    assignment = T{ 2, 4 };
    assignment /= splat(2);
    try std.testing.expectEqual(T{ 1, 2 }, assignment);
}
