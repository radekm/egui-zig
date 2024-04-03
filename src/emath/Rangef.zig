const std = @import("std");

// Inclusive range of floats, i.e. `min..=max`, but more ergonomic than [`RangeInclusive`].
pub const T = extern struct {
    min: f32,
    max: f32,

    /// The length of the range, i.e. `max - min`.
    pub fn span(self: T) f32 {
        return self.max - self.min;
    }
    /// The center of the range
    pub fn center(self: T) f32 {
        return 0.5 * (self.min + self.max);
    }
    pub fn contains(r: T, x: f32) bool {
        return r.min <= x and x <= r.max;
    }
    /// Equivalent to `x.clamp(min, max)`
    pub fn clamp(self: T, x: f32) f32 {
        return std.math.clamp(x, self.min, self.max);
    }
    /// Flip `min` and `max` if needed, so that `min <= max` after.
    pub fn asPositive(self: T) T {
        return T{ .min = @min(self.min, self.max), .max = @max(self.min, self.max) };
    }
    /// Shrink by this much on each side, keeping the center
    pub fn shrink(self: T, amnt: f32) T {
        return T{ .min = self.min + amnt, .max = self.max - amnt };
    }
    /// Expand by this much on each side, keeping the center
    pub fn expand(self: T, amnt: f32) T {
        return shrink(self, -amnt);
    }
    /// Flip the min and the max
    pub fn flip(self: T) T {
        return T{
            .min = self.max,
            .max = self.min,
        };
    }
    /// The overlap of two ranges, i.e. the range that is contained by both.
    ///
    /// If the ranges do not overlap, returns a range with `span() < 0.0`.
    ///
    /// ```
    /// # use emath::Rangef;
    /// assert_eq!(Rangef::new(0.0, 10.0).intersection(Rangef::new(5.0, 15.0)), Rangef::new(5.0, 10.0));
    /// assert_eq!(Rangef::new(0.0, 10.0).intersection(Rangef::new(10.0, 20.0)), Rangef::new(10.0, 10.0));
    /// assert!(Rangef::new(0.0, 10.0).intersection(Rangef::new(20.0, 30.0)).span() < 0.0);
    /// ```
    pub fn intersection(self: T, other: T) T {
        return T{
            .min = @max(self.min, other.min),
            .max = @min(self.max, other.max),
        };
    }
    /// Do the two ranges intersect?
    ///
    /// ```
    /// # use emath::Rangef;
    /// assert!(Rangef::new(0.0, 10.0).intersects(Rangef::new(5.0, 15.0)));
    /// assert!(Rangef::new(0.0, 10.0).intersects(Rangef::new(5.0, 6.0)));
    /// assert!(Rangef::new(0.0, 10.0).intersects(Rangef::new(10.0, 20.0)));
    /// assert!(!Rangef::new(0.0, 10.0).intersects(Rangef::new(20.0, 30.0)));
    /// ```
    pub fn intersects(self: T, other: T) bool {
        return other.min <= self.max and self.min <= other.max;
    }
};

/// Infinite range that contains everything, from -∞ to +∞, inclusive.
pub const EVERYTHING = T{
    .min = -std.math.inf(f32),
    .max = std.math.inf(f32),
};
/// The inverse of [`Self::EVERYTHING`]: stretches from positive infinity to negative infinity.
/// Contains nothing.
pub const NOTHING = T{
    .min = std.math.inf(f32),
    .max = -std.math.inf(f32),
};
/// An invalid [`Rangef`] filled with [`f32::NAN`].
pub const NAN = T{
    .min = std.math.nan(f32),
    .max = std.math.nan(f32),
};

pub fn point(min_and_max: f32) T {
    return T{ .min = min_and_max, .max = min_and_max };
}
