const std = @import("std");

const Pos2 = @import("Pos2.zig");
const Rangef = @import("Rangef.zig");
const Rot2 = @import("Rot2.zig");
const Vec2 = @import("Vec2.zig");

/// A rectangular region of space.
///
/// Usually a [`Rect`] has a positive (or zero) size,
/// and then [`Self::min`] `<=` [`Self::max`].
/// In these cases [`Self::min`] is the left-top corner
/// and [`Self::max`] is the right-bottom corner.
///
/// A rectangle is allowed to have a negative size, which happens when the order
/// of `min` and `max` are swapped. These are usually a sign of an error.
///
/// Normally the unit is points (logical pixels) in screen space coordinates.
///
/// `Rect` does NOT implement `Default`, because there is no obvious default value.
/// [`Rect::ZERO`] may seem reasonable, but when used as a bounding box, [`Rect::NOTHING`]
/// is a better default - so be explicit instead!
pub const T = extern struct {
    /// One of the corners of the rectangle, usually the left top one.
    min: Pos2.T,
    /// The other corner, opposing [`Self::min`]. Usually the right bottom one.
    max: Pos2.T,

    pub fn withMinX(self: T, min_x: f32) T {
        var copy = self;
        copy.min[0] = min_x;
        return copy;
    }
    pub fn withMinY(self: T, min_y: f32) T {
        var copy = self;
        copy.min[1] = min_y;
        return copy;
    }
    pub fn withMaxX(self: T, max_x: f32) T {
        var copy = self;
        copy.max[0] = max_x;
        return copy;
    }
    pub fn withMaxY(self: T, max_y: f32) T {
        var copy = self;
        copy.max[1] = max_y;
        return copy;
    }

    /// Expand by this much in each direction, keeping the center
    pub fn expand(self: T, amnt: f32) T {
        return self.expand2(Vec2.splat(amnt));
    }
    /// Expand by this much in each direction, keeping the center
    pub fn expand2(self: T, amnt: Vec2.T) T {
        return fromMinMax(self.min - amnt, self.max + amnt);
    }

    /// Shrink by this much in each direction, keeping the center
    pub fn shrink(self: T, amnt: f32) T {
        return self.shrink2(Vec2.splat(amnt));
    }
    /// Shrink by this much in each direction, keeping the center
    pub fn shrink2(self: T, amnt: Vec2.T) T {
        return fromMinMax(self.min + amnt, self.max - amnt);
    }

    pub fn translate(self: T, amnt: Vec2.T) T {
        return fromMinSize(self.min + amnt, self.size());
    }
    /// Rotate the bounds (will expand the [`Rect`])
    pub fn rotateBb(self: T, rot: Rot2.T) T {
        const a = rot.rotateVec2(self.leftTop());
        const b = rot.rotateVec2(self.rightTop());
        const c = rot.rotateVec2(self.leftBottom());
        const d = rot.rotateVec2(self.rightBottom());
        return fromMinMax(
            @min(@min(@min(a, b), c), d),
            @max(@max(@max(a, b), c), d),
        );
    }

    pub fn intersects(self: T, other: T) bool {
        return self.min[0] <= other.max[0] and other.min[0] <= self.max[0] and self.min[1] <= other.max[1] and other.min[1] <= self.max[1];
    }
    /// keep min
    pub fn setWidth(self: *T, w: f32) void {
        self.max[0] = self.min[0] + w;
    }
    /// keep min
    pub fn setHeight(self: *T, h: f32) void {
        self.max[1] = self.min[1] + h;
    }
    /// Keep size
    pub fn setCenter(self: *T, newCenter: Pos2.T) void {
        self.* = self.translate(newCenter - self.center());
    }

    pub fn contains(self: T, p: Pos2.T) bool {
        return self.min[0] <= p[0] and p[0] <= self.max[0] and self.min[1] <= p[1] and p[1] <= self.max[1];
    }
    pub fn containsRect(self: T, other: T) bool {
        return self.contains(other.min) and self.contains(other.max);
    }

    /// Return the given points clamped to be inside the rectangle
    /// Panics if [`Self::is_negative`].
    pub fn clamp(self: T, p: Pos2.T) Pos2.T {
        return Pos2.clamp(p, self.min, self.max);
    }

    pub fn extendWith(self: *T, p: Pos2.T) void {
        self.min = @min(self.min, p);
        self.max = @max(self.max, p);
    }
    /// Expand to include the given x coordinate
    pub fn extendWithX(self: *T, x: f32) void {
        self.min[0] = @min(self.min[0], x);
        self.max[0] = @max(self.max[0], x);
    }
    /// Expand to include the given y coordinate
    pub fn extendWithY(self: *T, y: f32) void {
        self.min[1] = @min(self.min[1], y);
        self.max[1] = @max(self.max[1], y);
    }
    /// The union of two bounding rectangle, i.e. the minimum [`Rect`]
    /// that contains both input rectangles.
    pub fn @"union"(self: T, other: T) T {
        return T{
            .min = @min(self.min, other.min),
            .max = @max(self.max, other.max),
        };
    }
    /// The intersection of two [`Rect`], i.e. the area covered by both.
    pub fn intersect(self: T, other: T) T {
        return T{
            .min = @max(self.min, other.min),
            .max = @min(self.max, other.max),
        };
    }
    pub fn center(self: T) Pos2.T {
        return Pos2.T{
            (self.min[0] + self.max[0]) / 2.0,
            (self.min[1] + self.max[1]) / 2.0,
        };
    }
    /// `rect.size() == Vec2 { x: rect.width(), y: rect.height() }`
    pub fn size(self: T) Vec2.T {
        return self.max - self.min;
    }
    pub fn width(self: T) f32 {
        return self.max[0] - self.min[0];
    }
    pub fn height(self: T) f32 {
        return self.max[1] - self.min[1];
    }

    /// Width / height
    ///
    /// * `aspect_ratio < 1`: portrait / high
    /// * `aspect_ratio = 1`: square
    /// * `aspect_ratio > 1`: landscape / wide
    pub fn aspectRatio(self: T) f32 {
        return self.width() / self.height();
    }
    /// `[2, 1]` for wide screen, and `[1, 2]` for portrait, etc.
    /// At least one dimension = 1, the other >= 1
    /// Returns the proportions required to letter-box a square view area.
    pub fn squareProportions(self: T) Vec2.T {
        const w = self.width();
        const h = self.height();
        return if (w > h)
            Vec2.T{ w / h, 1.0 }
        else
            Vec2.T{ 1.0, h / w };
    }
    pub fn area(self: T) f32 {
        return self.width() * self.height();
    }

    /// The distance from the rect to the position.
    ///
    /// The distance is zero when the position is in the interior of the rectangle.
    pub fn distanceToPos(self: T, pos: Pos2.T) f32 {
        return @sqrt(self.distanceSqToPos(pos));
    }
    /// The distance from the rect to the position, squared.
    ///
    /// The distance is zero when the position is in the interior of the rectangle.
    pub fn distanceSqToPos(self: T, pos: Pos2.T) f32 {
        const dx = if (self.min[0] > pos[0])
            self.min[0] - pos[0]
        else if (pos[0] > self.max[0])
            pos[0] - self.max[0]
        else
            0.0;
        const dy = if (self.min[1] > pos[1])
            self.min[1] - pos[1]
        else if (pos[1] > self.max[1])
            pos[1] - self.max[1]
        else
            0.0;
        return dx * dx + dy * dy;
    }

    /// Signed distance to the edge of the box.
    ///
    /// Negative inside the box.
    ///
    /// ```
    /// # use emath::{pos2, Rect};
    /// let rect = Rect::from_min_max(pos2(0.0, 0.0), pos2(1.0, 1.0));
    /// assert_eq!(rect.signed_distance_to_pos(pos2(0.50, 0.50)), -0.50);
    /// assert_eq!(rect.signed_distance_to_pos(pos2(0.75, 0.50)), -0.25);
    /// assert_eq!(rect.signed_distance_to_pos(pos2(1.50, 0.50)), 0.50);
    /// ```
    pub fn signedDistanceToPos(self: T, pos: Pos2.T) f32 {
        const edge_distances = @abs(pos - self.center()) - self.size() * Vec2.splat(0.5);
        const inside_dist = @min(@reduce(.Max, edge_distances), 0.0);
        const outside_dist = Vec2.length(@max(edge_distances, Vec2.ZERO));
        return inside_dist + outside_dist;
    }

    /// Linearly interpolate so that `[0, 0]` is [`Self::min`] and
    /// `[1, 1]` is [`Self::max`].
    pub fn lerpInside(self: T, t: Vec2.T) Pos2.T {
        return Pos2.T{
            std.math.lerp(self.min[0], self.max[0], t[0]),
            std.math.lerp(self.min[1], self.max[1], t[1]),
        };
    }
    /// Linearly self towards other rect.
    pub fn lerpTowards(self: T, other: T, t: f32) T {
        return T{
            .min = Pos2.lerp(self.min, other.min, t),
            .max = Pos2.lerp(self.max, other.max, t),
        };
    }

    pub fn xRange(self: T) Rangef.T {
        return Rangef.T{ .min = self.min[0], .max = self.max[0] };
    }
    pub fn yRange(self: T) Rangef.T {
        return Rangef.T{ .min = self.min[1], .max = self.max[1] };
    }
    pub fn bottomUpRange(self: T) Rangef.T {
        return Rangef.T{ .min = self.max[1], .max = self.min[1] };
    }

    /// `width < 0 || height < 0`
    pub fn isNegative(self: T) bool {
        return self.max[0] < self.min[0] or self.max[1] < self.min[1];
    }
    /// `width > 0 && height > 0`
    pub fn isPositive(self: T) bool {
        return self.min[0] < self.max[0] and self.min[1] < self.max[1];
    }
    /// True if all members are also finite.
    pub fn isFinite(self: T) bool {
        return Pos2.isFinite(self.min) and Pos2.isFinite(self.max);
    }
    /// True if any member is NaN.
    pub fn anyNan(self: T) bool {
        return Pos2.anyNan(self.min) or Pos2.anyNan(self.max);
    }

    // ## Convenience functions (assumes origin is towards left top):

    /// `min.x`
    pub fn left(self: T) f32 {
        return self.min[0];
    }
    /// `min.x`
    pub fn leftMut(self: *T) *f32 {
        return &self.min[0];
    }
    /// `min.x`
    pub fn setLeft(self: *T, x: f32) void {
        self.min[0] = x;
    }

    /// `max.x`
    pub fn right(self: T) f32 {
        return self.max[0];
    }
    /// `max.x`
    pub fn rightMut(self: *T) *f32 {
        return &self.max[0];
    }
    /// `max.x`
    pub fn setRight(self: *T, x: f32) void {
        self.max[0] = x;
    }

    /// `min.y`
    pub fn top(self: T) f32 {
        return self.min[1];
    }
    /// `min.y`
    pub fn topMut(self: *T) *f32 {
        return &self.min[1];
    }
    /// `min.y`
    pub fn setTop(self: *T, y: f32) void {
        self.min[1] = y;
    }

    /// `max.y`
    pub fn bottom(self: T) f32 {
        return self.max[1];
    }
    /// `max.y`
    pub fn bottomMut(self: *T) *f32 {
        return &self.max[1];
    }
    /// `max.y`
    pub fn setBottom(self: *T, y: f32) void {
        self.max[1] = y;
    }

    pub fn leftTop(self: T) Pos2.T {
        return Pos2.T{ self.left(), self.top() };
    }
    pub fn centerTop(self: T) Pos2.T {
        return Pos2.T{ self.center()[0], self.top() };
    }
    pub fn rightTop(self: T) Pos2.T {
        return Pos2.T{ self.right(), self.top() };
    }
    pub fn leftCenter(self: T) Pos2.T {
        return Pos2.T{ self.left(), self.center()[1] };
    }
    pub fn rightCenter(self: T) Pos2.T {
        return Pos2.T{ self.right(), self.center()[1] };
    }
    pub fn leftBottom(self: T) Pos2.T {
        return Pos2.T{ self.left(), self.bottom() };
    }
    pub fn centerBottom(self: T) Pos2.T {
        return Pos2.T{ self.center()[0], self.bottom() };
    }
    pub fn rightBottom(self: T) Pos2.T {
        return Pos2.T{ self.right(), self.bottom() };
    }

    /// Split rectangle in left and right halves. `t` is expected to be in the (0,1) range.
    pub fn splitLeftRightAtFraction(self: T, t: f32, out_left: *T, out_right: *T) void {
        self.splitLeftRightAtX(std.math.lerp(self.min[0], self.max[0], t), out_left, out_right);
    }
    /// Split rectangle in left and right halves at the given `x` coordinate.
    pub fn splitLeftRightAtX(self: T, split_x: f32, out_left: *T, out_right: *T) void {
        out_left.* = fromMinMax(self.min, Pos2.T{ split_x, self.max[1] });
        out_right.* = fromMinMax(Pos2.T{ split_x, self.min[1] }, self.max);
    }
    /// Split rectangle in top and bottom halves. `t` is expected to be in the (0,1) range.
    pub fn splitTopBottomAtFraction(self: T, t: f32, out_top: *T, out_bottom: *T) void {
        self.splitTopBottomAtY(std.math.lerp(self.min[1], self.max[1], t), out_top, out_bottom);
    }
    /// Split rectangle in top and bottom halves at the given `y` coordinate.
    pub fn splitTopBottomAtY(self: T, split_y: f32, out_top: *T, out_bottom: *T) void {
        out_top.* = fromMinMax(self.min, Pos2.T{ self.max[0], split_y });
        out_bottom.* = fromMinMax(Pos2.T{ self.min[0], split_y }, self.max);
    }

    /// Does this Rect intersect the given ray (where `d` is normalized)?
    pub fn intersectsRay(self: T, o: Pos2.T, d: Vec2.T) bool {
        var tmin = -std.math.inf(f32);
        var tmax = std.math.inf(f32);
        if (d[0] != 0) {
            const tx1 = (self.min[0] - o[0]) / d[0];
            const tx2 = (self.max[0] - o[0]) / d[0];
            tmin = @max(tmin, @min(tx1, tx2));
            tmax = @min(tmax, @max(tx1, tx2));
        }

        if (d[1] != 0) {
            const ty1 = (self.min[1] - o[1]) / d[1];
            const ty2 = (self.max[1] - o[1]) / d[1];
            tmin = @max(tmin, @min(ty1, ty2));
            tmax = @min(tmax, tmax, @max(ty1, ty2));
        }
        return tmin <= tmax;
    }

    pub fn multiplyByScalar(self: T, k: f32) T {
        return T{
            .min = self.min * Pos2.T{ k, k },
            .max = self.max * Pos2.T{ k, k },
        };
    }
    pub fn divideByScalar(self: T, k: f32) T {
        return T{
            .min = self.min / Pos2.T{ k, k },
            .max = self.max / Pos2.T{ k, k },
        };
    }
};

/// Infinite rectangle that contains every point.
pub const EVERYTHING = T{
    .min = Pos2.T{ -std.math.inf(f32), -std.math.inf(f32) },
    .max = Pos2.T{ std.math.inf(f32), std.math.inf(f32) },
};
/// The inverse of [`Self::EVERYTHING`]: stretches from positive infinity to negative infinity.
/// Contains no points.
///
/// This is useful as the seed for bounding boxes.
///
/// # Example:
/// ```
/// # use emath::*;
/// let mut rect = Rect::NOTHING;
/// assert!(rect.size() == Vec2::splat(-f32::INFINITY));
/// assert!(rect.contains(pos2(0.0, 0.0)) == false);
/// rect.extend_with(pos2(2.0, 1.0));
/// rect.extend_with(pos2(0.0, 3.0));
/// assert_eq!(rect, Rect::from_min_max(pos2(0.0, 1.0), pos2(2.0, 3.0)))
/// ```
pub const NOTHING = T{
    .min = Pos2.T{ std.math.inf(f32), std.math.inf(f32) },
    .max = Pos2.T{ -std.math.inf(f32), -std.math.inf(f32) },
};
/// An invalid [`Rect`] filled with [`f32::NAN`].
pub const NAN = T{
    .min = Pos2.T{ std.math.nan(f32), std.math.nan(f32) },
    .max = Pos2.T{ std.math.nan(f32), std.math.nan(f32) },
};
/// A [`Rect`] filled with zeroes.
pub const ZERO = T{ .min = Pos2.ZERO, .max = Pos2.ZERO };

pub fn fromMinMax(min: Pos2.T, max: Pos2.T) T {
    return T{ .min = min, .max = max };
}
/// left-top corner plus a size (stretching right-down).
pub fn fromMinSize(min: Pos2.T, size: Vec2.T) T {
    return T{
        .min = min,
        .max = min + size,
    };
}

pub fn fromCenterSize(center: Pos2.T, size: Vec2.T) T {
    return T{
        .min = center - size * Vec2.splat(0.5),
        .max = center + size * Vec2.splat(0.5),
    };
}

pub fn fromXYRanges(x_range: Rangef.T, y_range: Rangef.T) T {
    return T{
        .min = Pos2.T{ x_range.min, y_range.min },
        .max = Pos2.T{ x_range.max, y_range.max },
    };
}

/// Returns the bounding rectangle of the two points.
pub fn fromTwoPos(a: Pos2.T, b: Pos2.T) T {
    return T{
        .min = Pos2.T{ @min(a[0], b[0]), @min(a[1], b[1]) },
        .max = Pos2.T{ @max(a[0], b[0]), @max(a[1], b[1]) },
    };
}

/// Bounding-box around the points.
pub fn fromPoints(points: []const Pos2.T) T {
    var rect = NOTHING;
    for (points) |p| {
        rect.extendWith(p);
    }
    return rect;
}

/// A [`Rect`] that contains every point to the right of the given X coordinate.
pub fn everythingRightOf(left_x: f32) T {
    var rect = EVERYTHING;
    rect.setLeft(left_x);
    return rect;
}
/// A [`Rect`] that contains every point to the left of the given X coordinate.
pub fn everythingLeftOf(right_x: f32) T {
    var rect = EVERYTHING;
    rect.setRight(right_x);
    return rect;
}
/// A [`Rect`] that contains every point below a certain y coordinate
pub fn everythingBelow(top_y: f32) T {
    var rect = EVERYTHING;
    rect.setTop(top_y);
    return rect;
}
/// A [`Rect`] that contains every point above a certain y coordinate
pub fn everythingAbove(bottom_y: f32) T {
    var rect = EVERYTHING;
    rect.setBottom(bottom_y);
    return rect;
}

test {
    const r = fromMinMax(Pos2.T{ 10, 10 }, Pos2.T{ 20, 20 });
    try std.testing.expectEqual(0, r.distanceSqToPos(Pos2.T{ 15, 15 }));
    try std.testing.expectEqual(0, r.distanceSqToPos(Pos2.T{ 10, 15 }));
    try std.testing.expectEqual(0, r.distanceSqToPos(Pos2.T{ 10, 10 }));

    try std.testing.expectEqual(25, r.distanceSqToPos(Pos2.T{ 5, 15 })); // left of
    try std.testing.expectEqual(25, r.distanceSqToPos(Pos2.T{ 25, 15 })); // right of
    try std.testing.expectEqual(25, r.distanceSqToPos(Pos2.T{ 15, 5 })); // above
    try std.testing.expectEqual(25, r.distanceSqToPos(Pos2.T{ 15, 25 })); // below
    try std.testing.expectEqual(50, r.distanceSqToPos(Pos2.T{ 25, 5 })); // right and above
}
