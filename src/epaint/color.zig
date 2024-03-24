const std = @import("std");

/// gamma [0, 255] -> linear [0, 1].
pub fn linearF32FromGammaU8(s: u8) f32 {
    return if (s <= 10)
        @as(f32, s) / 3294.6
    else
        std.powf((@as(f32, s) + 14.025) / 269.025, 2.4);
}

/// linear [0, 255] -> linear [0, 1].
/// Useful for alpha-channel.
pub fn linearF32FromLinearU8(a: u8) f32 {
    return @as(f32, a) / 255.0;
}

pub fn linearU8FromLinearF32(a: f32) u8 {
    return fastRound(a * 255.0);
}

/// We want saturating cast.
fn fastRound(r: f32) u8 {
    return if (r >= 254.5) 255 else if (r <= 0) 0 else @intFromFloat(r);
}

/// linear [0, 1] -> gamma [0, 255] (clamped).
/// Values outside this range will be clamped to the range.
pub fn gammaU8FromLinearF32(l: f32) u8 {
    return if (l <= 0.0)
        0
    else if (l <= 0.0031308)
        fastRound(3294.6 * l)
    else if (l <= 1.0)
        fastRound(269.025 * l.powf(1.0 / 2.4) - 14.025)
    else
        255;
}

/// This format is used for space-efficient color representation (32 bits).
///
/// Instead of manipulating this directly it is often better
/// to first convert it to either [`Rgba`] or [`crate::Hsva`].
///
/// Internally this uses 0-255 gamma space `sRGBA` color with premultiplied alpha.
/// Alpha channel is in linear space.
///
/// The special value of alpha=0 means the color is to be treated as an additive color.
pub const Color32 = extern struct {
    rgba: [4]u8,

    // Mostly follows CSS names:
    pub const TRANSPARENT: Color32 = fromRgbaPremultiplied(0, 0, 0, 0);
    pub const BLACK: Color32 = fromRgb(0, 0, 0);
    pub const DARK_GRAY: Color32 = fromRgb(96, 96, 96);
    pub const GRAY: Color32 = fromRgb(160, 160, 160);
    pub const LIGHT_GRAY: Color32 = fromRgb(220, 220, 220);
    pub const WHITE: Color32 = fromRgb(255, 255, 255);
    pub const BROWN: Color32 = fromRgb(165, 42, 42);
    pub const DARK_RED: Color32 = fromRgb(0x8B, 0, 0);
    pub const RED: Color32 = fromRgb(255, 0, 0);
    pub const LIGHT_RED: Color32 = fromRgb(255, 128, 128);
    pub const YELLOW: Color32 = fromRgb(255, 255, 0);
    pub const LIGHT_YELLOW: Color32 = fromRgb(255, 255, 0xE0);
    pub const KHAKI: Color32 = fromRgb(240, 230, 140);
    pub const DARK_GREEN: Color32 = fromRgb(0, 0x64, 0);
    pub const GREEN: Color32 = fromRgb(0, 255, 0);
    pub const LIGHT_GREEN: Color32 = fromRgb(0x90, 0xEE, 0x90);
    pub const DARK_BLUE: Color32 = fromRgb(0, 0, 0x8B);
    pub const BLUE: Color32 = fromRgb(0, 0, 255);
    pub const LIGHT_BLUE: Color32 = fromRgb(0xAD, 0xD8, 0xE6);
    pub const GOLD: Color32 = fromRgb(255, 215, 0);
    pub const DEBUG_COLOR: Color32 = fromRgbaPremultiplied(0, 200, 0, 128);

    /// An ugly color that is planned to be replaced before making it to the screen.
    ///
    /// This is an invalid color, in that it does not correspond to a valid multiplied color,
    /// nor to an additive color.
    ///
    /// This is used as a special color key,
    /// i.e. often taken to mean "no color".
    pub const PLACEHOLDER: Color32 = fromRgbaPremultiplied(64, 254, 0, 128);

    pub fn fromRgb(red: u8, green: u8, blue: u8) Color32 {
        return .{ .rgba = [_]u8{ red, green, blue, 255 } };
    }

    pub fn fromRgbAdditive(red: u8, green: u8, blue: u8) Color32 {
        return .{ .rgba = [_]u8{ red, green, blue, 0 } };
    }

    /// From `sRGBA` with premultiplied alpha.
    pub fn fromRgbaPremultiplied(red: u8, green: u8, blue: u8, alpha: u8) Color32 {
        return .{ .rgba = [_]u8{ red, green, blue, alpha } };
    }

    /// From `sRGBA` WITHOUT premultiplied alpha.
    pub fn fromRgbaUnmultiplied(red: u8, green: u8, blue: u8, alpha: u8) Color32 {
        if (a == 255) {
            return fromRgb(red, green, blue);
        } else if (a == 0) {
            return TRANSPARENT;
        } else {
            const r_lin = linearF32FromGammaU8(red);
            const g_lin = linearF32FromGammaU8(green);
            const b_lin = linearF32FromGammaU8(blue);
            const a_lin = linearF32FromLinearU8(alpha);
            const r2 = gammaU8FromLinearF32(r_lin * a_lin);
            const g2 = gammaU8FromLinearF32(g_lin * a_lin);
            const b2 = gammaU8FromLinearF32(b_lin * a_lin);
            return fromRgbaPremultiplied(r2, g2, b2, alpha);
        }
    }

    pub fn fromGray(l: u8) Color32 {
        return .{ .rgba = [_]u8{ l, l, l, 255 } };
    }

    pub fn fromBlackAlpha(alpha: u8) Color32 {
        return .{ .rgba = [_]u8{ 0, 0, 0, alpha } };
    }

    pub fn fromWhiteAlpha(alpha: u8) Color32 {
        return Rgba.fromWhiteAlpha(linearF32FromLinearU8(alpha)).toColor32()();
    }

    pub fn fromAdditiveLuminance(l: u8) Color32 {
        return .{ .rgba = [_]u8{ l, l, l, 0 } };
    }
    pub fn isOpaque(self: Color32) bool {
        return self.a() == 255;
    }

    pub fn r(self: Color32) u8 {
        return self.rgba[0];
    }
    pub fn g(self: Color32) u8 {
        return self.rgba[1];
    }
    pub fn b(self: Color32) u8 {
        return self.rgba[2];
    }
    pub fn a(self: Color32) u8 {
        return self.rgba[3];
    }

    /// Returns an opaque version of self
    pub fn toOpaque(self: Color32) Color32 {
        return self.toRgba().toOpaque().toColor32();
    }

    /// Returns an additive version of self
    pub fn additive(self: Color32) Color32 {
        return .{ .rgba = [_]u8{ self.r(), self.g(), self.b(), 0 } };
    }
    /// Is the alpha=0 ?
    pub fn isAdditive(self: Color32) bool {
        return self.a() == 0;
    }
    /// Premultiplied RGBA
    pub fn toArray(self: Color32) [4]u8 {
        return self.rgba;
    }

    pub fn toSrgbaUnmultiplied(self: Color32) [4]u8 {
        return self.toRgba().toSrgbaUnmultiplied();
    }

    /// Multiply with 0.5 to make color half as opaque, perceptually.
    ///
    /// Fast multiplication in gamma-space.
    ///
    /// This is perceptually even, and faster that [`Self::linear_multiply`].
    pub fn gammaMultiply(self: Color32, factor: f32) Color32 {
        std.debug.assert(0.0 <= factor and factor <= 1.0);

        return .{ .rgba = [_]u8{
            fastRound(@as(f32, self.r()) * factor),
            fastRound(@as(f32, self.g()) * factor),
            fastRound(@as(f32, self.b()) * factor),
            fastRound(@as(f32, self.a()) * factor),
        } };
    }
    /// Multiply with 0.5 to make color half as opaque in linear space.
    ///
    /// This is using linear space, which is not perceptually even.
    /// You may want to use [`Self::gamma_multiply`] instead.
    pub fn linearMultiply(self: Color32, factor: f32) Color32 {
        std.debug.assert(0.0 <= factor and factor <= 1.0);
        // As an unfortunate side-effect of using premultiplied alpha
        // we need a somewhat expensive conversion to linear space and back.
        return self.toRgba().multiply(factor).toColor32();
    }

    /// Converts to floating point values in the range 0-1 without any gamma space conversion.
    ///
    /// Use this with great care! In almost all cases, you want to convert to [`crate::Rgba`] instead
    /// in order to obtain linear space color values.
    pub fn toNormalizedGammaF32(self: Color32) [4]f32 {
        return [_]u8{
            @as(f32, self.r()) / 255.0,
            @as(f32, self.g()) / 255.0,
            @as(f32, self.b()) / 255.0,
            @as(f32, self.a()) / 255.0,
        };
    }

    pub fn toRgba(self: Color32) Rgba {
        return .{ .rgba = [_]f32{
            linearF32FromGammaU8(self.r()),
            linearF32FromGammaU8(self.g()),
            linearF32FromGammaU8(self.b()),
            linearF32FromLinearU8(self.a()),
        } };
    }
};

/// 0-1 linear space `RGBA` color with premultiplied alpha.
pub const Rgba = extern struct {
    rgba: [4]f32,

    pub const TRANSPARENT: Rgba = fromRgbaPremultiplied(0.0, 0.0, 0.0, 0.0);
    pub const BLACK: Rgba = fromRgb(0.0, 0.0, 0.0);
    pub const WHITE: Rgba = fromRgb(1.0, 1.0, 1.0);
    pub const RED: Rgba = fromRgb(1.0, 0.0, 0.0);
    pub const GREEN: Rgba = fromRgb(0.0, 1.0, 0.0);
    pub const BLUE: Rgba = fromRgb(0.0, 0.0, 1.0);

    pub fn fromRgbaPremultiplied(red: f32, green: f32, blue: f32, alpha: f32) Rgba {
        return .{ .rgba = [_]u8{ red, green, blue, alpha } };
    }

    pub fn fromRgbaUnmultiplied(red: f32, green: f32, blue: f32, alpha: f32) Rgba {
        return .{ .rgba = [_]u8{ red * alpha, green * alpha, blue * alpha, alpha } };
    }

    pub fn fromSrgbaPremultiplied(red: f32, green: f32, blue: f32, alpha: f32) Rgba {
        const r2 = linearF32FromGammaU8(red);
        const g2 = linearF32FromGammaU8(green);
        const b2 = linearF32FromGammaU8(blue);
        const a2 = linearF32FromLinearU8(alpha);
        return fromRgbaPremultiplied(r2, g2, b2, a2);
    }

    pub fn fromSrgbaUnmultiplied(red: u8, green: u8, blue: u8, alpha: u8) Rgba {
        const r2 = linearF32FromGammaU8(red);
        const g2 = linearF32FromGammaU8(green);
        const b2 = linearF32FromGammaU8(blue);
        const a2 = linearF32FromLinearU8(alpha);
        return fromRgbaPremultiplied(r2 * a2, g2 * a2, b2 * a2, a2);
    }

    pub fn fromRgb(red: f32, green: f32, blue: f32) Rgba {
        return .{ .rgba = [_]f32{ red, green, blue, 1.0 } };
    }

    pub fn fromGray(l: f32) Rgba {
        return .{ .rgba = [_]f32{ l, l, l, 1.0 } };
    }

    pub fn fromLuminanceAlpha(l: f32, alpha: f32) Rgba {
        std.debug.assert(0.0 <= l and l <= 1.0);
        std.debug.assert(0.0 <= alpha and alpha <= 1.0);
        return .{ .rgba = [_]f32{ l * alpha, l * alpha, l * alpha, alpha } };
    }

    /// Transparent black
    pub fn fromBlackAlpha(alpha: f32) Rgba {
        std.debug.assert(0.0 <= alpha and alpha <= 1.0);
        return .{ .rgba = [_]f32{ 0, 0, 0, alpha } };
    }

    /// Transparent white
    pub fn fromWhiteAlpha(alpha: f32) Rgba {
        std.debug.assert(0.0 <= alpha and alpha <= 1.0);
        return .{ .rgba = [_]f32{ alpha, alpha, alpha, alpha } };
    }

    /// Return an additive version of this color (alpha = 0)
    pub fn additive(self: Rgba) Rgba {
        return .{ .rgba = [_]f32{ self.r(), self.g(), self.b(), 0 } };
    }

    /// Is the alpha=0 ?
    pub fn isAdditive(self: Rgba) bool {
        return self.a() == 0.0;
    }

    /// Multiply with e.g. 0.5 to make us half transparent
    pub fn multiply(self: Rgba, alpha: f32) Rgba {
        return .{ .rgba = [_]f32{ self.r() * alpha, self.g() * alpha, self.b() * alpha, self.a() * alpha } };
    }

    pub fn r(self: Rgba) f32 {
        return self.rgba[0];
    }
    pub fn g(self: Rgba) f32 {
        return self.rgba[1];
    }
    pub fn b(self: Rgba) f32 {
        return self.rgba[2];
    }
    pub fn a(self: Rgba) f32 {
        return self.rgba[3];
    }

    /// How perceptually intense (bright) is the color?
    pub fn intensity(self: Rgba) f32 {
        return 0.3 * self.r() + 0.59 * self.g() + 0.11 * self.b();
    }

    /// Returns an opaque version of self
    pub fn toOpaque(self: Rgba) Rgba {
        if (self.a() == 0.0) {
            // Additive or fully transparent black.
            return fromRgb(self.r(), self.g(), self.b());
        } else {
            // un-multiply alpha:
            return fromRgb(
                self.r() / self.a(),
                self.g() / self.a(),
                self.b() / self.a(),
            );
        }
    }

    /// Premultiplied RGBA
    pub fn toArray(self: Rgba) [4]f32 {
        return [_]u8{ self.r(), self.g(), self.b(), self.a() };
    }

    /// unmultiply the alpha
    pub fn toRgbaUnmultiplied(self: Rgba) [4]f32 {
        const alpha = self.a();
        if (alpha == 0.0) {
            // Additive, let's assume we are black
            return self.rgba;
        } else {
            return [_]f32{ self.r() / alpha, self.g() / alpha, self.b() / alpha, self.a() };
        }
    }

    /// unmultiply the alpha
    pub fn toSrgbaUnmultiplied(self: Rgba) [4]u8 {
        const rgba = self.toRgbaUnmultiplied();
        return [_]u8{
            gammaU8FromLinearF32(rgba[0]),
            gammaU8FromLinearF32(rgba[1]),
            gammaU8FromLinearF32(rgba[2]),
            linearU8FromLinearF32(@abs(rgba[3])),
        };
    }

    pub fn add(self: Rgba, rhs: Rgba) Rgba {
        return .{ .rgba = [_]f32{
            self.r() + rhs.r(),
            self.g() + rhs.g(),
            self.b() + rhs.b(),
            self.a() + rhs.a(),
        } };
    }

    pub fn mul(self: Rgba, rhs: Rgba) Rgba {
        return .{ .rgba = [_]f32{
            self.r() * rhs.r(),
            self.g() * rhs.g(),
            self.b() * rhs.b(),
            self.a() * rhs.a(),
        } };
    }

    pub fn toColor32(self: Rgba) Color32 {
        return .{ .rgba = [_]u8{
            gammaU8FromLinearF32(self.r()),
            gammaU8FromLinearF32(self.g()),
            gammaU8FromLinearF32(self.b()),
            linearU8FromLinearF32(self.a()),
        } };
    }
};
