const std = @import("std");
const core = @import("mach").core;
const gpu = core.gpu;

const Pos2 = @import("emath/Pos2.zig");
const Rangef = @import("emath/Rangef.zig");
const Rect = @import("emath/Rect.zig");
const Rot2 = @import("emath/Rot2.zig");
const Vec2 = @import("emath/Vec2.zig");
const Vec2b = @import("emath/Vec2b.zig");

const Color = @import("epaint/Color.zig");
const Mesh = @import("epaint/Mesh.zig");
const Shape = @import("epaint/Shape.zig");
const Stroke = @import("epaint/Stroke.zig");
const Tessellator = @import("epaint/Tessellator.zig");
const Texture = @import("epaint/Texture.zig");
const TextureAtlas = @import("epaint/TextureAtlas.zig");

test "force typechecking" {
    std.testing.refAllDeclsRecursive(Pos2);
    std.testing.refAllDeclsRecursive(Rangef);
    std.testing.refAllDeclsRecursive(Rect);
    std.testing.refAllDeclsRecursive(Rot2);
    std.testing.refAllDeclsRecursive(Vec2);
    std.testing.refAllDeclsRecursive(Vec2b);

    std.testing.refAllDeclsRecursive(Color);
    std.testing.refAllDeclsRecursive(Mesh);
    std.testing.refAllDeclsRecursive(Shape);
    std.testing.refAllDeclsRecursive(Stroke);
    std.testing.refAllDeclsRecursive(Tessellator);
    std.testing.refAllDeclsRecursive(Texture);
    std.testing.refAllDeclsRecursive(TextureAtlas);
}

var vertices: []const Mesh.Vertex = &.{
    .{ .pos = .{ -0.5, -0.5 }, .uv = Mesh.WHITE_UV, .color = .{ .rgba = .{ 255, 0, 0, 255 } } }, // left bottom
    .{ .pos = .{ 0.5, -0.5 }, .uv = Mesh.WHITE_UV, .color = .{ .rgba = .{ 0, 255, 0, 255 } } }, // right bottom
    .{ .pos = .{ 0.5, 0.5 }, .uv = Mesh.WHITE_UV, .color = .{ .rgba = .{ 0, 0, 255, 255 } } }, // right top
    .{ .pos = .{ -0.5, 0.5 }, .uv = Mesh.WHITE_UV, .color = .{ .rgba = .{ 255, 255, 128, 255 } } }, // left top
    .{ .pos = .{ 0, 0.9 }, .uv = Mesh.WHITE_UV, .color = .{ .rgba = .{ 255, 255, 128, 255 } } }, // middle completely top
};
var index_data: []const u32 = &.{
    0, 1, 2,
    2, 3, 0,
    2, 3, 4,
};

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

title_timer: core.Timer,
pipeline: *gpu.RenderPipeline,
vertex_buffer: *gpu.Buffer,
index_buffer: *gpu.Buffer,

bind_group: *gpu.BindGroup,
uniform_buffer: *gpu.Buffer,

pub fn init(app: *App) !void {
    try core.init(.{});

    const shader_module = core.device.createShaderModuleWGSL("sh.wgsl", @embedFile("sh.wgsl"));
    defer shader_module.release();

    var mesh = Mesh.init(gpa.allocator(), Texture.Id.DEFAULT);
    defer mesh.deinit();
    {
        var tessellator = Tessellator.init(gpa.allocator(), 16, Tessellator.TessellationOptions.DEFAULT, [2]usize{ 10, 10 }, std.ArrayList(TextureAtlas.PreparedDisc).init(gpa.allocator()));
        defer tessellator.deinit();

        try tessellator.tessellateCircle(Shape.Circle.filled(Pos2.T{ 100, 200 }, 55, Color.Color32.RED), &mesh);
        try tessellator.tessellateCircle(Shape.Circle.stroke(Pos2.T{ 250, 200 }, 76, .{ .width = 5, .color = Color.Color32.DARK_BLUE }), &mesh);
        try tessellator.tessellateEllipse(.{
            .center = Pos2.T{ 80, 380 },
            .radius = Vec2.T{ 80, 30 },
            .fill = Color.Color32.YELLOW,
            .stroke = .{ .width = 5, .color = Color.Color32.GREEN },
        }, &mesh);
    }
    vertices = mesh.vertices.items;
    index_data = mesh.indices.items;

    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x2, .offset = @offsetOf(Mesh.Vertex, "pos"), .shader_location = 0 },
        .{ .format = .float32x2, .offset = @offsetOf(Mesh.Vertex, "uv"), .shader_location = 1 },
        .{ .format = .uint32, .offset = @offsetOf(Mesh.Vertex, "color"), .shader_location = 2 },
    };
    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Mesh.Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &.{},
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const bind_group_layout = core.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{gpu.BindGroupLayout.Entry.buffer(
            0,
            .{ .vertex = true },
            .uniform,
            false,
            @sizeOf(Vec2.T),
        )},
    }));
    defer bind_group_layout.release();

    const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &.{bind_group_layout},
    }));
    defer pipeline_layout.release();

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex_main",
            .buffers = &.{vertex_buffer_layout},
        }),
        .primitive = .{ .cull_mode = .none },
    };

    const vertex_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true },
        .size = @sizeOf(Mesh.Vertex) * vertices.len,
        .mapped_at_creation = .true,
    });
    const vertex_mapped = vertex_buffer.getMappedRange(Mesh.Vertex, 0, vertices.len);
    @memcpy(vertex_mapped.?, vertices[0..]);
    vertex_buffer.unmap();

    const index_buffer = core.device.createBuffer(&.{
        .usage = .{ .index = true },
        .size = @sizeOf(u32) * index_data.len,
        .mapped_at_creation = .true,
    });
    const index_mapped = index_buffer.getMappedRange(u32, 0, index_data.len);
    @memcpy(index_mapped.?, index_data[0..]);
    index_buffer.unmap();

    const uniform_buffer = core.device.createBuffer(&.{
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(Vec2.T),
        .mapped_at_creation = .false,
    });

    const bind_group_descriptor = gpu.BindGroup.Descriptor.init(.{
        .layout = bind_group_layout,
        .entries = &.{
            gpu.BindGroup.Entry.buffer(
                0,
                uniform_buffer,
                0,
                @sizeOf(Vec2.T),
            ),
        },
    });

    app.title_timer = try core.Timer.start();
    app.pipeline = core.device.createRenderPipeline(&pipeline_descriptor);
    app.bind_group = core.device.createBindGroup(&bind_group_descriptor);
    app.vertex_buffer = vertex_buffer;
    app.index_buffer = index_buffer;
    app.uniform_buffer = uniform_buffer;
}

pub fn deinit(app: *App) void {
    app.uniform_buffer.release();
    app.vertex_buffer.release();
    app.index_buffer.release();
    app.pipeline.release();
    core.deinit();
    _ = gpa.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| if (event == .close) return true;

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const encoder = core.device.createCommandEncoder(null);
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = .{ .r = 0, .g = 0.7, .b = 0.7, .a = 1 },
        .load_op = .clear,
        .store_op = .store,
    };
    const render_pass_info = gpu.RenderPassDescriptor.init(.{ .color_attachments = &.{color_attachment} });

    const window_size: [2]f32 = Vec2.T{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    encoder.writeBuffer(app.uniform_buffer, 0, &window_size);

    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.setVertexBuffer(0, app.vertex_buffer, 0, @sizeOf(Mesh.Vertex) * vertices.len);
    pass.setIndexBuffer(app.index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
    pass.setBindGroup(0, app.bind_group, null);
    pass.drawIndexed(@intCast(index_data.len), 1, 0, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();
    core.queue.submit(&.{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("RGB Quad [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}
