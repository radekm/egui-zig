const std = @import("std");

const Shape = @import("Shape.zig");

// from lyon_geom::quadratic_bezier.rs
// copied from https://docs.rs/lyon_geom/latest/lyon_geom/
pub const Parameters = struct {
    count: f32,
    integral_from: f32,
    integral_step: f32,
    inv_integral_from: f32,
    div_inv_integral_diff: f32,
    is_point: bool,

    // https://raphlinus.github.io/graphics/curves/2019/12/23/flatten-quadbez.html
    pub fn fromCurve(curve: Shape.QuadraticBezier, tolerance: f32) Parameters {
        // Map the quadratic bézier segment to y = x^2 parabola.
        const from = curve.points[0];
        const ctrl = curve.points[1];
        const to = curve.points[2];

        const ddx = 2.0 * ctrl[0] - from[0] - to[0];
        const ddy = 2.0 * ctrl[1] - from[1] - to[1];
        const cross = (to[0] - from[0]) * ddy - (to[1] - from[1]) * ddx;
        const inv_cross = 1.0 / cross;
        const parabola_from = ((ctrl[0] - from[0]) * ddx + (ctrl[1] - from[1]) * ddy) * inv_cross;
        const parabola_to = ((to[0] - ctrl[0]) * ddx + (to[1] - ctrl[1]) * ddy) * inv_cross;
        // Note, scale can be NaN, for example with straight lines. When it happens the NaN will
        // propagate to other parameters. We catch it all by setting the iteration count to zero
        // and leave the rest as garbage.
        const scale = @abs(cross) / (std.math.hypot(ddx, ddy) * @abs(parabola_to - parabola_from));

        const integral_from = approxParabolaIntegral(parabola_from);
        const integral_to = approxParabolaIntegral(parabola_to);
        const integral_diff = integral_to - integral_from;

        const inv_integral_from = approxParabolaInvIntegral(integral_from);
        const inv_integral_to = approxParabolaInvIntegral(integral_to);
        const div_inv_integral_diff = 1.0 / (inv_integral_to - inv_integral_from);

        // the original author thinks it can be stored as integer if it's not generic.
        // but if so, we have to handle the edge case of the integral being infinite.
        var count = @ceil(0.5 * @abs(integral_diff) * @sqrt(scale / tolerance));
        var is_point = false;
        // If count is NaN the curve can be approximated by a single straight line or a point.
        if (!std.math.isFinite(count)) {
            count = 0.0;
            is_point = std.math.hypot(to[0] - from[0], to[1] - from[1]) < tolerance * tolerance;
        }

        const integral_step = integral_diff / count;

        return .{
            .count = count,
            .integral_from = integral_from,
            .integral_step = integral_step,
            .inv_integral_from = inv_integral_from,
            .div_inv_integral_diff = div_inv_integral_diff,
            .is_point = is_point,
        };
    }

    pub fn tAtIteration(self: Parameters, iteration: f32) f32 {
        const u = approxParabolaInvIntegral(self.integral_from + self.integral_step * iteration);
        return (u - self.inv_integral_from) * self.div_inv_integral_diff;
    }
};

/// Compute an approximation to integral (1 + 4x^2) ^ -0.25 dx used in the flattening code.
fn approxParabolaIntegral(x: f32) f32 {
    const d = 0.67;
    const quarter = 0.25;
    return x / (1.0 - d + @sqrt(@sqrt(std.math.pow(f32, d, 4) + quarter * x * x)));
}

/// Approximate the inverse of the function above.
fn approxParabolaInvIntegral(x: f32) f32 {
    const b = 0.39;
    const quarter = 0.25;
    return x * (1.0 - b + @sqrt(b * b + quarter * x * x));
}
