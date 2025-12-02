const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const day = b.option(
        usize,
        "ay",
        "Specify the day number",
    ) orelse @panic("No day selected. Select a day with -Day=<number>");

    const day_dir_name = std.fmt.allocPrint(
        b.allocator,
        "day{}",
        .{day},
    ) catch @panic("OOM");

    const path = std.fs.path.join(
        b.allocator,
        &.{ "src", day_dir_name, "challenge.zig" },
    ) catch @panic("OOM");

    const inputs_dir = std.fs.path.join(
        b.allocator,
        &.{ "inputs", day_dir_name },
    ) catch @panic("OOM");

    const utils_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{
            .name = "utils",
            .module = utils_mod,
        }},
    });

    const options = b.addOptions();
    options.addOption([]const u8, "inputs_dir", inputs_dir);
    mod.addOptions("build_options", options);
    utils_mod.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .root_module = mod,
        .name = "challenge",
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "run the executable");
    run_step.dependOn(&run.step);
}
