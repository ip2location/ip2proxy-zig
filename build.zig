const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ip2proxy = b.addModule("ip2proxy", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run the unit and database tests");

    const unit_tests = b.addTest(.{ .root_module = ip2proxy });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const db_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("test/database.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "ip2proxy", .module = ip2proxy }},
    }) });
    test_step.dependOn(&b.addRunArtifact(db_tests).step);

    const example_step = b.step("example", "Build the example program into zig-out/bin");
    const lookup = b.addExecutable(.{
        .name = "lookup",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example/lookup.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "ip2proxy", .module = ip2proxy }},
        }),
    });
    example_step.dependOn(&b.addInstallArtifact(lookup, .{}).step);
}
