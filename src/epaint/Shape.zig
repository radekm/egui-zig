const std = @import("std");

const Pos2 = @import("../emath/Pos2.zig");
const Rect = @import("../emath/Rect.zig");
const Vec2 = @import("../emath/Vec2.zig");

const Color = @import("Color.zig");
const Stroke = @import("Stroke.zig");

/// How to paint a circle.
pub const Circle = struct {
    center: Pos2.T,
    radius: f32,
    fill: Color.Color32,
    stroke: Stroke.T,

    pub fn filled(center: Pos2.T, radius: f32, fill_color: Color.Color32) Circle {
        return Circle{
            .center = center,
            .radius = radius,
            .fill = fill_color,
            .stroke = Stroke.NONE,
        };
    }

    pub fn stroke(center: Pos2.T, radius: f32, stroke0: Stroke.T) Circle {
        return Circle{
            .center = center,
            .radius = radius,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = stroke0,
        };
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: Circle) Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            return Rect.NOTHING
        else
            Rect.fromCenterSize(
                self.center,
                Vec2.splat(self.radius * 2.0 + self.stroke.width),
            );
    }
};

// ----------------------------------------------------------------------------

/// How to paint an ellipse.
pub const Ellipse = struct {
    center: Pos2.T,
    /// Radius is the vector (a, b) where the width of the Ellipse is 2a and the height is 2b
    radius: Vec2.T,
    fill: Color.Color32,
    stroke: Stroke.T,

    pub fn filled(center: Pos2.T, radius: Vec2.T, fill_color: Color.Color32) Ellipse {
        return .{
            .center = center,
            .radius = radius,
            .fill = fill_color,
            .stroke = Stroke.NONE,
        };
    }

    pub fn stroke(center: Pos2.T, radius: Vec2.T, stroke0: Stroke.T) Ellipse {
        return .{
            .center = center,
            .radius = radius,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = stroke0,
        };
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: Ellipse) Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            Rect.NOTHING
        else
            Rect.fromCenterSize(
                self.center,
                self.radius * Vec2.splat(2.0) + Vec2.splat(self.stroke.width),
            );
    }
};

// ----------------------------------------------------------------------------

/// How rounded the corners of things should be
pub const Rounding = struct {
    /// Radius of the rounding of the North-West (left top) corner.
    nw: f32,
    /// Radius of the rounding of the North-East (right top) corner.
    ne: f32,
    /// Radius of the rounding of the South-West (left bottom) corner.
    sw: f32,
    /// Radius of the rounding of the South-East (right bottom) corner.
    se: f32,

    /// No rounding on any corner.
    pub const ZERO = Rounding{ .nw = 0.0, .ne = 0.0, .sw = 0.0, .se = 0.0 };

    pub fn same(radius: f32) Rounding {
        return .{ .nw = radius, .ne = radius, .sw = radius, .se = radius };
    }

    pub fn eql(self: Rounding, other: Rounding) bool {
        return std.meta.eql(self, other);
    }

    /// Do all corners have the same rounding?
    pub fn isSame(self: Rounding) bool {
        return self.nw == self.ne and self.nw == self.sw and self.nw == self.se;
    }

    /// Make sure each corner has a rounding of at least this.
    pub fn atLeast(self: Rounding, min: f32) Rounding {
        return .{
            .nw = @max(self.nw, min),
            .ne = @max(self.ne, min),
            .sw = @max(self.sw, min),
            .se = @max(self.se, min),
        };
    }

    /// Make sure each corner has a rounding of at most this.
    pub fn atMost(self: Rounding, max: f32) Rounding {
        return .{
            .nw = @min(self.nw, max),
            .ne = @min(self.ne, max),
            .sw = @min(self.sw, max),
            .se = @min(self.se, max),
        };
    }

    pub fn add(self: Rounding, rhs: Rounding) Rounding {
        return .{
            .nw = self.nw + rhs.nw,
            .ne = self.ne + rhs.ne,
            .sw = self.sw + rhs.sw,
            .se = self.se + rhs.se,
        };
    }

    pub fn sub(self: Rounding, rhs: Rounding) Rounding {
        return .{
            .nw = self.nw - rhs.nw,
            .ne = self.ne - rhs.ne,
            .sw = self.sw - rhs.sw,
            .se = self.se - rhs.se,
        };
    }
};
