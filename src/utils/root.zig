const std = @import("std");
const build_options = @import("build_options");
const Allocator = std.mem.Allocator;

const VoidFn = fn () anyerror!void;
const ChallengeFn = fn (Allocator, []const u8) anyerror!usize;
const BuildMainOptions = struct {
    challenge1: ?ChallengeFn = null,
    challenge2: ?ChallengeFn = null,
    input_file: []const u8 = "input",
};
pub fn buildMain(comptime options: BuildMainOptions) VoidFn {
    return struct {
        fn main() !void {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const alloc = gpa.allocator();
            const input_file_path = build_options.inputs_dir ++ .{std.fs.path.sep} ++ options.input_file;
            const input = readInputFile(alloc, input_file_path) catch |err| switch (err) {
                error.FileNotFound => {
                    std.debug.print("Input file not found: {s}\n", .{input_file_path});
                    return;
                },
                else => return err,
            };
            defer alloc.free(input);
            var out_buffer: [20]u8 = undefined;
            var out_writer = std.fs.File.stdout().writer(&out_buffer);

            if (options.challenge1) |c1| {
                var timer: ?std.time.Timer = std.time.Timer.start() catch null;
                const res = try c1(alloc, input);
                const time = if (timer) |*t| t.read() else null;
                out_writer.interface.print("Challenge 1: {d}", .{res}) catch {};
                if (time) |t| {
                    out_writer.interface.print(" ({d} ms)", .{t / std.time.ns_per_ms}) catch {};
                }
                out_writer.interface.print("\n", .{}) catch {};
                out_writer.interface.flush() catch {};
            }
            if (options.challenge2) |c2| {
                var timer: ?std.time.Timer = std.time.Timer.start() catch null;
                const res = try c2(alloc, input);
                const time = if (timer) |*t| t.read() else null;
                out_writer.interface.print("Challenge 2: {d}", .{res}) catch {};
                if (time) |t| {
                    out_writer.interface.print(" ({d} ms)", .{t / std.time.ns_per_ms}) catch {};
                }
                out_writer.interface.print("\n", .{}) catch {};
                out_writer.interface.flush() catch {};
            }
        }
    }.main;
}

fn readInputFile(allocator: Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 << 10);
}
