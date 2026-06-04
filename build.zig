const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Pull in the zig-astar library as a dependency. The name here must match
    // the key under `.dependencies` in build.zig.zon (added by `zig fetch`).
    const astar = b.dependency("zig_astar", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "mouse-maze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    // Expose the library to our code as `@import("astar")`.
    exe.root_module.addImport("astar", astar.module("astar"));
    b.installArtifact(exe);

    // `zig build run` builds and runs the animation.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Build and run the animated mouse maze");
    run_step.dependOn(&run_cmd.step);
}
