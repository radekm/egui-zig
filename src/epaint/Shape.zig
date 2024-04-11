const std = @import("std");
const Allocator = std.mem.Allocator;

const m = @import("../emath/lib.zig");
const Pos2 = m.Pos2;
const Rangef = m.Rangef;
const RectTransform = m.RectTransform;
const Vec2 = m.Vec2;

const BezierFlattening = @import("BezierFlattening.zig");
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

// ----------------------------------------------------------------------------

/// A quadratic [Bézier Curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve).
///
/// See also [`CubicBezierShape`].
pub const QuadraticBezier = struct {
    /// The first point is the starting point and the last one is the ending point of the curve.
    /// The middle point is the control points.
    points: [3]Pos2.T,
    closed: bool,
    fill: Color.Color32,
    stroke: Stroke.T,

    /// Transform the curve with the given transform.
    pub fn transform(self: QuadraticBezier, transform0: RectTransform.T) QuadraticBezier {
        var points = [1]Pos2.T{Pos2.ZERO} ** 3;
        for (self.points, 0..) |origin_point, i| {
            points[i] = transform0.transformPos(origin_point);
        }
        return .{
            .points = points,
            .closed = self.closed,
            .fill = self.fill,
            .stroke = self.stroke,
        };
    }

    /// Convert the quadratic Bézier curve to one [`PathShape`].
    /// The `tolerance` will be used to control the max distance between the curve and the base line.
    pub fn toPath(self: QuadraticBezier, allocator: Allocator, tolerance: ?f32) Allocator.Error!Path {
        const points = try self.flatten(allocator, tolerance);
        return .{
            .points = points,
            .closed = self.closed,
            .fill = self.fill,
            .stroke = self.stroke,
        };
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: QuadraticBezier) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            self.logicalBoundingRect().expand(self.stroke.width / 2.0);
    }

    fn quadraticForEachLocalExtremum(p0: f32, p1: f32, p2: f32) ?f32 {
        // A quadratic Bézier curve can be derived by a linear function:
        // p(t) = p0 + t(p1 - p0) + t^2(p2 - 2p1 + p0)
        // The derivative is:
        // p'(t) = (p1 - p0) + 2(p2 - 2p1 + p0)t or:
        // f(x) = a* x + b
        const a = p2 - 2.0 * p1 + p0;
        // let b = p1 - p0;
        // no need to check for zero, since we're only interested in local extrema
        if (a == 0.0)
            return null;

        const t = (p0 - p1) / a;
        if (t > 0.0 and t < 1.0)
            return t
        else
            return null;
    }

    /// Logical bounding rectangle (ignoring stroke width)
    pub fn logicalBoundingRect(self: QuadraticBezier) m.Rect.T {
        var min_x = self.points[0][0];
        var max_x = self.points[2][0];
        if (min_x > max_x) std.mem.swap(f32, &min_x, &max_x);
        var min_y = self.points[0][1];
        var max_y = self.points[2][1];
        if (min_y > max_y) std.mem.swap(f32, &min_y, &max_y);

        if (quadraticForEachLocalExtremum(self.points[0][0], self.points[1][0], self.points[2][0])) |t| {
            const x = self.sample(t)[0];
            if (x < min_x) {
                min_x = x;
            }
            if (x > max_x) {
                max_x = x;
            }
        }

        if (quadraticForEachLocalExtremum(self.points[0][1], self.points[1][1], self.points[2][1])) |t| {
            const y = self.sample(t)[1];
            if (y < min_y) {
                min_y = y;
            }
            if (y > max_y) {
                max_y = y;
            }
        }

        return .{
            .min = .{ min_x, min_y },
            .max = .{ max_x, max_y },
        };
    }

    /// Calculate the point (x,y) at t based on the quadratic Bézier curve equation.
    /// t is in [0.0,1.0]
    /// [Bézier Curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Quadratic_B.C3.A9zier_curves)
    ///
    pub fn sample(self: QuadraticBezier, t: f32) Pos2.T {
        std.debug.assert(t >= 0.0 and t <= 1.0); // The sample value should be in [0.0,1.0].
        const h = 1.0 - t;
        const a = t * t;
        const b = 2.0 * t * h;
        const c = h * h;
        const result = self.points[2] * Vec2.splat(a) + self.points[1] * Vec2.splat(b) + self.points[0] * Vec2.splat(c);
        return result;
    }

    /// find a set of points that approximate the quadratic Bézier curve.
    /// the number of points is determined by the tolerance.
    /// the points may not be evenly distributed in the range [0.0,1.0] (t value)
    pub fn flatten(self: QuadraticBezier, allocator: Allocator, tolerance0: ?f32) Allocator.Error!std.ArrayList(Pos2.T) {
        const tolerance = tolerance0 orelse @abs(self.points[0][0] - self.points[2][0]) * 0.001;
        var result = std.ArrayList(Pos2.T).init(allocator);
        errdefer result.deinit();
        try result.append(self.points[0]);

        const callback = struct {
            context: *std.ArrayList(Pos2.T),
            fn run(self_nested: @This(), p: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self_nested.context.append(p);
            }
        }{ .context = &result };
        try self.forEachFlattenedWithT(tolerance, callback);
        return result;
    }

    // copied from https://docs.rs/lyon_geom/latest/lyon_geom/
    /// Compute a flattened approximation of the curve, invoking a callback at
    /// each step.
    ///
    /// The callback takes the point and corresponding curve parameter at each step.
    ///
    /// This implements the algorithm described by Raph Levien at
    /// <https://raphlinus.github.io/graphics/curves/2019/12/23/flatten-quadbez.html>
    pub fn forEachFlattenedWithT(
        self: QuadraticBezier,
        tolerance: f32,
        callback: anytype,
    ) Allocator.Error!void {
        const params = BezierFlattening.Parameters.fromCurve(self, tolerance);
        if (params.is_point) {
            return;
        }
        const count: u32 = @intFromFloat(params.count);
        // Following if protects from integer overflow which would happen
        // if start of range is bigger than end.
        if (count >= 1) {
            for (1..count) |index| {
                const t = params.tAtIteration(@floatFromInt(index));
                try callback.run(self.sample(t), t);
            }
        }
        try callback.run(self.sample(1.0), 1.0);
    }
};

test "quadratic bounding box" {
    {
        const curve = QuadraticBezier{
            .points = [3]Pos2.T{ .{ 110.0, 170.0 }, .{ 10.0, 10.0 }, .{ 180.0, 30.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        const bbox = curve.logicalBoundingRect();
        try std.testing.expectApproxEqAbs(72.96, bbox.min[0], 0.01);
        try std.testing.expectApproxEqAbs(27.78, bbox.min[1], 0.01);
        try std.testing.expectApproxEqAbs(180.0, bbox.max[0], 0.01);
        try std.testing.expectApproxEqAbs(170.0, bbox.max[1], 0.01);
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.1, callback);

        try std.testing.expectEqual(26, result.items.len);
    }
    {
        const curve = QuadraticBezier{
            .points = [3]Pos2.T{ .{ 110.0, 170.0 }, .{ 180.0, 30.0 }, .{ 10.0, 10.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        const bbox = curve.logicalBoundingRect();
        try std.testing.expectApproxEqAbs(10.0, bbox.min[0], 0.01);
        try std.testing.expectApproxEqAbs(10.0, bbox.min[1], 0.01);
        try std.testing.expectApproxEqAbs(130.42, bbox.max[0], 0.01);
        try std.testing.expectApproxEqAbs(170.0, bbox.max[1], 0.01);
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.1, callback);

        try std.testing.expectEqual(25, result.items.len);
    }
}

test "quadratic different tolerance" {
    const curve = QuadraticBezier{
        .points = [3]Pos2.T{ .{ 110.0, 170.0 }, .{ 180.0, 30.0 }, .{ 10.0, 10.0 } },
        .closed = false,
        .fill = Color.Color32.TRANSPARENT,
        .stroke = Stroke.NONE,
    };
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(1.0, callback);

        try std.testing.expectEqual(9, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.1, callback);

        try std.testing.expectEqual(25, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(77, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.001, callback);

        try std.testing.expectEqual(240, result.items.len);
    }
}

test "quadratic flattening" {
    const curve = QuadraticBezier{
        .points = [3]Pos2.T{ .{ 0.0, 0.0 }, .{ 80.0, 200.0 }, .{ 100.0, 30.0 } },
        .closed = false,
        .fill = Color.Color32.TRANSPARENT,
        .stroke = Stroke.NONE,
    };
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(1.0, callback);

        try std.testing.expectEqual(9, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.5, callback);

        try std.testing.expectEqual(11, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.1, callback);

        try std.testing.expectEqual(24, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(72, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.001, callback);

        try std.testing.expectEqual(223, result.items.len);
    }
}

// ----------------------------------------------------------------------------

/// A cubic [Bézier Curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve).
///
/// See also [`QuadraticBezierShape`].
pub const CubicBezier = struct {
    /// The first point is the starting point and the last one is the ending point of the curve.
    /// The middle points are the control points.
    points: [4]Pos2.T,
    closed: bool,
    fill: Color.Color32,
    stroke: Stroke.T,

    /// Transform the curve with the given transform.
    pub fn transform(self: CubicBezier, transform0: RectTransform.T) CubicBezier {
        var points = [1]Pos2.T{Pos2.ZERO} ** 4;
        for (self.points, 0..) |origin_point, i| {
            points[i] = transform0.transformPos(origin_point);
        }
        return .{
            .points = points,
            .closed = self.closed,
            .fill = self.fill,
            .stroke = self.stroke,
        };
    }

    /// Convert the cubic Bézier curve to one or two [`PathShape`]'s.
    /// When the curve is closed and it has to intersect with the base line, it will be converted into two shapes.
    /// Otherwise, it will be converted into one shape.
    /// The `tolerance` will be used to control the max distance between the curve and the base line.
    /// The `epsilon` is used when comparing two floats.
    pub fn toPath(
        self: CubicBezier,
        allocator: Allocator,
        tolerance: ?f32,
        epsilon: ?f32,
    ) Allocator.Error!std.ArrayList(Path) {
        var paths = std.ArrayList(Path).init(allocator);
        errdefer paths.deinit();

        var points_bounded_array = try self.flattenClosed(allocator, tolerance, epsilon);
        errdefer for (points_bounded_array.slice()) |points| {
            points.deinit();
        };

        for (points_bounded_array.slice()) |points| {
            const path = Path{
                .points = points,
                .closed = self.closed,
                .fill = self.fill,
                .stroke = self.stroke,
            };
            try paths.append(path);
        }

        return paths;
    }

    /// The visual bounding rectangle (includes stroke width)
    pub fn visualBoundingRect(self: CubicBezier) m.Rect.T {
        return if (self.fill.eql(Color.Color32.TRANSPARENT) and self.stroke.isEmpty())
            m.Rect.NOTHING
        else
            self.logicalBoundingRect().expand(self.stroke.width / 2.0);
    }

    fn inRange(t: f32) bool {
        return 0.0 <= t and t <= 1.0;
    }

    fn cubicForEachLocalExtremum(p0: f32, p1: f32, p2: f32, p3: f32) std.BoundedArray(f32, 2) {
        // See www.faculty.idc.ac.il/arik/quality/appendixa.html for an explanation
        // A cubic Bézier curve can be derivated by the following equation:
        // B'(t) = 3(1-t)^2(p1-p0) + 6(1-t)t(p2-p1) + 3t^2(p3-p2) or
        // f(x) = a * x² + b * x + c
        const a = 3.0 * (p3 + 3.0 * (p1 - p2) - p0);
        const b = 6.0 * (p2 - 2.0 * p1 + p0);
        const c = 3.0 * (p1 - p0);

        var result = std.BoundedArray(f32, 2).init(0) catch unreachable;

        // linear situation
        if (a == 0.0) {
            if (b != 0.0) {
                const t = -c / b;
                if (inRange(t)) {
                    result.append(t) catch unreachable;
                }
            }
            return result;
        }
        const discr = b * b - 4.0 * a * c;
        // no Real solution
        if (discr < 0.0) {
            return result;
        }
        // one Real solution
        if (discr == 0.0) {
            const t = -b / (2.0 * a);
            if (inRange(t)) {
                result.append(t) catch unreachable;
            }
            return result;
        }

        // two Real solutions
        const discrSqrt = @sqrt(discr);
        const t1 = (-b - discrSqrt) / (2.0 * a);
        const t2 = (-b + discrSqrt) / (2.0 * a);
        if (inRange(t1)) {
            result.append(t1) catch unreachable;
        }
        if (inRange(t2)) {
            result.append(t2) catch unreachable;
        }

        return result;
    }

    /// Logical bounding rectangle (ignoring stroke width)
    pub fn logicalBoundingRect(self: CubicBezier) m.Rect.T {
        // temporary solution
        var min_x = self.points[0][0];
        var max_x = self.points[3][0];
        if (min_x > max_x) std.mem.swap(f32, &min_x, &max_x);
        var min_y = self.points[0][1];
        var max_y = self.points[3][1];
        if (min_y > max_y) std.mem.swap(f32, &min_y, &max_y);

        // find the inflection points and get the x value
        for (cubicForEachLocalExtremum(
            self.points[0][0],
            self.points[1][0],
            self.points[2][0],
            self.points[3][0],
        ).slice()) |t| {
            const x = self.sample(t)[0];
            if (x < min_x) {
                min_x = x;
            }
            if (x > max_x) {
                max_x = x;
            }
        }

        // find the inflection points and get the y value
        for (cubicForEachLocalExtremum(
            self.points[0][1],
            self.points[1][1],
            self.points[2][1],
            self.points[3][1],
        ).slice()) |t| {
            const y = self.sample(t)[1];
            if (y < min_y) {
                min_y = y;
            }
            if (y > max_y) {
                max_y = y;
            }
        }

        return .{
            .min = .{ min_x, min_y },
            .max = .{ max_x, max_y },
        };
    }

    /// Calculate the point (x,y) at t based on the cubic Bézier curve equation.
    /// t is in [0.0,1.0]
    /// [Bézier Curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Cubic_B.C3.A9zier_curves)
    ///
    pub fn sample(self: CubicBezier, t: f32) Pos2.T {
        std.debug.assert(inRange(t)); // The sample value should be in [0.0,1.0].
        const h = 1.0 - t;
        const a = t * t * t;
        const b = 3.0 * t * t * h;
        const c = 3.0 * t * h * h;
        const d = h * h * h;
        const result =
            self.points[3] * Vec2.splat(a) +
            self.points[2] * Vec2.splat(b) +
            self.points[1] * Vec2.splat(c) +
            self.points[0] * Vec2.splat(d);
        return result;
    }

    /// Find out the t value for the point where the curve is intersected with the base line.
    /// The base line is the line from P0 to P3.
    /// If the curve only has two intersection points with the base line, they should be 0.0 and 1.0.
    /// In this case, the "fill" will be simple since the curve is a convex line.
    /// If the curve has more than two intersection points with the base line, the "fill" will be a problem.
    /// We need to find out where is the 3rd t value (0<t<1)
    /// And the original cubic curve will be split into two curves (0.0..t and t..1.0).
    /// B(t) = (1-t)^3*P0 + 3*t*(1-t)^2*P1 + 3*t^2*(1-t)*P2 + t^3*P3
    /// or B(t) = (P3 - 3*P2 + 3*P1 - P0)*t^3 + (3*P2 - 6*P1 + 3*P0)*t^2 + (3*P1 - 3*P0)*t + P0
    /// this B(t) should be on the line between P0 and P3. Therefore:
    /// (B.x - P0.x)/(P3.x - P0.x) = (B.y - P0.y)/(P3.y - P0.y), or:
    /// B.x * (P3.y - P0.y) - B.y * (P3.x - P0.x) + P0.x * (P0.y - P3.y) + P0.y * (P3.x - P0.x) = 0
    /// B.x = (P3.x - 3 * P2.x + 3 * P1.x - P0.x) * t^3 + (3 * P2.x - 6 * P1.x + 3 * P0.x) * t^2 + (3 * P1.x - 3 * P0.x) * t + P0.x
    /// B.y = (P3.y - 3 * P2.y + 3 * P1.y - P0.y) * t^3 + (3 * P2.y - 6 * P1.y + 3 * P0.y) * t^2 + (3 * P1.y - 3 * P0.y) * t + P0.y
    /// Combine the above three equations and iliminate B.x and B.y, we get:
    /// t^3 * ( (P3.x - 3*P2.x + 3*P1.x - P0.x) * (P3.y - P0.y) - (P3.y - 3*P2.y + 3*P1.y - P0.y) * (P3.x - P0.x))
    /// + t^2 * ( (3 * P2.x - 6 * P1.x + 3 * P0.x) * (P3.y - P0.y) - (3 * P2.y - 6 * P1.y + 3 * P0.y) * (P3.x - P0.x))
    /// + t^1 * ( (3 * P1.x - 3 * P0.x) * (P3.y - P0.y) - (3 * P1.y - 3 * P0.y) * (P3.x - P0.x))
    /// + (P0.x * (P3.y - P0.y) - P0.y * (P3.x - P0.x)) + P0.x * (P0.y - P3.y) + P0.y * (P3.x - P0.x)
    /// = 0
    /// or a * t^3 + b * t^2 + c * t + d = 0
    ///
    /// let x = t - b / (3 * a), then we have:
    /// x^3 + p * x + q = 0, where:
    /// p = (3.0 * a * c - b^2) / (3.0 * a^2)
    /// q = (2.0 * b^3 - 9.0 * a * b * c + 27.0 * a^2 * d) / (27.0 * a^3)
    ///
    /// when p > 0, there will be one real root, two complex roots
    /// when p = 0, there will be two real roots, when p=q=0, there will be three real roots but all 0.
    /// when p < 0, there will be three unique real roots. this is what we need. (x1, x2, x3)
    ///  t = x + b / (3 * a), then we have: t1, t2, t3.
    /// the one between 0.0 and 1.0 is what we need.
    /// <`https://baike.baidu.com/item/%E4%B8%80%E5%85%83%E4%B8%89%E6%AC%A1%E6%96%B9%E7%A8%8B/8388473 /`>
    ///
    pub fn findCrossT(self: CubicBezier, epsilon: f32) ?f32 {
        const p0 = self.points[0];
        const p1 = self.points[1];
        const p2 = self.points[2];
        const p3 = self.points[3];
        const a = (p3[0] - 3.0 * p2[0] + 3.0 * p1[0] - p0[0]) * (p3[1] - p0[1]) - (p3[1] - 3.0 * p2[1] + 3.0 * p1[1] - p0[1]) * (p3[0] - p0[0]);
        const b = (3.0 * p2[0] - 6.0 * p1[0] + 3.0 * p0[0]) * (p3[1] - p0[1]) - (3.0 * p2[1] - 6.0 * p1[1] + 3.0 * p0[1]) * (p3[0] - p0[0]);
        const c = (3.0 * p1[0] - 3.0 * p0[0]) * (p3[1] - p0[1]) - (3.0 * p1[1] - 3.0 * p0[1]) * (p3[0] - p0[0]);
        const d = p0[0] * (p3[1] - p0[1]) - p0[1] * (p3[0] - p0[0]) + p0[0] * (p0[1] - p3[1]) + p0[1] * (p3[0] - p0[0]);
        const h = -b / (3.0 * a);
        const p = (3.0 * a * c - b * b) / (3.0 * a * a);
        const q = (2.0 * b * b * b - 9.0 * a * b * c + 27.0 * a * a * d) / (27.0 * a * a * a);
        if (p > 0.0) {
            return null;
        }
        const r = @sqrt(-1.0 * std.math.pow(f32, p / 3.0, 3));
        const theta = std.math.acos(-1.0 * q / (2.0 * r)) / 3.0;
        const t1 = 2.0 * std.math.cbrt(r) * @cos(theta) + h;
        const t2 = 2.0 * std.math.cbrt(r) * @cos(theta + 120.0 * @as(f32, std.math.pi) / 180.0) + h;
        const t3 = 2.0 * std.math.cbrt(r) * @cos(theta + 240.0 * @as(f32, std.math.pi) / 180.0) + h;
        if (t1 > epsilon and t1 < 1.0 - epsilon) {
            return t1;
        }
        if (t2 > epsilon and t2 < 1.0 - epsilon) {
            return t2;
        }
        if (t3 > epsilon and t3 < 1.0 - epsilon) {
            return t3;
        }
        return null;
    }

    /// find a set of points that approximate the cubic Bézier curve.
    /// the number of points is determined by the tolerance.
    /// the points may not be evenly distributed in the range [0.0,1.0] (t value)
    /// this api will check whether the curve will cross the base line or not when closed = true.
    /// The result will be a vec of vec of Pos2. it will store two closed aren in different vec.
    /// The epsilon is used to compare a float value.
    pub fn flattenClosed(
        self: CubicBezier,
        allocator: Allocator,
        tolerance0: ?f32,
        epsilon0: ?f32,
    ) Allocator.Error!std.BoundedArray(std.ArrayList(Pos2.T), 2) {
        const tolerance = tolerance0 orelse @abs(self.points[0][0] - self.points[3][0]) * 0.001;
        const epsilon = epsilon0 orelse 1.0e-5;
        var result = std.BoundedArray(std.ArrayList(Pos2.T), 2).init(0) catch unreachable;
        var first_half = std.ArrayList(Pos2.T).init(allocator);
        var second_half = std.ArrayList(Pos2.T).init(allocator);
        var flipped = false;
        try first_half.append(self.points[0]);
        if (self.findCrossT(epsilon)) |cross| {
            if (self.closed) {
                const callback = struct {
                    flipped: *bool,
                    cross: f32,
                    first_half: *std.ArrayList(Pos2.T),
                    second_half: *std.ArrayList(Pos2.T),
                    self: *const CubicBezier,
                    fn run(self_nested: @This(), p: Pos2.T, t: f32) Allocator.Error!void {
                        if (t < self_nested.cross) {
                            try self_nested.first_half.append(p);
                        } else {
                            if (!self_nested.flipped.*) {
                                // when just crossed the base line, flip the order of the points
                                // add the cross point to the first half as the last point
                                // and add the cross point to the second half as the first point
                                self_nested.flipped.* = true;
                                const cross_point = self_nested.self.sample(self_nested.cross);
                                try self_nested.first_half.append(cross_point);
                                try self_nested.second_half.append(cross_point);
                            }
                            try self_nested.second_half.append(p);
                        }
                    }
                }{
                    .flipped = &flipped,
                    .cross = cross,
                    .first_half = &first_half,
                    .second_half = &second_half,
                    .self = &self,
                };
                try self.forEachFlattenedWithT(tolerance, callback);
            } else {
                const callback = struct {
                    first_half: *std.ArrayList(Pos2.T),
                    fn run(self_nested: @This(), p: Pos2.T, t: f32) Allocator.Error!void {
                        _ = t;
                        try self_nested.first_half.append(p);
                    }
                }{ .first_half = &first_half };
                try self.forEachFlattenedWithT(tolerance, callback);
            }
        } else {
            const callback = struct {
                first_half: *std.ArrayList(Pos2.T),
                fn run(self_nested: @This(), p: Pos2.T, t: f32) Allocator.Error!void {
                    _ = t;
                    try self_nested.first_half.append(p);
                }
            }{ .first_half = &first_half };
            try self.forEachFlattenedWithT(tolerance, callback);
        }

        result.append(first_half) catch unreachable;
        if (second_half.items.len != 0) {
            result.append(second_half) catch unreachable;
        }
        return result;
    }

    fn singleCurveApproximation(curve: CubicBezier) QuadraticBezier {
        const c1_x = (curve.points[1][0] * 3.0 - curve.points[0][0]) * 0.5;
        const c1_y = (curve.points[1][1] * 3.0 - curve.points[0][1]) * 0.5;
        const c2_x = (curve.points[2][0] * 3.0 - curve.points[3][0]) * 0.5;
        const c2_y = (curve.points[2][1] * 3.0 - curve.points[3][1]) * 0.5;
        const c = Pos2.T{ (c1_x + c2_x) * 0.5, (c1_y + c2_y) * 0.5 };
        return .{
            .points = .{ curve.points[0], c, curve.points[3] },
            .closed = curve.closed,
            .fill = curve.fill,
            .stroke = curve.stroke,
        };
    }

    /// split the original cubic curve into a new one within a range.
    pub fn splitRange(self: CubicBezier, t_range: Rangef.T) CubicBezier {
        // Range should be in [0.0,1.0].
        std.debug.assert(t_range.min >= 0.0 and t_range.max <= 1.0 and t_range.min <= t_range.max);
        const from = self.sample(t_range.min);
        const to = self.sample(t_range.max);
        const d_from = self.points[1] - self.points[0];
        const d_ctrl = self.points[2] - self.points[1];
        const d_to = self.points[3] - self.points[2];
        const q = QuadraticBezier{
            .points = .{ d_from, d_ctrl, d_to },
            .closed = self.closed,
            .fill = self.fill,
            .stroke = self.stroke,
        };
        const delta_t = t_range.max - t_range.min;
        const q_start = q.sample(t_range.min);
        const q_end = q.sample(t_range.max);
        const ctrl1 = from + q_start * Vec2.splat(delta_t);
        const ctrl2 = to - q_end * Vec2.splat(delta_t);
        return .{
            .points = .{ from, ctrl1, ctrl2, to },
            .closed = self.closed,
            .fill = self.fill,
            .stroke = self.stroke,
        };
    }

    // lyon_geom::flatten_cubic.rs
    // copied from https://docs.rs/lyon_geom/latest/lyon_geom/
    fn forEachFlattenedWithT(
        curve: CubicBezier,
        tolerance: f32,
        callback: anytype,
    ) Allocator.Error!void {
        const quadratics_tolerance = tolerance * 0.2;
        const flattening_tolerance = tolerance * 0.8;
        const num_quadratics = curve.numQuadratics(quadratics_tolerance);
        const step = 1.0 / @as(f32, @floatFromInt(num_quadratics));
        const n = num_quadratics;
        var t0: f32 = 0.0;

        const callback2 = struct {
            t0: *f32,
            step: f32,
            callback: @TypeOf(callback),
            fn run(self_nested: @This(), point: Pos2.T, t_sub: f32) Allocator.Error!void {
                const t = self_nested.t0.* + self_nested.step * t_sub;
                try self_nested.callback.run(point, t);
            }
        }{ .t0 = &t0, .step = step, .callback = callback };

        for (0..(n - 1)) |_| {
            const t1 = t0 + step;
            const quadratic = singleCurveApproximation(curve.splitRange(.{ .min = t0, .max = t1 }));
            try quadratic.forEachFlattenedWithT(flattening_tolerance, callback2);
            t0 = t1;
        }

        // Do the last step manually to make sure we finish at t = 1.0 exactly.
        const quadratic = singleCurveApproximation(curve.splitRange(.{ .min = t0, .max = 1.0 }));
        try quadratic.forEachFlattenedWithT(flattening_tolerance, callback2);
    }

    // copied from lyon::geom::flattern_cubic.rs
    // Computes the number of quadratic bézier segments to approximate a cubic one.
    // Derived by Raph Levien from section 10.6 of Sedeberg's CAGD notes
    // https://scholarsarchive.byu.edu/cgi/viewcontent.cgi?article=1000&context=facpub#section.10.6
    // and the error metric from the caffein owl blog post http://caffeineowl.com/graphics/2d/vectorial/cubic2quad01.html
    pub fn numQuadratics(self: CubicBezier, tolerance: f32) u32 {
        std.debug.assert(tolerance > 0.0); // the tolerance should be positive
        const x = self.points[0][0] - 3.0 * self.points[1][0] + 3.0 * self.points[2][0] - self.points[3][0];
        const y = self.points[0][1] - 3.0 * self.points[1][1] + 3.0 * self.points[2][1] - self.points[3][1];
        const err = x * x + y * y;
        return @intFromFloat(@max(@ceil(std.math.pow(f32, err / (432.0 * tolerance * tolerance), 1.0 / 6.0)), 1.0));
    }
};

test "cubic bounding box" {
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 10.0, 10.0 }, .{ 110.0, 170.0 }, .{ 180.0, 30.0 }, .{ 270.0, 210.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        const bbox = curve.logicalBoundingRect();
        try std.testing.expectEqual(10.0, bbox.min[0]);
        try std.testing.expectEqual(10.0, bbox.min[1]);
        try std.testing.expectEqual(270.0, bbox.max[0]);
        try std.testing.expectEqual(210.0, bbox.max[1]);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 10.0, 10.0 }, .{ 110.0, 170.0 }, .{ 270.0, 210.0 }, .{ 180.0, 30.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        const bbox = curve.logicalBoundingRect();
        try std.testing.expectEqual(10.0, bbox.min[0]);
        try std.testing.expectEqual(10.0, bbox.min[1]);
        try std.testing.expectApproxEqAbs(206.50, bbox.max[0], 0.01);
        try std.testing.expectApproxEqAbs(148.48, bbox.max[1], 0.01);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 110.0, 170.0 }, .{ 10.0, 10.0 }, .{ 270.0, 210.0 }, .{ 180.0, 30.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        const bbox = curve.logicalBoundingRect();
        try std.testing.expectApproxEqAbs(86.71, bbox.min[0], 0.01);
        try std.testing.expectApproxEqAbs(30.0, bbox.min[1], 0.01);
        try std.testing.expectApproxEqAbs(199.27, bbox.max[0], 0.01);
        try std.testing.expectApproxEqAbs(170.0, bbox.max[1], 0.01);
    }
}

test "cubic different tolerance flattening" {
    const curve = CubicBezier{
        .points = [4]Pos2.T{ .{ 0.0, 0.0 }, .{ 100.0, 0.0 }, .{ 100.0, 100.0 }, .{ 100.0, 200.0 } },
        .closed = false,
        .fill = Color.Color32.TRANSPARENT,
        .stroke = Stroke.NONE,
    };
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(1.0, callback);

        try std.testing.expectEqual(10, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.5, callback);

        try std.testing.expectEqual(13, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.1, callback);

        try std.testing.expectEqual(28, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(83, result.items.len);
    }
    {
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.001, callback);

        try std.testing.expectEqual(248, result.items.len);
    }
}

test "cubic different shape flattening" {
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 90.0, 110.0 }, .{ 30.0, 170.0 }, .{ 210.0, 170.0 }, .{ 170.0, 110.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(117, result.items.len);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 90.0, 110.0 }, .{ 90.0, 170.0 }, .{ 170.0, 170.0 }, .{ 170.0, 110.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(91, result.items.len);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{ .{ 90.0, 110.0 }, .{ 110.0, 170.0 }, .{ 150.0, 170.0 }, .{ 170.0, 110.0 } },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(75, result.items.len);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{
                .{ 90.0, 110.0 },
                .{ 110.0, 170.0 },
                .{ 230.0, 110.0 },
                .{ 170.0, 110.0 },
            },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(100, result.items.len);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{
                .{ 90.0, 110.0 },
                .{ 110.0, 170.0 },
                .{ 210.0, 70.0 },
                .{ 170.0, 110.0 },
            },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(71, result.items.len);
    }
    {
        const curve = CubicBezier{
            .points = [4]Pos2.T{
                .{ 90.0, 110.0 },
                .{ 110.0, 170.0 },
                .{ 150.0, 50.0 },
                .{ 170.0, 110.0 },
            },
            .closed = false,
            .fill = Color.Color32.TRANSPARENT,
            .stroke = Stroke.NONE,
        };
        var result = std.ArrayList(Pos2.T).init(std.testing.allocator);
        defer result.deinit();

        try result.append(curve.points[0]);

        const callback = struct {
            result: *std.ArrayList(Pos2.T),
            fn run(self: @This(), pos: Pos2.T, t: f32) Allocator.Error!void {
                _ = t;
                try self.result.append(pos);
            }
        }{ .result = &result };
        try curve.forEachFlattenedWithT(0.01, callback);

        try std.testing.expectEqual(88, result.items.len);
    }
}
