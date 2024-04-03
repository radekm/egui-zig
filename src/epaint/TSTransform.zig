const std = @import("std");

const Pos2 = @import("../emath/Pos2.zig");
const Rect = @import("../emath/Rect.zig");
const Vec2 = @import("../emath/Vec2.zig");

/// Linearly transforms positions via a translation, then a scaling.
///
/// [`TSTransform`] first scales points with the scaling origin at `0, 0`
/// (the top left corner), then translates them.
pub const T = extern struct {
    /// Scaling applied first, scaled around (0, 0).
    scaling: f32,
    /// Translation amount, applied after scaling.
    translation: Vec2.T,

    /// Inverts the transform.
    ///
    /// ```
    /// # use emath::{pos2, vec2, TSTransform};
    /// let p1 = pos2(2.0, 3.0);
    /// let p2 = pos2(12.0, 5.0);
    /// let ts = TSTransform::new(vec2(2.0, 3.0), 2.0);
    /// let inv = ts.inverse();
    /// assert_eq!(inv.mul_pos(p1), pos2(0.0, 0.0));
    /// assert_eq!(inv.mul_pos(p2), pos2(5.0, 1.0));
    ///
    /// assert_eq!(ts.inverse().inverse(), ts);
    /// ```
    pub fn inverse(self: T) T {
        return .{
            .translation = -self.translation / Vec2.splat(self.scaling),
            .scaling = 1.0 / self.scaling,
        };
    }

    /// Transforms the given coordinate.
    ///
    /// ```
    /// # use emath::{pos2, vec2, TSTransform};
    /// let p1 = pos2(0.0, 0.0);
    /// let p2 = pos2(5.0, 1.0);
    /// let ts = TSTransform::new(vec2(2.0, 3.0), 2.0);
    /// assert_eq!(ts.mul_pos(p1), pos2(2.0, 3.0));
    /// assert_eq!(ts.mul_pos(p2), pos2(12.0, 5.0));
    /// ```
    pub fn transformPos(self: T, pos: Pos2.T) Pos2.T {
        return Vec2.splat(self.scaling) * pos + self.translation;
    }

    /// Transforms the given rectangle.
    ///
    /// ```
    /// # use emath::{pos2, vec2, Rect, TSTransform};
    /// let rect = Rect::from_min_max(pos2(5.0, 5.0), pos2(15.0, 10.0));
    /// let ts = TSTransform::new(vec2(1.0, 0.0), 3.0);
    /// let transformed = ts.mul_rect(rect);
    /// assert_eq!(transformed.min, pos2(16.0, 15.0));
    /// assert_eq!(transformed.max, pos2(46.0, 30.0));
    /// ```
    pub fn transformRect(self: T, rect: Rect.T) Rect.T {
        return Rect.T{
            .min = self.transformPos(rect.min),
            .max = self.transformPos(rect.max),
        };
    }

    /// Applies the right hand side transform, then the left hand side.
    ///
    /// ```
    /// # use emath::{TSTransform, vec2};
    /// let ts1 = TSTransform::new(vec2(1.0, 0.0), 2.0);
    /// let ts2 = TSTransform::new(vec2(-1.0, -1.0), 3.0);
    /// let ts_combined = TSTransform::new(vec2(2.0, -1.0), 6.0);
    /// assert_eq!(ts_combined, ts2 * ts1);
    /// ```
    pub fn compose(self: T, rhs: T) T {
        // Apply rhs first.
        return T{
            .scaling = self.scaling * rhs.scaling,
            .translation = self.translation + Vec2.splat(self.scaling) * rhs.translation,
        };
    }
};

pub const IDENTITY = T{ .translation = Vec2.ZERO, .scaling = 1.0 };

pub fn fromTranslation(translation: Vec2.T) T {
    return .{ .translation = translation, .scaling = 1.0 };
}

pub fn fromScaling(scaling: f32) T {
    return .{ .translation = Vec2.ZERO, .scaling = scaling };
}
