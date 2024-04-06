//! Converts graphics primitives into textured triangles.
//!
//! This module converts lines, circles, text and more represented by [`Shape`]
//! into textured triangles represented by [`Mesh`].

const std = @import("std");
const Allocator = std.mem.Allocator;

const m = @import("../emath/lib.zig");
const Pos2 = m.Pos2;
const Rect = m.Rect;
const Vec2 = m.Vec2;

const Color = @import("Color.zig");
const Mesh = @import("Mesh.zig");
const Shape = @import("Shape.zig");
const Stroke = @import("Stroke.zig");
const Texture = @import("Texture.zig");
const TextureAtlas = @import("TextureAtlas.zig");

// fn main() {
//     let n = 64;
//     println!("pub const CIRCLE_{}: [Vec2; {}] = [", n, n+1);
//     for i in 0..=n {
//         let a = std::f64::consts::TAU * i as f64 / n as f64;
//         println!("    vec2({:.06}, {:.06}),", a.cos(), a.sin());
//     }
//     println!("];")
// }
const CIRCLE_8: [9]Vec2.T = [_]Vec2.T{
    Vec2.T{ 1.000000, 0.000000 },
    Vec2.T{ 0.707107, 0.707107 },
    Vec2.T{ 0.000000, 1.000000 },
    Vec2.T{ -0.707107, 0.707107 },
    Vec2.T{ -1.000000, 0.000000 },
    Vec2.T{ -0.707107, -0.707107 },
    Vec2.T{ 0.000000, -1.000000 },
    Vec2.T{ 0.707107, -0.707107 },
    Vec2.T{ 1.000000, 0.000000 },
};
const CIRCLE_16: [17]Vec2.T = [_]Vec2.T{
    Vec2.T{ 1.000000, 0.000000 },
    Vec2.T{ 0.923880, 0.382683 },
    Vec2.T{ 0.707107, 0.707107 },
    Vec2.T{ 0.382683, 0.923880 },
    Vec2.T{ 0.000000, 1.000000 },
    Vec2.T{ -0.382684, 0.923880 },
    Vec2.T{ -0.707107, 0.707107 },
    Vec2.T{ -0.923880, 0.382683 },
    Vec2.T{ -1.000000, 0.000000 },
    Vec2.T{ -0.923880, -0.382683 },
    Vec2.T{ -0.707107, -0.707107 },
    Vec2.T{ -0.382684, -0.923880 },
    Vec2.T{ 0.000000, -1.000000 },
    Vec2.T{ 0.382684, -0.923879 },
    Vec2.T{ 0.707107, -0.707107 },
    Vec2.T{ 0.923880, -0.382683 },
    Vec2.T{ 1.000000, 0.000000 },
};
const CIRCLE_32: [33]Vec2.T = [_]Vec2.T{
    Vec2.T{ 1.000000, 0.000000 },
    Vec2.T{ 0.980785, 0.195090 },
    Vec2.T{ 0.923880, 0.382683 },
    Vec2.T{ 0.831470, 0.555570 },
    Vec2.T{ 0.707107, 0.707107 },
    Vec2.T{ 0.555570, 0.831470 },
    Vec2.T{ 0.382683, 0.923880 },
    Vec2.T{ 0.195090, 0.980785 },
    Vec2.T{ 0.000000, 1.000000 },
    Vec2.T{ -0.195090, 0.980785 },
    Vec2.T{ -0.382683, 0.923880 },
    Vec2.T{ -0.555570, 0.831470 },
    Vec2.T{ -0.707107, 0.707107 },
    Vec2.T{ -0.831470, 0.555570 },
    Vec2.T{ -0.923880, 0.382683 },
    Vec2.T{ -0.980785, 0.195090 },
    Vec2.T{ -1.000000, 0.000000 },
    Vec2.T{ -0.980785, -0.195090 },
    Vec2.T{ -0.923880, -0.382683 },
    Vec2.T{ -0.831470, -0.555570 },
    Vec2.T{ -0.707107, -0.707107 },
    Vec2.T{ -0.555570, -0.831470 },
    Vec2.T{ -0.382683, -0.923880 },
    Vec2.T{ -0.195090, -0.980785 },
    Vec2.T{ -0.000000, -1.000000 },
    Vec2.T{ 0.195090, -0.980785 },
    Vec2.T{ 0.382683, -0.923880 },
    Vec2.T{ 0.555570, -0.831470 },
    Vec2.T{ 0.707107, -0.707107 },
    Vec2.T{ 0.831470, -0.555570 },
    Vec2.T{ 0.923880, -0.382683 },
    Vec2.T{ 0.980785, -0.195090 },
    Vec2.T{ 1.000000, -0.000000 },
};
const CIRCLE_64: [65]Vec2.T = [_]Vec2.T{
    Vec2.T{ 1.000000, 0.000000 },
    Vec2.T{ 0.995185, 0.098017 },
    Vec2.T{ 0.980785, 0.195090 },
    Vec2.T{ 0.956940, 0.290285 },
    Vec2.T{ 0.923880, 0.382683 },
    Vec2.T{ 0.881921, 0.471397 },
    Vec2.T{ 0.831470, 0.555570 },
    Vec2.T{ 0.773010, 0.634393 },
    Vec2.T{ 0.707107, 0.707107 },
    Vec2.T{ 0.634393, 0.773010 },
    Vec2.T{ 0.555570, 0.831470 },
    Vec2.T{ 0.471397, 0.881921 },
    Vec2.T{ 0.382683, 0.923880 },
    Vec2.T{ 0.290285, 0.956940 },
    Vec2.T{ 0.195090, 0.980785 },
    Vec2.T{ 0.098017, 0.995185 },
    Vec2.T{ 0.000000, 1.000000 },
    Vec2.T{ -0.098017, 0.995185 },
    Vec2.T{ -0.195090, 0.980785 },
    Vec2.T{ -0.290285, 0.956940 },
    Vec2.T{ -0.382683, 0.923880 },
    Vec2.T{ -0.471397, 0.881921 },
    Vec2.T{ -0.555570, 0.831470 },
    Vec2.T{ -0.634393, 0.773010 },
    Vec2.T{ -0.707107, 0.707107 },
    Vec2.T{ -0.773010, 0.634393 },
    Vec2.T{ -0.831470, 0.555570 },
    Vec2.T{ -0.881921, 0.471397 },
    Vec2.T{ -0.923880, 0.382683 },
    Vec2.T{ -0.956940, 0.290285 },
    Vec2.T{ -0.980785, 0.195090 },
    Vec2.T{ -0.995185, 0.098017 },
    Vec2.T{ -1.000000, 0.000000 },
    Vec2.T{ -0.995185, -0.098017 },
    Vec2.T{ -0.980785, -0.195090 },
    Vec2.T{ -0.956940, -0.290285 },
    Vec2.T{ -0.923880, -0.382683 },
    Vec2.T{ -0.881921, -0.471397 },
    Vec2.T{ -0.831470, -0.555570 },
    Vec2.T{ -0.773010, -0.634393 },
    Vec2.T{ -0.707107, -0.707107 },
    Vec2.T{ -0.634393, -0.773010 },
    Vec2.T{ -0.555570, -0.831470 },
    Vec2.T{ -0.471397, -0.881921 },
    Vec2.T{ -0.382683, -0.923880 },
    Vec2.T{ -0.290285, -0.956940 },
    Vec2.T{ -0.195090, -0.980785 },
    Vec2.T{ -0.098017, -0.995185 },
    Vec2.T{ -0.000000, -1.000000 },
    Vec2.T{ 0.098017, -0.995185 },
    Vec2.T{ 0.195090, -0.980785 },
    Vec2.T{ 0.290285, -0.956940 },
    Vec2.T{ 0.382683, -0.923880 },
    Vec2.T{ 0.471397, -0.881921 },
    Vec2.T{ 0.555570, -0.831470 },
    Vec2.T{ 0.634393, -0.773010 },
    Vec2.T{ 0.707107, -0.707107 },
    Vec2.T{ 0.773010, -0.634393 },
    Vec2.T{ 0.831470, -0.555570 },
    Vec2.T{ 0.881921, -0.471397 },
    Vec2.T{ 0.923880, -0.382683 },
    Vec2.T{ 0.956940, -0.290285 },
    Vec2.T{ 0.980785, -0.195090 },
    Vec2.T{ 0.995185, -0.098017 },
    Vec2.T{ 1.000000, -0.000000 },
};
const CIRCLE_128: [129]Vec2.T = [_]Vec2.T{
    Vec2.T{ 1.000000, 0.000000 },
    Vec2.T{ 0.998795, 0.049068 },
    Vec2.T{ 0.995185, 0.098017 },
    Vec2.T{ 0.989177, 0.146730 },
    Vec2.T{ 0.980785, 0.195090 },
    Vec2.T{ 0.970031, 0.242980 },
    Vec2.T{ 0.956940, 0.290285 },
    Vec2.T{ 0.941544, 0.336890 },
    Vec2.T{ 0.923880, 0.382683 },
    Vec2.T{ 0.903989, 0.427555 },
    Vec2.T{ 0.881921, 0.471397 },
    Vec2.T{ 0.857729, 0.514103 },
    Vec2.T{ 0.831470, 0.555570 },
    Vec2.T{ 0.803208, 0.595699 },
    Vec2.T{ 0.773010, 0.634393 },
    Vec2.T{ 0.740951, 0.671559 },
    Vec2.T{ 0.707107, 0.707107 },
    Vec2.T{ 0.671559, 0.740951 },
    Vec2.T{ 0.634393, 0.773010 },
    Vec2.T{ 0.595699, 0.803208 },
    Vec2.T{ 0.555570, 0.831470 },
    Vec2.T{ 0.514103, 0.857729 },
    Vec2.T{ 0.471397, 0.881921 },
    Vec2.T{ 0.427555, 0.903989 },
    Vec2.T{ 0.382683, 0.923880 },
    Vec2.T{ 0.336890, 0.941544 },
    Vec2.T{ 0.290285, 0.956940 },
    Vec2.T{ 0.242980, 0.970031 },
    Vec2.T{ 0.195090, 0.980785 },
    Vec2.T{ 0.146730, 0.989177 },
    Vec2.T{ 0.098017, 0.995185 },
    Vec2.T{ 0.049068, 0.998795 },
    Vec2.T{ 0.000000, 1.000000 },
    Vec2.T{ -0.049068, 0.998795 },
    Vec2.T{ -0.098017, 0.995185 },
    Vec2.T{ -0.146730, 0.989177 },
    Vec2.T{ -0.195090, 0.980785 },
    Vec2.T{ -0.242980, 0.970031 },
    Vec2.T{ -0.290285, 0.956940 },
    Vec2.T{ -0.336890, 0.941544 },
    Vec2.T{ -0.382683, 0.923880 },
    Vec2.T{ -0.427555, 0.903989 },
    Vec2.T{ -0.471397, 0.881921 },
    Vec2.T{ -0.514103, 0.857729 },
    Vec2.T{ -0.555570, 0.831470 },
    Vec2.T{ -0.595699, 0.803208 },
    Vec2.T{ -0.634393, 0.773010 },
    Vec2.T{ -0.671559, 0.740951 },
    Vec2.T{ -0.707107, 0.707107 },
    Vec2.T{ -0.740951, 0.671559 },
    Vec2.T{ -0.773010, 0.634393 },
    Vec2.T{ -0.803208, 0.595699 },
    Vec2.T{ -0.831470, 0.555570 },
    Vec2.T{ -0.857729, 0.514103 },
    Vec2.T{ -0.881921, 0.471397 },
    Vec2.T{ -0.903989, 0.427555 },
    Vec2.T{ -0.923880, 0.382683 },
    Vec2.T{ -0.941544, 0.336890 },
    Vec2.T{ -0.956940, 0.290285 },
    Vec2.T{ -0.970031, 0.242980 },
    Vec2.T{ -0.980785, 0.195090 },
    Vec2.T{ -0.989177, 0.146730 },
    Vec2.T{ -0.995185, 0.098017 },
    Vec2.T{ -0.998795, 0.049068 },
    Vec2.T{ -1.000000, 0.000000 },
    Vec2.T{ -0.998795, -0.049068 },
    Vec2.T{ -0.995185, -0.098017 },
    Vec2.T{ -0.989177, -0.146730 },
    Vec2.T{ -0.980785, -0.195090 },
    Vec2.T{ -0.970031, -0.242980 },
    Vec2.T{ -0.956940, -0.290285 },
    Vec2.T{ -0.941544, -0.336890 },
    Vec2.T{ -0.923880, -0.382683 },
    Vec2.T{ -0.903989, -0.427555 },
    Vec2.T{ -0.881921, -0.471397 },
    Vec2.T{ -0.857729, -0.514103 },
    Vec2.T{ -0.831470, -0.555570 },
    Vec2.T{ -0.803208, -0.595699 },
    Vec2.T{ -0.773010, -0.634393 },
    Vec2.T{ -0.740951, -0.671559 },
    Vec2.T{ -0.707107, -0.707107 },
    Vec2.T{ -0.671559, -0.740951 },
    Vec2.T{ -0.634393, -0.773010 },
    Vec2.T{ -0.595699, -0.803208 },
    Vec2.T{ -0.555570, -0.831470 },
    Vec2.T{ -0.514103, -0.857729 },
    Vec2.T{ -0.471397, -0.881921 },
    Vec2.T{ -0.427555, -0.903989 },
    Vec2.T{ -0.382683, -0.923880 },
    Vec2.T{ -0.336890, -0.941544 },
    Vec2.T{ -0.290285, -0.956940 },
    Vec2.T{ -0.242980, -0.970031 },
    Vec2.T{ -0.195090, -0.980785 },
    Vec2.T{ -0.146730, -0.989177 },
    Vec2.T{ -0.098017, -0.995185 },
    Vec2.T{ -0.049068, -0.998795 },
    Vec2.T{ -0.000000, -1.000000 },
    Vec2.T{ 0.049068, -0.998795 },
    Vec2.T{ 0.098017, -0.995185 },
    Vec2.T{ 0.146730, -0.989177 },
    Vec2.T{ 0.195090, -0.980785 },
    Vec2.T{ 0.242980, -0.970031 },
    Vec2.T{ 0.290285, -0.956940 },
    Vec2.T{ 0.336890, -0.941544 },
    Vec2.T{ 0.382683, -0.923880 },
    Vec2.T{ 0.427555, -0.903989 },
    Vec2.T{ 0.471397, -0.881921 },
    Vec2.T{ 0.514103, -0.857729 },
    Vec2.T{ 0.555570, -0.831470 },
    Vec2.T{ 0.595699, -0.803208 },
    Vec2.T{ 0.634393, -0.773010 },
    Vec2.T{ 0.671559, -0.740951 },
    Vec2.T{ 0.707107, -0.707107 },
    Vec2.T{ 0.740951, -0.671559 },
    Vec2.T{ 0.773010, -0.634393 },
    Vec2.T{ 0.803208, -0.595699 },
    Vec2.T{ 0.831470, -0.555570 },
    Vec2.T{ 0.857729, -0.514103 },
    Vec2.T{ 0.881921, -0.471397 },
    Vec2.T{ 0.903989, -0.427555 },
    Vec2.T{ 0.923880, -0.382683 },
    Vec2.T{ 0.941544, -0.336890 },
    Vec2.T{ 0.956940, -0.290285 },
    Vec2.T{ 0.970031, -0.242980 },
    Vec2.T{ 0.980785, -0.195090 },
    Vec2.T{ 0.989177, -0.146730 },
    Vec2.T{ 0.995185, -0.098017 },
    Vec2.T{ 0.998795, -0.049068 },
    Vec2.T{ 1.000000, -0.000000 },
};

const PathPoint = struct {
    pos: Pos2.T,
    /// For filled paths the normal is used for anti-aliasing (both strokes and filled areas).
    ///
    /// For strokes the normal is also used for giving thickness to the path
    /// (i.e. in what direction to expand).
    ///
    /// The normal could be estimated by differences between successive points,
    /// but that would be less accurate (and in some cases slower).
    ///
    /// Normals are normally unit-length.
    normal: Vec2.T,
};

/// A connected line (without thickness or gaps) which can be tessellated
/// to either to a stroke (with thickness) or a filled convex area.
/// Used as a scratch-pad during tessellation.
const Path = struct {
    points: std.ArrayList(PathPoint),

    pub fn init(allocator: Allocator) Path {
        return .{ .points = std.ArrayList(PathPoint).init(allocator) };
    }

    pub fn deinit(self: Path) void {
        self.points.deinit();
    }

    pub fn clear(self: *Path) void {
        self.points.clearRetainingCapacity();
    }

    pub fn reserve(self: *Path, additional: usize) Allocator.Error!void {
        try self.points.ensureUnusedCapacity(additional);
    }

    pub fn addPoint(self: *Path, pos: Pos2.T, normal: Vec2.T) Allocator.Error!void {
        try self.points.append(PathPoint{ .pos = pos, .normal = normal });
    }

    pub fn addCircle(self: *Path, center: Pos2.T, radius: f32) Allocator.Error!void {
        // These cutoffs are based on a high-dpi display. TODO(emilk): use pixels_per_point here?
        // same cutoffs as in add_circle_quadrant
        const circle =
            // zig fmt: off
            if (radius <= 2.0) &CIRCLE_8
            else if (radius <= 5.0) &CIRCLE_16
            else if (radius < 18.0) &CIRCLE_32
            else if (radius < 50.0) &CIRCLE_64
            else &CIRCLE_128;
            // zig fmt: on

        const added_points = try self.points.addManyAsSlice(circle.len);
        for (added_points, circle) |*added, n| {
            added.* = PathPoint{
                .pos = center + Vec2.splat(radius) * n,
                .normal = n,
            };
        }
    }

    pub fn addLineSegment(self: *Path, points: [2]Pos2.T) Allocator.Error!void {
        const added = try self.points.addManyAsArray(2);
        const normal = Vec2.rot90(Vec2.normalize(points[1] - points[0]));
        added[0] = .{ .pos = points[0], .normal = normal };
        added[1] = .{ .pos = points[1], .normal = normal };
    }

    pub fn addOpenPoints(self: *Path, points: []Pos2.T) Allocator.Error!void {
        const n = points.len;
        std.debug.assert(n >= 2);

        if (n == 2) {
            // Common case optimization:
            try self.addLineSegment([2]Pos2.T{ points[0], points[1] });
        } else {
            try self.reserve(n);
            try self.addPoint(points[0], Vec2.rot90(Vec2.normalize(points[1] - points[0])));
            var n0 = Vec2.rot90(Vec2.normalize(points[1] - points[0]));
            for (1..n - 1) |i| {
                var n1 = Vec2.rot90(Vec2.normalize(points[i + 1] - points[i]));
                // Handle duplicated points (but not triplicated…):
                if (Vec2.isZero(n0)) {
                    n0 = n1;
                } else if (Vec2.isZero(n1)) {
                    n1 = n0;
                }
                const normal = (n0 + n1) / Vec2.splat(2.0);
                const length_sq = Vec2.lengthSq(normal);
                const right_angle_length_sq = 0.5;
                const sharper_than_a_right_angle = length_sq < right_angle_length_sq;
                if (sharper_than_a_right_angle) {
                    // cut off the sharp corner
                    const center_normal = Vec2.normalize(normal);
                    const n0c = (n0 + center_normal) / Vec2.splat(2.0);
                    const n1c = (n1 + center_normal) / Vec2.splat(2.0);
                    try self.addPoint(points[i], n0c / Vec2.splat(Vec2.lengthSq(n0c)));
                    try self.addPoint(points[i], n1c / Vec2.splat(Vec2.lengthSq(n1c)));
                } else {
                    // miter join
                    try self.addPoint(points[i], normal / Vec2.splat(length_sq));
                }
                n0 = n1;
            }
            try self.addPoint(
                points[n - 1],
                Vec2.rot90(Vec2.normalize(points[n - 1] - points[n - 2])),
            );
        }
    }

    pub fn addLineLoop(self: *Path, points: []Pos2.T) Allocator.Error!void {
        const n = points.len;
        std.debug.assert(n >= 2);

        try self.reserve(n);
        var n0 = Vec2.rot90(Vec2.normalize(points[0] - points[n - 1]));
        for (0..n) |i| {
            const next_i = if (i + 1 == n)
                0
            else
                i + 1;
            var n1 = Vec2.rot90(Vec2.normalize(points[next_i] - points[i]));
            // Handle duplicated points (but not triplicated…):
            if (Vec2.isZero(n0)) {
                n0 = n1;
            } else if (Vec2.isZero(n1)) {
                n1 = n0;
            }
            const normal = (n0 + n1) / Vec2.splat(2.0);
            const length_sq = Vec2.lengthSq(normal);
            // We can't just cut off corners for filled shapes like this,
            // because the feather will both expand and contract the corner along the provided normals
            // to make sure it doesn't grow, and the shrinking will make the inner points cross each other.
            //
            // A better approach is to shrink the vertices in by half the feather-width here
            // and then only expand during feathering.
            //
            // See https://github.com/emilk/egui/issues/1226
            const CUT_OFF_SHARP_CORNERS = false;
            const right_angle_length_sq = 0.5;
            const sharper_than_a_right_angle = length_sq < right_angle_length_sq;
            if (CUT_OFF_SHARP_CORNERS and sharper_than_a_right_angle) {
                // cut off the sharp corner
                const center_normal = normal.normalized();
                const n0c = (n0 + center_normal) / 2.0;
                const n1c = (n1 + center_normal) / 2.0;
                self.addPoint(points[i], n0c / Vec2.lengthSq(n0c));
                self.addPoint(points[i], n1c / Vec2.lengthSq(n1c));
            } else {
                // miter join
                try self.addPoint(points[i], normal / Vec2.splat(length_sq));
            }
            n0 = n1;
        }
    }

    /// Open-ended.
    pub fn strokeOpen(self: Path, feathering: f32, stroke0: Stroke.T, out: *Mesh.T) Allocator.Error!void {
        try strokePath(feathering, self.points.items, .open, stroke0, out);
    }
    /// A closed path (returning to the first point).
    pub fn strokeClosed(self: Path, feathering: f32, stroke0: Stroke.T, out: *Mesh.T) Allocator.Error!void {
        try strokePath(feathering, self.points.items, .closed, stroke0, out);
    }
    pub fn stroke(self: Path, feathering: f32, path_type: PathType, stroke0: Stroke.T, out: *Mesh.T) Allocator.Error!void {
        try strokePath(feathering, self.points.items, path_type, stroke0, out);
    }

    /// The path is taken to be closed (i.e. returning to the start again).
    ///
    /// Calling this may reverse the vertices in the path if they are wrong winding order.
    ///
    /// The preferred winding order is clockwise.
    pub fn fill(self: *Path, feathering: f32, color: Color.Color32, out: *Mesh.T) Allocator.Error!void {
        try fillClosedPath(feathering, self.points.items, color, out);
    }

    /// Like [`Self::fill`] but with texturing.
    ///
    /// The `uv_from_pos` is called for each vertex position.
    pub fn fillWithUv(
        self: *Path,
        feathering: f32,
        color: Color.Color32,
        texture_id: Texture.Id,
        rect_to_fill: Rect.T,
        rect_in_texture: Rect.T,
        out: *Mesh.T,
    ) Allocator.Error!void {
        try fillClosedPathWithUv(
            feathering,
            self.points.items,
            color,
            texture_id,
            rect_to_fill,
            rect_in_texture,
            out,
        );
    }
};

const path_module = struct {
    //! Helpers for constructing paths

    /// overwrites existing points
    pub fn roundedRectangle(
        path: *std.ArrayList(Pos2.T),
        rect: Rect.T,
        rounding: Shape.Rounding,
    ) Allocator.Error!void {
        path.clearRetainingCapacity();
        const min = rect.min;
        const max = rect.max;
        const r = clampRounding(rounding, rect);
        if (r.eql(Shape.Rounding.ZERO)) {
            const added = try path.addManyAsArray(4);
            added[0] = Pos2.T{ min[0], min[1] }; // left top
            added[1] = Pos2.T{ max[0], min[1] }; // right top
            added[2] = Pos2.T{ max[0], max[1] }; // right bottom
            added[3] = Pos2.T{ min[0], max[1] }; // left bottom

        } else {
            // We need to avoid duplicated vertices, because that leads to visual artifacts later.
            // Duplicated vertices can happen when one side is all rounding, with no straight edge between.
            const eps = @reduce(.Max, Vec2.splat(std.math.floatEps(f32)) * rect.size());
            try addCircleQuadrant(path, Pos2.T{ max[0] - r.se, max[1] - r.se }, r.se, 0.0); // south east
            if (rect.width() <= r.se + r.sw + eps) {
                _ = path.pop(); // avoid duplicated vertex

            }
            try addCircleQuadrant(path, Pos2.T{ min[0] + r.sw, max[1] - r.sw }, r.sw, 1.0); // south west
            if (rect.height() <= r.sw + r.nw + eps) {
                _ = path.pop(); // avoid duplicated vertex

            }
            try addCircleQuadrant(path, Pos2.T{ min[0] + r.nw, min[1] + r.nw }, r.nw, 2.0); // north west
            if (rect.width() <= r.nw + r.ne + eps) {
                _ = path.pop(); // avoid duplicated vertex

            }
            try addCircleQuadrant(path, Pos2.T{ max[0] - r.ne, min[1] + r.ne }, r.ne, 3.0); // north east
            if (rect.height() <= r.ne + r.se + eps) {
                _ = path.pop(); // avoid duplicated vertex

            }
        }
    }

    /// Add one quadrant of a circle
    ///
    /// * quadrant 0: right bottom
    /// * quadrant 1: left bottom
    /// * quadrant 2: left top
    /// * quadrant 3: right top
    //
    // Derivation:
    //
    // * angle 0 * TAU / 4 = right
    //   - quadrant 0: right bottom
    // * angle 1 * TAU / 4 = bottom
    //   - quadrant 1: left bottom
    // * angle 2 * TAU / 4 = left
    //   - quadrant 2: left top
    // * angle 3 * TAU / 4 = top
    //   - quadrant 3: right top
    // * angle 4 * TAU / 4 = right
    pub fn addCircleQuadrant(path: *std.ArrayList(Pos2.T), center: Pos2.T, radius: f32, quadrant: f32) Allocator.Error!void {
        // These cutoffs are based on a high-dpi display. TODO(emilk): use pixels_per_point here?
        // same cutoffs as in add_circle
        if (radius <= 0.0) {
            try path.append(center);
        } else {
            var quadrant_vertices: []const Vec2.T = undefined;
            if (radius <= 2.0) {
                const offset = @as(usize, @intFromFloat(quadrant)) * 2;
                quadrant_vertices = CIRCLE_8[offset .. offset + 3];
            } else if (radius <= 5.0) {
                const offset = @as(usize, @intFromFloat(quadrant)) * 4;
                quadrant_vertices = CIRCLE_16[offset .. offset + 5];
            } else if (radius < 18.0) {
                const offset = @as(usize, @intFromFloat(quadrant)) * 8;
                quadrant_vertices = CIRCLE_32[offset .. offset + 9];
            } else if (radius < 50.0) {
                const offset = @as(usize, @intFromFloat(quadrant)) * 16;
                quadrant_vertices = CIRCLE_64[offset .. offset + 17];
            } else {
                const offset = @as(usize, @intFromFloat(quadrant)) * 32;
                quadrant_vertices = CIRCLE_128[offset .. offset + 33];
            }

            const added_points = try path.addManyAsSlice(quadrant_vertices.len);
            for (added_points, quadrant_vertices) |*added_point, v| {
                added_point.* = center + Vec2.splat(radius) * v;
            }
        }
    }

    // Ensures the radius of each corner is within a valid range
    fn clampRounding(rounding: Shape.Rounding, rect: Rect.T) Shape.Rounding {
        const half_width = rect.width() * 0.5;
        const half_height = rect.height() * 0.5;
        const max_cr = @min(half_width, half_height);
        return rounding.atMost(max_cr).atLeast(0.0);
    }
};

// ----------------------------------------------------------------------------

pub const PathType = union(enum) {
    open,
    closed,
};

/// Tessellation quality options
pub const TessellationOptions = struct {
    /// Use "feathering" to smooth out the edges of shapes as a form of anti-aliasing.
    ///
    /// Feathering works by making each edge into a thin gradient into transparency.
    /// The size of this edge is controlled by [`Self::feathering_size_in_pixels`].
    ///
    /// This makes shapes appear smoother, but requires more triangles and is therefore slower.
    ///
    /// This setting does not affect text.
    ///
    /// Default: `true`.
    feathering: bool,
    /// The size of the the feathering, in physical pixels.
    ///
    /// The default, and suggested, value for this is `1.0`.
    /// If you use a larger value, edges will appear blurry.
    feathering_size_in_pixels: f32,
    /// If `true` (default) cull certain primitives before tessellating them.
    /// This likely makes
    coarse_tessellation_culling: bool,
    /// If `true`, small filled circled will be optimized by using pre-rasterized circled
    /// from the font atlas.
    prerasterized_discs: bool,
    /// If `true` (default) align text to mesh grid.
    /// This makes the text sharper on most platforms.
    round_text_to_pixels: bool,
    /// Output the clip rectangles to be painted.
    debug_paint_clip_rects: bool,
    /// Output the text-containing rectangles.
    debug_paint_text_rects: bool,
    /// If true, no clipping will be done.
    debug_ignore_clip_rects: bool,
    /// The maximum distance between the original curve and the flattened curve.
    bezier_tolerance: f32,
    /// The default value will be 1.0e-5, it will be used during float compare.
    epsilon: f32,
    /// If `rayon` feature is activated, should we parallelize tessellation?
    parallel_tessellation: bool,
    /// If `true`, invalid meshes will be silently ignored.
    /// If `false`, invalid meshes will cause a panic.
    ///
    /// The default is `false` to save performance.
    validate_meshes: bool,

    pub const DEFAULT = TessellationOptions{
        .feathering = true,
        .feathering_size_in_pixels = 1.0,
        .coarse_tessellation_culling = true,
        .prerasterized_discs = true,
        .round_text_to_pixels = true,
        .debug_paint_text_rects = false,
        .debug_paint_clip_rects = false,
        .debug_ignore_clip_rects = false,
        .bezier_tolerance = 0.1,
        .epsilon = 1.0e-5,
        .parallel_tessellation = true,
        .validate_meshes = false,
    };
};

fn cwSignedArea(path: []PathPoint) f64 {
    if (path.len > 0) {
        const last = path[path.len - 1];
        var previous = last.pos;
        var area: f64 = 0.0;
        for (path) |p| {
            area += @as(f64, previous[0] * p.pos[1] - p.pos[0] * previous[1]);
            previous = p.pos;
        }
        return area;
    } else {
        return 0.0;
    }
}

/// Tessellate the given convex area into a polygon.
///
/// Calling this may reverse the vertices in the path if they are wrong winding order.
///
/// The preferred winding order is clockwise.
fn fillClosedPath(feathering: f32, path: []PathPoint, color: Color.Color32, out: *Mesh.T) Allocator.Error!void {
    if (color.eql(Color.Color32.TRANSPARENT))
        return;

    const n: u32 = @intCast(path.len);
    if (feathering > 0.0) {
        if (cwSignedArea(path) < 0.0) {
            // Wrong winding order - fix:
            std.mem.reverse(PathPoint, path);
            std.mem.reverse(PathPoint, path);
            for (path) |*point| {
                point.normal = -point.normal;
            }
        }
        try out.reserveTriangles(@as(usize, @intCast(3 * n)));
        try out.reserveVertices(@as(usize, @intCast(2 * n)));
        const color_outer = Color.Color32.TRANSPARENT;
        const idx_inner: u32 = @intCast(out.vertices.items.len);
        const idx_outer = idx_inner + 1;
        // The fill:
        for (2..n) |i| {
            try out.addTriangle(idx_inner + 2 * (@as(u32, @intCast(i)) - 1), idx_inner, idx_inner + 2 * @as(u32, @intCast(i)));
        }
        // The feathering:
        var @"i0": u32 = n - 1;
        for (0..n) |@"i1"| {
            const p1 = &path[@"i1"];
            const dm = Vec2.splat(0.5 * feathering) * p1.normal;
            try out.coloredVertex(p1.pos - dm, color);
            try out.coloredVertex(p1.pos + dm, color_outer);
            try out.addTriangle(idx_inner + @as(u32, @intCast(@"i1")) * 2, idx_inner + @"i0" * 2, idx_outer + 2 * @"i0");
            try out.addTriangle(idx_outer + @"i0" * 2, idx_outer + @as(u32, @intCast(@"i1")) * 2, idx_inner + 2 * @as(u32, @intCast(@"i1")));
            @"i0" = @as(u32, @intCast(@"i1"));
        }
    } else {
        try out.reserveTriangles(@as(usize, @intCast(n)));
        const idx: u32 = @intCast(out.vertices.items.len);

        const added_vertices = try out.vertices.addManyAsSlice(path.len);
        for (added_vertices, path) |*added_vertex, p| {
            added_vertex.* = .{ .pos = p.pos, .uv = Mesh.WHITE_UV, .color = color };
        }

        for (2..n) |i| {
            try out.addTriangle(idx, idx + @as(u32, @intCast(i)) - 1, idx + @as(u32, @intCast(i)));
        }
    }
}

/// Given position `pos` inside `rect_to_fill` interpolates position inside `rect_in_texture`.
fn uvForPos(pos: Pos2.T, rect_to_fill: Rect.T, rect_in_texture: Rect.T) Pos2.T {
    const from_x = rect_to_fill.xRange();
    const to_x = rect_in_texture.xRange();
    const from_y = rect_to_fill.yRange();
    const to_y = rect_in_texture.yRange();
    return .{
        m.remap(f32, pos[0], from_x.min, from_x.max, to_x.min, to_x.max),
        m.remap(f32, pos[1], from_y.min, from_y.max, to_y.min, to_y.max),
    };
}

/// Like [`fill_closed_path`] but with texturing.
///
/// The `uv_from_pos` is called for each vertex position.
fn fillClosedPathWithUv(
    feathering: f32,
    path: []PathPoint,
    color: Color.Color32,
    texture_id: Texture.Id,
    rect_to_fill: Rect.T,
    rect_in_texture: Rect.T,
    out: *Mesh.T,
) Allocator.Error!void {
    if (color.eql(Color.Color32.TRANSPARENT))
        return;

    if (out.isEmpty()) {
        out.texture_id = texture_id;
    } else {
        // Single mesh cannot use two different textures.
        std.debug.assert(out.texture_id.eql(texture_id));
    }

    const n: u32 = @intCast(path.len);
    if (feathering > 0.0) {
        if (cwSignedArea(path) < 0.0) {
            // Wrong winding order - fix:
            std.mem.reverse(PathPoint, path);
            for (path) |*point| {
                point.normal = -point.normal;
            }
        }

        try out.reserveTriangles(@as(usize, @intCast(3 * n)));
        try out.reserveVertices(@as(usize, @intCast(2 * n)));
        const color_outer = Color.Color32.TRANSPARENT;
        const idx_inner: u32 = @intCast(out.vertices.items.len);
        const idx_outer = idx_inner + 1;
        // The fill:
        for (2..n) |i| {
            try out.addTriangle(idx_inner + 2 * (@as(u32, @intCast(i)) - 1), idx_inner, idx_inner + 2 * @as(u32, @intCast(i)));
        }

        // The feathering:
        var @"i0": u32 = n - 1;
        for (0..n) |@"i1"| {
            const p1 = &path[@"i1"];
            const dm = Vec2.splat(0.5 * feathering) * p1.normal;

            // This part is different from `fillClosedPath`.
            const pos1 = p1.pos - dm;
            try out.vertices.append(.{
                .pos = pos1,
                .uv = uvForPos(pos1, rect_to_fill, rect_in_texture),
                .color = color,
            });
            const pos2 = p1.pos + dm;
            try out.vertices.append(.{
                .pos = pos2,
                .uv = uvForPos(pos2, rect_to_fill, rect_in_texture),
                .color = color_outer,
            });

            try out.addTriangle(idx_inner + @as(u32, @intCast(@"i1")) * 2, idx_inner + @"i0" * 2, idx_outer + 2 * @"i0");
            try out.addTriangle(idx_outer + @"i0" * 2, idx_outer + @as(u32, @intCast(@"i1")) * 2, idx_inner + 2 * @as(u32, @intCast(@"i1")));
            @"i0" = @as(u32, @intCast(@"i1"));
        }
    } else {
        try out.reserveTriangles(@as(usize, @intCast(n)));
        const idx: u32 = @intCast(out.vertices.items.len);

        const added_vertices = try out.vertices.addManyAsSlice(path.len);
        for (added_vertices, path) |*added_vertex, p| {
            // The only difference from `fillClosedPath` is that instead of `Mesh.WHITE_UV`
            // we use `uvFromPos (p.pos)`.
            added_vertex.* = .{ .pos = p.pos, .uv = uvForPos(p.pos, rect_to_fill, rect_in_texture), .color = color };
        }

        for (2..n) |i| {
            try out.addTriangle(idx, idx + @as(u32, @intCast(i)) - 1, idx + @as(u32, @intCast(i)));
        }
    }
}

/// Tessellate the given path as a stroke with thickness.
fn strokePath(
    feathering: f32,
    path: []PathPoint,
    path_type: PathType,
    stroke: Stroke.T,
    out: *Mesh.T,
) Allocator.Error!void {
    const n: u32 = @intCast(path.len);
    if (stroke.width <= 0.0 or stroke.color.eql(Color.Color32.TRANSPARENT) or n < 2)
        return;

    const idx: u32 = @intCast(out.vertices.items.len);
    if (feathering > 0.0) {
        var color_inner = stroke.color;
        const color_outer = Color.Color32.TRANSPARENT;
        const thin_line = stroke.width <= feathering;
        if (thin_line) {
            //
            // We paint the line using three edges: outer, inner, outer.
            //
            //       o   i   o      outer, inner, outer
            //       |---|          feathering (pixel width)
            //

            // Fade out as it gets thinner:

            color_inner = mulColor(color_inner, stroke.width / feathering);
            if (color_inner.eql(Color.Color32.TRANSPARENT)) {
                return;
            }
            try out.reserveTriangles(@as(usize, @intCast(4 * n)));
            try out.reserveVertices(@as(usize, @intCast(3 * n)));
            var @"i0" = n - 1;
            for (0..n) |@"i1"| {
                const connect_with_previous = path_type == .closed or @"i1" > 0;
                const p1 = &path[@as(usize, @intCast(@"i1"))];
                const p = p1.pos;
                const normal = p1.normal;
                try out.coloredVertex(p + normal * Vec2.splat(feathering), color_outer);
                try out.coloredVertex(p, color_inner);
                try out.coloredVertex(p - normal * Vec2.splat(feathering), color_outer);
                if (connect_with_previous) {
                    try out.addTriangle(idx + 3 * @"i0" + 0, idx + 3 * @"i0" + 1, idx + 3 * @as(u32, @intCast(@"i1")) + 0);
                    try out.addTriangle(idx + 3 * @"i0" + 1, idx + 3 * @as(u32, @intCast(@"i1")) + 0, idx + 3 * @as(u32, @intCast(@"i1")) + 1);
                    try out.addTriangle(idx + 3 * @"i0" + 1, idx + 3 * @"i0" + 2, idx + 3 * @as(u32, @intCast(@"i1")) + 1);
                    try out.addTriangle(idx + 3 * @"i0" + 2, idx + 3 * @as(u32, @intCast(@"i1")) + 1, idx + 3 * @as(u32, @intCast(@"i1")) + 2);
                }
                @"i0" = @as(u32, @intCast(@"i1"));
            }
        } else {
            // thick anti-aliased line

            //
            // We paint the line using four edges: outer, inner, inner, outer
            //
            //       o   i     p    i   o   outer, inner, point, inner, outer
            //       |---|                  feathering (pixel width)
            //         |--------------|     width
            //       |---------|            outer_rad
            //           |-----|            inner_rad
            //

            const inner_rad = 0.5 * (stroke.width - feathering);
            const outer_rad = 0.5 * (stroke.width + feathering);
            switch (path_type) {
                .closed => {
                    try out.reserveTriangles(@as(usize, @intCast(6 * n)));
                    try out.reserveVertices(@as(usize, @intCast(4 * n)));
                    var @"i0" = n - 1;
                    for (0..n) |@"i1"| {
                        const p1 = &path[@as(usize, @intCast(@"i1"))];
                        const p = p1.pos;
                        const normal = p1.normal;
                        try out.coloredVertex(p + normal * Vec2.splat(outer_rad), color_outer);
                        try out.coloredVertex(p + normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(outer_rad), color_outer);
                        try out.addTriangle(idx + 4 * @"i0" + 0, idx + 4 * @"i0" + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 0);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 0, idx + 4 * @as(u32, @intCast(@"i1")) + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @"i0" + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @"i0" + 3, idx + 4 * @as(u32, @intCast(@"i1")) + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 3, idx + 4 * @as(u32, @intCast(@"i1")) + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 3);
                        @"i0" = @as(u32, @intCast(@"i1"));
                    }
                },
                .open => {
                    // Anti-alias the ends by extruding the outer edge and adding
                    // two more triangles to each end:
                    //   | aa |       | aa |
                    //    _________________   ___
                    //   | \    added    / |  feathering
                    //   |   \ ___p___ /   |  ___
                    //   |    |       |    |
                    //   |    |  opa  |    |
                    //   |    |  que  |    |
                    //   |    |       |    |
                    // (in the future it would be great with an option to add a circular end instead)
                    try out.reserveTriangles(6 * @as(usize, @intCast(n)) + 4);
                    try out.reserveVertices(4 * @as(usize, @intCast(n)));
                    {
                        const end = &path[0];
                        const p = end.pos;
                        const normal = end.normal;
                        const back_extrude = Vec2.rot90(normal) * Vec2.splat(feathering);
                        try out.coloredVertex(p + normal * Vec2.splat(outer_rad) + back_extrude, color_outer);
                        try out.coloredVertex(p + normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(outer_rad) + back_extrude, color_outer);
                        try out.addTriangle(idx + 0, idx + 1, idx + 2);
                        try out.addTriangle(idx + 0, idx + 2, idx + 3);
                    }
                    var @"i0": u32 = 0;
                    for (1..n - 1) |@"i1"| {
                        const point = &path[@as(usize, @intCast(@"i1"))];
                        const p = point.pos;
                        const normal = point.normal;
                        try out.coloredVertex(p + normal * Vec2.splat(outer_rad), color_outer);
                        try out.coloredVertex(p + normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(outer_rad), color_outer);
                        try out.addTriangle(idx + 4 * @"i0" + 0, idx + 4 * @"i0" + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 0);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 0, idx + 4 * @as(u32, @intCast(@"i1")) + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @"i0" + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 1, idx + 4 * @as(u32, @intCast(@"i1")) + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @"i0" + 3, idx + 4 * @as(u32, @intCast(@"i1")) + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 3, idx + 4 * @as(u32, @intCast(@"i1")) + 2, idx + 4 * @as(u32, @intCast(@"i1")) + 3);
                        @"i0" = @as(u32, @intCast(@"i1"));
                    }
                    {
                        const @"i1" = n - 1;
                        const end = &path[@as(usize, @intCast(@"i1"))];
                        const p = end.pos;
                        const normal = end.normal;
                        const back_extrude = -Vec2.rot90(normal) * Vec2.splat(feathering);
                        try out.coloredVertex(p + normal * Vec2.splat(outer_rad) + back_extrude, color_outer);
                        try out.coloredVertex(p + normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(inner_rad), color_inner);
                        try out.coloredVertex(p - normal * Vec2.splat(outer_rad) + back_extrude, color_outer);
                        try out.addTriangle(idx + 4 * @"i0" + 0, idx + 4 * @"i0" + 1, idx + 4 * @"i1" + 0);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @"i1" + 0, idx + 4 * @"i1" + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 1, idx + 4 * @"i0" + 2, idx + 4 * @"i1" + 1);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @"i1" + 1, idx + 4 * @"i1" + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 2, idx + 4 * @"i0" + 3, idx + 4 * @"i1" + 2);
                        try out.addTriangle(idx + 4 * @"i0" + 3, idx + 4 * @"i1" + 2, idx + 4 * @"i1" + 3);
                        // The extension:
                        try out.addTriangle(idx + 4 * @"i1" + 0, idx + 4 * @"i1" + 1, idx + 4 * @"i1" + 2);
                        try out.addTriangle(idx + 4 * @"i1" + 0, idx + 4 * @"i1" + 2, idx + 4 * @"i1" + 3);
                    }
                },
            }
        }
    } else {
        // not anti-aliased:
        try out.reserveTriangles(2 * @as(usize, @intCast(n)));
        try out.reserveVertices(2 * @as(usize, @intCast(n)));
        const last_index = if (path_type == .closed)
            n
        else
            n - 1;
        for (0..last_index) |i| {
            try out.addTriangle(
                idx + (2 * @as(u32, @intCast(i)) + 0) % (2 * n),
                idx + (2 * @as(u32, @intCast(i)) + 1) % (2 * n),
                idx + (2 * @as(u32, @intCast(i)) + 2) % (2 * n),
            );
            try out.addTriangle(
                idx + (2 * @as(u32, @intCast(i)) + 2) % (2 * n),
                idx + (2 * @as(u32, @intCast(i)) + 1) % (2 * n),
                idx + (2 * @as(u32, @intCast(i)) + 3) % (2 * n),
            );
        }
        const thin_line = stroke.width <= feathering;
        if (thin_line) {
            // Fade out thin lines rather than making them thinner
            const radius = feathering / 2.0;
            const color = mulColor(stroke.color, stroke.width / feathering);
            if (color.eql(Color.Color32.TRANSPARENT)) {
                return;
            }
            for (path) |p| {
                try out.coloredVertex(p.pos + Vec2.splat(radius) * p.normal, color);
                try out.coloredVertex(p.pos - Vec2.splat(radius) * p.normal, color);
            }
        } else {
            const radius = stroke.width / 2.0;
            for (path) |p| {
                try out.coloredVertex(p.pos + Vec2.splat(radius) * p.normal, stroke.color);
                try out.coloredVertex(p.pos - Vec2.splat(radius) * p.normal, stroke.color);
            }
        }
    }
}
fn mulColor(color: Color.Color32, factor: f32) Color.Color32 {
    // The fast gamma-space multiply also happens to be perceptually better.
    // Win-win!
    return color.gammaMultiply(factor);
}

// ----------------------------------------------------------------------------

/// Converts [`Shape`]s into triangles ([`Mesh`]).
///
/// For performance reasons it is smart to reuse the same [`Tessellator`].
///
/// See also [`tessellate_shapes`], a convenient wrapper around [`Tessellator`].
pub const T = struct {
    allocator: Allocator,
    pixels_per_point: f32,
    options: TessellationOptions,
    font_tex_size: [2]usize,
    /// See [`TextureAtlas::prepared_discs`].
    prepared_discs: std.ArrayList(TextureAtlas.PreparedDisc),
    /// size of feathering in points. normally the size of a physical pixel. 0.0 if disabled
    feathering: f32,
    /// Only used for culling
    clip_rect: Rect.T,
    scratchpad_points: std.ArrayList(Pos2.T),
    scratchpad_path: Path,

    // `prepared_discs` are not touched.
    pub fn deinit(self: T) void {
        self.scratchpad_points.deinit();
        self.scratchpad_path.deinit();
    }

    /// Set the [`Rect`] to use for culling.
    pub fn setClipRect(self: *T, clip_rect: Rect.T) void {
        self.clip_rect = clip_rect;
    }

    pub fn roundToPixel(self: T, point: f32) f32 {
        return if (self.options.round_text_to_pixels)
            std.math.round(point * self.pixels_per_point) / self.pixels_per_point
        else
            point;
    }

    // TODO: Translate `tessellateClippedShape` from Rust to Zig.
    // TODO: Translate `tessellateShape` from Rust to Zig.

    /// Tessellate a single [`CircleShape`] into a [`Mesh`].
    ///
    /// * `shape`: the circle to tessellate.
    /// * `out`: triangles are appended to this.
    pub fn tessellateCircle(self: *T, circle: Shape.Circle, out: *Mesh.T) Allocator.Error!void {
        const center = circle.center;
        const radius = circle.radius;
        var fill = circle.fill;
        const stroke = circle.stroke;
        if (radius <= 0.0)
            return;

        if (self.options.coarse_tessellation_culling and !self.clip_rect.expand(radius + stroke.width).contains(center))
            return;

        if (self.options.prerasterized_discs and !fill.eql(Color.Color32.TRANSPARENT)) {
            const radius_px = radius * self.pixels_per_point;
            // strike the right balance between some circles becoming too blurry, and some too sharp.
            const cutoff_radius = radius_px * std.math.pow(f32, 2.0, 0.25);
            // Find the right disc radius for a crisp edge:
            // TODO(emilk): perhaps we can do something faster than this linear search.
            for (self.prepared_discs.items) |disc| {
                if (cutoff_radius <= disc.r) {
                    const side = radius_px * disc.w / (self.pixels_per_point * disc.r);
                    const rect = Rect.fromCenterSize(center, Vec2.splat(side));
                    try out.addRectWithUv(rect, disc.uv, fill);
                    if (stroke.isEmpty()) {
                        return; // we are done

                    } else {
                        // we still need to do the stroke
                        fill = Color.Color32.TRANSPARENT; // don't fill again below
                        break;
                    }
                }
            }
        }
        self.scratchpad_path.clear();
        try self.scratchpad_path.addCircle(center, radius);
        try self.scratchpad_path.fill(self.feathering, fill, out);
        try self.scratchpad_path.strokeClosed(self.feathering, stroke, out);
    }

    /// Tessellate a single [`EllipseShape`] into a [`Mesh`].
    ///
    /// * `shape`: the ellipse to tessellate.
    /// * `out`: triangles are appended to this.
    pub fn tessellateEllipse(self: *T, ellipse: Shape.Ellipse, out: *Mesh.T) Allocator.Error!void {
        const center = ellipse.center;
        const radius = ellipse.radius;
        const fill = ellipse.fill;
        const stroke = ellipse.stroke;
        if (radius[0] <= 0.0 or radius[1] <= 0.0)
            return;

        if (self.options.coarse_tessellation_culling and
            !self.clip_rect.expand2(radius + Vec2.splat(stroke.width)).contains(center))
            return;

        // Get the max pixel radius
        const max_radius: u32 = @intFromFloat(@reduce(.Max, radius) * self.pixels_per_point);
        // Ensure there is at least 8 points in each quarter of the ellipse
        const num_points: u32 = @max(8, max_radius / 16);
        // Create an ease ratio based the ellipses a and b
        const ratio = std.math.clamp((radius[1] / radius[0]) / 2.0, 0.0, 1.0);

        // Generate points between the 0 to pi/2
        const quarter = try self.allocator.alloc(Vec2.T, num_points);
        defer self.allocator.free(quarter);
        for (quarter, 1..) |*q, i| {
            const percent = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_points));

            // Ease the percent value, concentrating points around tight bends
            const eased = 2.0 * (percent - percent * percent) * ratio + percent * percent;

            // Scale the ease to the quarter
            const t = eased * std.math.pi / 2;
            q.* = Vec2.T{ radius[0] * @cos(t), radius[1] * @sin(t) };
        }

        // Build the ellipse from the 4 known vertices filling arcs between
        // them by mirroring the points between 0 and pi/2
        var points = try std.ArrayList(Vec2.T).initCapacity(self.allocator, 4 * (quarter.len + 1));
        defer points.deinit();

        try points.append(center + Vec2.T{ radius[0], 0.0 });
        for (try points.addManyAsSlice(quarter.len), quarter) |*added_point, q| {
            added_point.* = center + q;
        }

        try points.append(center + Vec2.T{ 0.0, radius[1] });
        for (try points.addManyAsSlice(quarter.len), 0..) |*added_point, i| {
            const q = quarter[quarter.len - i - 1];
            added_point.* = center + Vec2.T{ -q[0], q[1] };
        }

        try points.append(center + Vec2.T{ -radius[0], 0.0 });
        for (try points.addManyAsSlice(quarter.len), quarter) |*added_point, q| {
            added_point.* = center - q;
        }

        try points.append(center + Vec2.T{ 0.0, -radius[1] });
        for (try points.addManyAsSlice(quarter.len), 0..) |*added_point, i| {
            const q = quarter[quarter.len - i - 1];
            added_point.* = center + Vec2.T{ q[0], -q[1] };
        }

        self.scratchpad_path.clear();
        try self.scratchpad_path.addLineLoop(points.items);
        try self.scratchpad_path.fill(self.feathering, fill, out);
        try self.scratchpad_path.strokeClosed(self.feathering, stroke, out);
    }

    // TODO: Translate `tessellateMesh` from Rust to Zig.

    /// Tessellate a line segment between the two points with the given stroke into a [`Mesh`].
    ///
    /// * `shape`: the mesh to tessellate.
    /// * `out`: triangles are appended to this.
    pub fn tessellateLine(self: *T, points: [2]Pos2.T, stroke: Stroke.T, out: *Mesh.T) Allocator.Error!void {
        if (stroke.isEmpty())
            return;
        if (self.options.coarse_tessellation_culling and
            !self.clip_rect.intersects(Rect.fromTwoPos(points[0], points[1]).expand(stroke.width)))
            return;

        self.scratchpad_path.clear();
        try self.scratchpad_path.addLineSegment(points);
        try self.scratchpad_path.strokeOpen(self.feathering, stroke, out);
    }

    /// Tessellate a single [`PathShape`] into a [`Mesh`].
    ///
    /// * `path_shape`: the path to tessellate.
    /// * `out`: triangles are appended to this.
    pub fn tessellatePath(self: *T, path: Shape.Path, out: *Mesh.T) Allocator.Error!void {
        if (path.points.items.len < 2)
            return;

        if (self.options.coarse_tessellation_culling and !path.visualBoundingRect().intersects(self.clip_rect))
            return;

        const points = path.points.items;
        const closed = path.closed;
        const fill = path.fill;
        const stroke = path.stroke;

        self.scratchpad_path.clear();
        if (closed) {
            try self.scratchpad_path.addLineLoop(points);
        } else {
            try self.scratchpad_path.addOpenPoints(points);
        }
        if (!fill.eql(Color.Color32.TRANSPARENT)) {
            std.debug.assert(closed); // You asked to fill a path that is not closed. That makes no sense.
            try self.scratchpad_path.fill(self.feathering, fill, out);
        }
        const typ: PathType = if (closed)
            .closed
        else
            .open;
        try self.scratchpad_path.stroke(self.feathering, typ, stroke, out);
    }

    /// Tessellate a single [`Rect`] into a [`Mesh`].
    ///
    /// * `rect`: the rectangle to tessellate.
    /// * `out`: triangles are appended to this.
    pub fn tessellateRect(self: *T, rect0: Shape.Rect, out: *Mesh.T) Allocator.Error!void {
        var rect = rect0.rect;
        var rounding = rect0.rounding;
        const fill = rect0.fill;
        const stroke = rect0.stroke;
        var blur_width = rect0.blur_width;
        const fill_texture_id = rect0.fill_texture_id;
        const uv = rect0.uv;

        if (self.options.coarse_tessellation_culling and !rect.expand(stroke.width).intersects(self.clip_rect))
            return;

        if (rect.isNegative())
            return;

        // It is common to (sometimes accidentally) create an infinitely sized rectangle.
        // Make sure we can handle that:
        rect.min = @max(rect.min, Pos2.T{ -1e7, -1e7 });
        rect.max = @min(rect.max, Pos2.T{ 1e7, 1e7 });
        const old_feathering = self.feathering;
        if (old_feathering < blur_width) {
            // We accomplish the blur by using a larger-than-normal feathering.
            // Feathering is usually used to make the edges of a shape softer for anti-aliasing.
            // The tessellator can't handle blurring/feathering larger than the smallest side of the rect.
            // Thats because the tessellator approximate very thin rectangles as line segments,
            // and these line segments don't have rounded corners.
            // When the feathering is small (the size of a pixel), this is usually fine,
            // but here we have a huge feathering to simulate blur,
            // so we need to avoid this optimization in the tessellator,
            // which is also why we add this rather big epsilon:
            const eps = 0.1;
            blur_width = std.math.clamp(blur_width, 0.0, @reduce(.Min, rect.size()) - eps);
            rounding = rounding.add(Shape.Rounding.same(0.5 * blur_width));
            self.feathering = @max(self.feathering, blur_width);
        }
        if (rect.width() < self.feathering) {
            // Very thin - approximate by a vertical line-segment:
            const line = [_]Pos2.T{ rect.centerTop(), rect.centerBottom() };
            if (!fill.eql(Color.Color32.TRANSPARENT)) {
                try self.tessellateLine(line, .{ .width = rect.width(), .color = fill }, out);
            }
            if (!stroke.isEmpty()) {
                try self.tessellateLine(line, stroke, out); // back…
                try self.tessellateLine(line, stroke, out); // …and forth

            }
        } else if (rect.height() < self.feathering) {
            // Very thin - approximate by a horizontal line-segment:
            const line = [_]Pos2.T{ rect.leftCenter(), rect.rightCenter() };
            if (!fill.eql(Color.Color32.TRANSPARENT)) {
                try self.tessellateLine(line, .{ .width = rect.height(), .color = fill }, out);
            }
            if (!stroke.isEmpty()) {
                try self.tessellateLine(line, stroke, out); // back…
                try self.tessellateLine(line, stroke, out); // …and forth

            }
        } else {
            const path = &self.scratchpad_path;
            path.clear();
            try path_module.roundedRectangle(&self.scratchpad_points, rect, rounding);
            try path.addLineLoop(self.scratchpad_points.items);
            if (uv.isPositive()) {
                // Textured
                try path.fillWithUv(
                    self.feathering,
                    fill,
                    fill_texture_id,
                    rect,
                    uv,
                    out,
                );
            } else {
                // Untextured
                try path.fill(self.feathering, fill, out);
            }
            try path.strokeClosed(self.feathering, stroke, out);
        }
        self.feathering = old_feathering; // restore

    }

    // TODO: Translate `tessellateText` from Rust to Zig.
    // TODO: Translate `tessellateQuadraticBezier` from Rust to Zig.
    // TODO: Translate `tessellateCubicBezier` from Rust to Zig.
    // TODO: Translate `tessellateBezierComplete` from Rust to Zig.
    // TODO: Translate `addClipRects` from Rust to Zig.
};

// TODO: Shouldn't `prepared_discs` be slice rather than `ArrayList`?

/// Create a new [`Tessellator`].
///
/// * `pixels_per_point`: number of physical pixels to each logical point
/// * `options`: tessellation quality
/// * `shapes`: what to tessellate
/// * `font_tex_size`: size of the font texture. Required to normalize glyph uv rectangles when tessellating text.
/// * `prepared_discs`: What [`TextureAtlas::prepared_discs`] returns. Can safely be set to an empty vec.
pub fn init(
    allocator: Allocator,
    pixels_per_point: f32,
    options: TessellationOptions,
    font_tex_size: [2]usize,
    prepared_discs: std.ArrayList(TextureAtlas.PreparedDisc),
) T {
    var feathering: f32 = 0;
    if (options.feathering) {
        const pixel_size = 1.0 / pixels_per_point;
        feathering = options.feathering_size_in_pixels * pixel_size;
    }
    return .{
        .allocator = allocator,
        .pixels_per_point = pixels_per_point,
        .options = options,
        .font_tex_size = font_tex_size,
        .prepared_discs = prepared_discs,
        .feathering = feathering,
        .clip_rect = Rect.EVERYTHING,
        .scratchpad_points = std.ArrayList(Pos2.T).init(allocator),
        .scratchpad_path = Path.init(allocator),
    };
}

// TODO: Translate tessellator test from Rust to Zig.
