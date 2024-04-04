@group(0) @binding(0) var<uniform> screen_size: vec2<f32>;

struct Output {
     @builtin(position) pos: vec4<f32>,
     @location(0) color: vec4<f32>,
};

fn unpack_color(color: u32) -> vec4<f32> {
    return vec4<f32>(
        f32(color & 255u),
        f32((color >> 8u) & 255u),
        f32((color >> 16u) & 255u),
        f32((color >> 24u) & 255u),
    ) / 255.0;
}

fn position_from_screen(screen_pos: vec2<f32>) -> vec4<f32> {
    // `screen_pos` has `x` zero on the left and `y` zero at bottom.
    return vec4<f32>(
        2.0 * screen_pos.x / screen_size.x - 1.0,
        1.0 - 2.0 * screen_pos.y / screen_size.y,
        0.0,
        1.0,
    );
}

@vertex fn vertex_main(@location(0) pos: vec2<f32>, @location(2) color: u32) -> Output {
     var output: Output;
     output.pos = position_from_screen(pos);
     output.color = unpack_color(color);
     return output;
}

@fragment fn frag_main(@location(0) color: vec4<f32>) -> @location(0) vec4<f32> {
    return color;
}
