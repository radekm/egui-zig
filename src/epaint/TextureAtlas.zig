const std = @import("std");

const Rect = @import("../emath/Rect.zig");

pub const Rectu = struct {
    /// inclusive
    min_x: usize,
    /// inclusive
    min_y: usize,
    /// exclusive
    max_x: usize,
    /// exclusive
    max_y: usize,

    pub const NOTHING = Rectu{
        .min_x = std.math.maxInt(usize),
        .min_y = std.math.maxInt(usize),
        .max_x = 0,
        .max_y = 0,
    };

    pub const EVERYTHING: Rectu = Rectu{
        .min_x = 0,
        .min_y = 0,
        .max_x = std.math.maxInt(usize),
        .max_y = std.math.maxInt(usize),
    };
};

pub const PrerasterizedDisc = struct {
    r: f32,
    uv: Rectu,
};

/// A pre-rasterized disc (filled circle), somewhere in the texture atlas.
pub const PreparedDisc = struct {
    /// The radius of this disc in texels.
    r: f32,
    /// Width in texels.
    w: f32,
    /// Where in the texture atlas the disc is.
    /// Normalized in 0-1 range.
    uv: Rect.T,
};
