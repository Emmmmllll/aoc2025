const std = @import("std");
const build_options = @import("build_options");
const Allocator = std.mem.Allocator;

const VoidFn = fn () anyerror!void;
const MainFn = fn (Allocator, []const u8) anyerror!void;
const BuildMainOptions = struct {
    challenge1: ?MainFn = null,
    challenge2: ?MainFn = null,
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
            if (options.challenge1) |c1|
                try c1(alloc, input);
            if (options.challenge2) |c2|
                try c2(alloc, input);
        }
    }.main;
}

fn readInputFile(allocator: Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 << 10);
}
