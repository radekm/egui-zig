const std = @import("std");
const mach = @import("mach");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mach_dep = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,
        .core = true,
    });
    const app = try mach.CoreApp.init(b, mach_dep.builder, .{
        .name = "egui-demo",
        .src = "src/demo.zig",
        .target = target,
        .optimize = optimize,
        .deps = &[_]std.Build.Module.Import{},
    });

    b.installArtifact(app.compile);

    const test_step = b.step("test", "Run unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/demo.zig" },
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
