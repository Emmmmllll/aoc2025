const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    // .challenge1 = challenge1,
    // .challenge2 = challenge2,
});

pub fn challenge1(alloc: Allocator, input: []const u8) !void {
    _ = alloc;
    _ = input;
    return error.NotImplemented;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !void {
    _ = alloc;
    _ = input;
    return error.NotImplemented;
}
