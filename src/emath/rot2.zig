const std = @import("std");

const Vec2 = @import("Vec2.zig");

// {s,c} represents the rotation matrix:
//
// | c -s |
// | s  c |
//
// `vec2(c,s)` represents where the X axis will end up after rotation.
//
/// Represents a rotation in the 2D plane.
//
/// A rotation of 𝞃/4 = 90° rotates the X axis to the Y axis.
//
/// Normally a [`Rot2`] is normalized (unit-length).
/// If not, it will also scale vectors.
pub const T = extern struct {
    /// angle.sin()
    s: f32,
    /// angle.cos()
    c: f32,

    pub fn angle(self: T) f32 {
        return std.math.atan2(self.s, self.c);
    }

    /// The factor by which vectors will be scaled.
    pub fn length(self: T) f32 {
        return std.math.hypot(self.c, self.s);
    }
    pub fn lengthSq(self: T) f32 {
        return self.c * self.c + self.s * self.s;
    }

    pub fn isFinite(self: T) bool {
        return std.math.isFinite(self.c) and std.math.isFinite(self.s);
    }
    pub fn inverse(self: T) T {
        // We divide by squared length because inverse must have length `1.0 / self.length()`.
        return (T{
            .s = -self.s,
            .c = self.c,
        }).divideByScalar(self.lengthSq());
    }
    pub fn normalized(self: T) T {
        const l = self.length();
        const ret = T{
            .c = self.c / l,
            .s = self.s / l,
        };
        std.debug.assert(ret.isFinite());
        return ret;
    }

    // Compose two rotations (ie. multiply matrices).
    pub fn compose(self: T, r: T) T {
        // |lc -ls| * |rc -rs|
        // |ls  lc|   |rs  rc|
        return T{
            .c = self.c * r.c - self.s * r.s,
            .s = self.s * r.c + self.c * r.s,
        };
    }

    /// Rotates (and maybe scales) the vector.
    pub fn rotateVec2(self: T, v: Vec2.T) Vec2.T {
        return Vec2.T{
            self.c * v[0] - self.s * v[1],
            self.s * v[0] + self.c * v[1],
        };
    }

    pub fn multiplyByScalar(self: T, k: f32) T {
        return T{
            .c = self.c * k,
            .s = self.s * k,
        };
    }

    pub fn divideByScalar(self: T, k: f32) T {
        return T{
            .c = self.c / k,
            .s = self.s / k,
        };
    }
};

/// The identity rotation: nothing rotates
pub const IDENTITY = T{ .s = 0.0, .c = 1.0 };

/// Angle is clockwise in radians.
/// A 𝞃/4 = 90° rotation means rotating the X axis to the Y axis.
pub fn fromAngle(a: f32) T {
    return T{ .s = std.math.sin(a), .c = std.math.cos(a) };
}

test {
    {
        const angle = std.math.tau / 6.0;
        const rot = fromAngle(angle);
        try std.testing.expectApproxEqAbs(angle, rot.angle(), 1e-5);
        try std.testing.expectApproxEqAbs(0, rot.compose(rot.inverse()).angle(), 1e-5);
        try std.testing.expectApproxEqAbs(0, rot.inverse().compose(rot).angle(), 1e-5);
    }
    {
        const angle = std.math.tau / 4.0;
        const rot = fromAngle(angle);
        try std.testing.expectApproxEqAbs(
            0,
            Vec2.length(rot.rotateVec2(Vec2.T{ 1, 0 }) - Vec2.T{ 0, 1 }),
            1e-5,
        );
    }
    {
        // Test rotation and scaling
        const angle = std.math.tau / 4.0;
        const rot = fromAngle(angle).multiplyByScalar(3);
        const rotated = rot.rotateVec2(Vec2.T{ 1, 0 });
        const expected = Vec2.T{ 0.0, 3.0 };
        try std.testing.expectApproxEqAbs(0, Vec2.length(rotated - expected), 1e-5);
        const undone = rot.inverse().compose(rot);
        try std.testing.expectApproxEqAbs(0, undone.angle(), 1e-5);
        try std.testing.expectApproxEqAbs(0, undone.length() - 1.0, 1e-5);
    }
}
