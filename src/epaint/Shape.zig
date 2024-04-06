const std = @import("std");

const m = @import("../emath/lib.zig");
const Pos2 = m.Pos2;
const Vec2 = m.Vec2;

const Color = @import("Color.zig");
const Stroke = @import("Stroke.zig");
const Texture = @import("Texture.zig");

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
    pub fn visualBoundingRect(self: Circle) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            m.Rect.fromCenterSize(
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
    pub fn visualBoundingRect(self: Ellipse) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            m.Rect.fromCenterSize(
                self.center,
                self.radius * Vec2.splat(2.0) + Vec2.splat(self.stroke.width),
            );
    }
};

// ----------------------------------------------------------------------------

// TODO: Consider whether `Path.points` should be slice instead of array list.

/// A path which can be stroked and/or filled (if closed).
pub const Path = struct {
    /// Filled paths should prefer clockwise order.
    points: std.ArrayList(Pos2.T),
    /// If true, connect the first and last of the points together.
    /// This is required if `fill != TRANSPARENT`.
    closed: bool,
    /// Fill is only supported for convex polygons.
    fill: Color.Color32,
    /// Color and thickness of the line.
    stroke: Stroke.T,
    // TODO(emilk): Add texture support either by supplying uv for each point,
    // or by some transform from points to uv (e.g. a callback or a linear transform matrix).

    /// A line through many points.
    ///
    /// Use [`Shape::line_segment`] instead if your line only connects two points.
    pub fn line(points: std.ArrayList(Pos2.T), stroke: Stroke.T) Path {
        return .{
            .points = points,
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = stroke,
        };
    }

    /// A line that closes back to the start point again.
    pub fn closedLine(points: std.ArrayList(Pos2.T), stroke: Stroke.T) Path {
        return .{
            .points = points,
            .closed = true,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = stroke,
        };
    }

    /// A convex polygon with a fill and optional stroke.
    ///
    /// The most performant winding order is clockwise.
    pub fn convexPolygon(
        points: std.ArrayList(Pos2.T),
        fill: Color.Color32,
        stroke: Stroke.T,
    ) Path {
        return .{
            .points = points,
            .closed = true,
            .fill = fill,
            .stroke = stroke,
        };
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: Path) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            m.Rect.fromPoints(self.points.items).expand(self.stroke.width / 2.0);
    }
};

// ----------------------------------------------------------------------------

/// How to paint a rectangle.
pub const Rect = struct {
    rect: m.Rect.T,
    /// How rounded the corners are. Use `Rounding::ZERO` for no rounding.
    rounding: Rounding,
    /// How to fill the rectangle.
    fill: Color.Color32,
    /// The thickness and color of the outline.
    stroke: Stroke.T,
    /// If larger than zero, the edges of the rectangle
    /// (for both fill and stroke) will be blurred.
    ///
    /// This can be used to produce shadows and glow effects.
    ///
    /// The blur is currently implemented using a simple linear blur in sRGBA gamma space.
    blur_width: f32,
    /// If the rect should be filled with a texture, which one?
    ///
    /// The texture is multiplied with [`Self::fill`].
    fill_texture_id: Texture.Id,
    /// What UV coordinates to use for the texture?
    ///
    /// To display a texture, set [`Self::fill_texture_id`],
    /// and set this to `Rect::from_min_max(pos2(0.0, 0.0), pos2(1.0, 1.0))`.
    ///
    /// Use [`Rect::ZERO`] to turn off texturing.
    uv: m.Rect.T,

    pub fn new(
        rect: m.Rect.T,
        rounding: Rounding,
        fill_color: Color.Color32,
        stroke0: Stroke.T,
    ) Rect {
        return .{
            .rect = rect,
            .rounding = rounding,
            .fill = fill_color,
            .stroke = stroke0,
            .blur_width = 0.0,
            .fill_texture_id = Texture.Id.DEFAULT,
            .uv = m.Rect.ZERO,
        };
    }

    pub fn filled(
        rect: m.Rect.T,
        rounding: Rounding,
        fill_color: Color.Color32,
    ) Rect {
        return .{
            .rect = rect,
            .rounding = rounding,
            .fill = fill_color,
            .stroke = Stroke.NONE,
            .blur_width = 0.0,
            .fill_texture_id = Texture.Id.DEFAULT,
            .uv = m.Rect.ZERO,
        };
    }
    pub fn stroke(rect: m.Rect.T, rounding: Rounding, stroke0: Stroke.T) Rect {
        return .{
            .rect = rect,
            .rounding = rounding,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = stroke0,
            .blur_width = 0.0,
            .fill_texture_id = Texture.Id.DEFAULT,
            .uv = m.Rect.ZERO,
        };
    }

    /// If larger than zero, the edges of the rectangle
    /// (for both fill and stroke) will be blurred.
    ///
    /// This can be used to produce shadows and glow effects.
    ///
    /// The blur is currently implemented using a simple linear blur in `sRGBA` gamma space.
    pub fn withBlurWidth(self: Rect, blur_width: f32) Rect {
        var copy = self;
        copy.blur_width = blur_width;
        return copy;
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: Rect) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            self.rect.expand((self.stroke.width + self.blur_width) / 2.0);
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
