const std = @import("std");
const Allocator = std.mem.Allocator;

const Pos2 = @import("../emath/Pos2.zig");
const Rect = @import("../emath/Rect.zig");
const Rot2 = @import("../emath/Rot2.zig");
const Vec2 = @import("../emath/Vec2.zig");

const Color = @import("Color.zig");
const Texture = @import("Texture.zig");
const TSTransform = @import("TSTransform.zig");

/// The UV coordinate of a white region of the texture mesh.
/// The default egui texture has the top-left corner pixel fully white.
/// You need need use a clamping texture sampler for this to work
/// (so it doesn't do bilinear blending with bottom right corner).
pub const WHITE_UV = Pos2.ZERO;

/// The 2D vertex type.
///
/// Should be friendly to send to GPU as is.
pub const Vertex = extern struct {
    /// Logical pixel coordinates (points).
    /// (0,0) is the top left corner of the screen.
    pos: Pos2.T, // 64 bit
    /// Normalized texture coordinates.
    /// (0, 0) is the top left corner of the texture.
    /// (1, 1) is the bottom right corner of the texture.
    uv: Pos2.T, // 64 bit
    /// sRGBA with premultiplied alpha
    color: Color.Color32, // 32 bit
};

/// Textured triangles in two dimensions.
pub const T = struct {
    /// Draw as triangles (i.e. the length is always multiple of three).
    ///
    /// If you only support 16-bit indices you can use [`Mesh::split_to_u16`].
    ///
    /// egui is NOT consistent with what winding order it uses, so turn off backface culling.
    indices: std.ArrayList(u32),
    /// The vertex data indexed by `indices`.
    vertices: std.ArrayList(Vertex),
    /// The texture to use when drawing these triangles.
    texture_id: Texture.Id,
    // TODO(emilk): bounding rectangle

    pub fn deinit(self: *T) void {
        self.indices.deinit();
        self.vertices.deinit();
    }

    /// Restore to default state, but without freeing memory.
    pub fn clear(self: *T) void {
        self.indices.clearRetainingCapacity();
        self.vertices.clearRetainingCapacity();
    }

    /// Are all indices within the bounds of the contained vertices?
    pub fn isValid(self: T) bool {
        const n: u32 = @truncate(self.vertices.items.len);
        if (@as(usize, @intCast(n)) == self.vertices.items.len) {
            // `len` fits into `u32`.
            for (self.indices.items) |i| {
                if (i >= n) return false;
            }
            return true;
        } else return false;
    }

    pub fn isEmpty(self: T) bool {
        return self.indices.items.len == 0 and self.vertices.items.len == 0;
    }

    /// Calculate a bounding rectangle.
    pub fn calcBounds(self: T) Rect.T {
        var bounds = Rect.NOTHING;
        for (self.vertices.items) |v| {
            bounds.extendWith(v.pos);
        }
        return bounds;
    }

    /// Append all the indices and vertices of `other` to `self` without
    /// taking ownership.
    pub fn appendRef(self: *T, other: T) Allocator.Error!void {
        std.debug.assert(other.isValid());
        if (self.isEmpty()) {
            self.texture_id = other.texture_id;
        } else {
            if (self.texture_id.eql(other.texture_id))
                @panic("Can't merge Mesh using different textures.");
        }

        // CONSIDER: Check overflows? Or just compile with `ReleaseSafe`?
        const index_offset: u32 = @intCast(self.vertices.items.len);
        const added_indices = try self.indices.addManyAsSlice(other.indices.items.len);
        for (added_indices, other.indices.items) |*added_index, other_index| {
            added_index.* = other_index + index_offset;
        }
        const added_vertices = try self.vertices.addManyAsSlice(other.vertices.items.len);
        for (added_vertices, other.vertices.items) |*added_vertex, other_vertex| {
            added_vertex.* = other_vertex;
        }
    }

    pub fn coloredVertex(self: *T, pos: Pos2.T, color: Color.Color32) Allocator.Error!void {
        std.debug.assert(self.texture_id.eql(Texture.Id.DEFAULT));
        try self.vertices.append(Vertex{
            .pos = pos,
            .uv = WHITE_UV,
            .color = color,
        });
    }

    /// Add a triangle.
    pub fn addTriangle(self: *T, a: u32, b: u32, c: u32) Allocator.Error!void {
        const added = try self.indices.addManyAsArray(3);
        added[0] = a;
        added[1] = b;
        added[2] = c;
    }

    /// Make room for this many additional triangles (will reserve 3x as many indices).
    /// See also `reserve_vertices`.
    pub fn reserveTriangles(self: *T, additional_triangles: usize) Allocator.Error!void {
        try self.indices.ensureUnusedCapacity(3 * additional_triangles);
    }
    /// Make room for this many additional vertices.
    /// See also `reserve_triangles`.
    pub fn reserveVertices(self: *T, additional: usize) Allocator.Error!void {
        try self.vertices.ensureUnusedCapacity(additional);
    }

    /// Rectangle with a texture and color.
    pub fn addRectWithUv(self: *T, rect: Rect.T, uv: Rect.T, color: Color.Color32) Allocator.Error!void {
        const idx: u32 = @intCast(self.vertices.items.len);
        try self.addTriangle(idx + 0, idx + 1, idx + 2);
        try self.addTriangle(idx + 2, idx + 1, idx + 3);
        try self.vertices.append(Vertex{
            .pos = rect.leftTop(),
            .uv = uv.leftTop(),
            .color = color,
        });
        try self.vertices.append(Vertex{
            .pos = rect.rightTop(),
            .uv = uv.rightTop(),
            .color = color,
        });
        try self.vertices.append(Vertex{
            .pos = rect.leftBottom(),
            .uv = uv.leftBottom(),
            .color = color,
        });
        try self.vertices.append(Vertex{
            .pos = rect.rightBottom(),
            .uv = uv.rightBottom(),
            .color = color,
        });
    }

    /// Uniformly colored rectangle.
    pub fn addColoredRect(self: *T, rect: Rect.T, color: Color.Color32) Allocator.Error!void {
        std.debug.assert(self.texture_id.eql(Texture.Id.DEFAULT));
        try self.addRectWithUv(
            rect,
            Rect.T{ .min = WHITE_UV, .max = WHITE_UV },
            color,
        );
    }

    /// Translate location by this much, in-place
    pub fn translate(self: *T, delta: Vec2.T) void {
        for (self.vertices.items) |*v| {
            v.pos += delta;
        }
    }
    /// Transform the mesh in-place with the given transform.
    pub fn transform(self: *T, tr: TSTransform.T) void {
        for (self.vertices.items) |*v| {
            v.pos = tr.transformPos(v.pos);
        }
    }
    /// Rotate by some angle about an origin, in-place.
    ///
    /// Origin is a position in screen space.
    pub fn rotate(self: *T, rot: Rot2.T, origin: Pos2.T) void {
        for (self.vertices.items) |*v| {
            v.pos = origin + rot.rotateVec2(v.pos - origin);
        }
    }
};

pub fn init(allocator: Allocator, texture_id: Texture.Id) T {
    return T{
        .indices = std.ArrayList(u32).init(allocator),
        .vertices = std.ArrayList(Vertex).init(allocator),
        .texture_id = texture_id,
    };
}
