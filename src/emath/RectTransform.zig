const std = @import("std");

const m = @import("lib.zig");
const Pos2 = m.Pos2;
const Rect = m.Rect;
const Vec2 = m.Vec2;

/// Linearly transforms positions from one [`Rect`] to another.
///
/// [`RectTransform`] stores the rectangles, and therefore supports clamping and culling.
pub const T = struct {
    from: Rect.T,
    to: Rect.T,

    /// The scale factors.
    pub fn scale(self: T) Vec2.T {
        return self.to.size() / self.from.size();
    }

    pub fn inverse(self: T) T {
        return fromTo(self.to, self.from);
    }

    /// Transforms the given coordinate in the `from` space to the `to` space.
    pub fn transformPos(self: T, pos: Pos2.T) Pos2.T {
        return .{
            m.remap(pos[0], self.from.xRange(), self.to.xRange()),
            m.remap(pos[1], self.from.yRange(), self.to.yRange()),
        };
    }

    /// Transforms the given rectangle in the `in`-space to a rectangle in the `out`-space.
    pub fn transformRect(self: T, rect: Rect) Rect {
        return .{
            .min = self.transformPos(rect.min),
            .max = self.transformPos(rect.max),
        };
    }

    /// Transforms the given coordinate in the `from` space to the `to` space,
    /// clamping if necessary.
    pub fn transformPosClamped(self: T, pos: Pos2.T) Pos2.T {
        return .{
            m.remapClamp(pos[0], self.from.xRange(), self.to.xRange()),
            m.remapClamp(pos[1], self.from.yRange(), self.to.yRange()),
        };
    }
};

pub fn identity(from_and_to: Rect.T) T {
    return fromTo(from_and_to, from_and_to);
}

pub fn fromTo(from: Rect.T, to: Rect.T) T {
    return .{ .from = from, .to = to };
}
