const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Id = struct {
    num: u64,

    pub fn parse(s: []const u8) !Id {
        const num = std.fmt.parseInt(u64, s, 10) catch
            return error.InvalidId;
        return Id{ .num = num };
    }
};

const IdRange = struct {
    start: Id,
    end: Id,

    pub fn parse(s: []const u8) !IdRange {
        var splitter = std.mem.splitAny(u8, s, "-");
        const start = try Id.parse(splitter.next() orelse return error.InvalidIdRange);
        const end = try Id.parse(splitter.next() orelse return error.InvalidIdRange);
        return IdRange{ .start = start, .end = end };
    }

    pub fn containsId(self: IdRange, id: Id) bool {
        return self.start.num <= id.num and self.end.num >= id.num;
    }

    pub fn merge(self: IdRange, other: IdRange) ?IdRange {
        if (!self.containsId(other.start) and !self.containsId(other.end) and !other.containsId(self.start) and !other.containsId(self.end)) {
            return null;
        }
        const new_start = @min(self.start.num, other.start.num);
        const new_end = @max(self.end.num, other.end.num);
        return IdRange{ .start = .{ .num = new_start }, .end = .{ .num = new_end } };
    }

    pub fn format(self: IdRange, writer: *std.Io.Writer) !void {
        try writer.print("{d}-{d}", .{ self.start.num, self.end.num });
    }
};

fn parseRanges(alloc: Allocator, input: []const u8) !struct { []IdRange, []const u8 } {
    var ranges = std.array_list.Managed(IdRange).init(alloc);
    defer ranges.deinit();
    var lineiter = std.mem.splitAny(u8, input, "\n");
    while (lineiter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) break;
        const range = try IdRange.parse(trimmed);
        try ranges.append(range);
    }
    return .{ try ranges.toOwnedSlice(), lineiter.rest() };
}

fn mergeRanges(range_list: *std.ArrayList(IdRange)) bool {
    std.mem.sort(IdRange, range_list.items, {}, struct {
        fn lessThan(_: void, a: IdRange, b: IdRange) bool {
            return a.end.num < b.end.num;
        }
    }.lessThan);
    // go backwards so, we can safely remove items
    var i = range_list.items.len;
    var has_merged = false;
    while (i > 1) {
        i -= 1;
        const merged = range_list.items[i].merge(range_list.items[i - 1]) orelse continue;
        _ = range_list.orderedRemove(i);
        range_list.items[i - 1] = merged;
        has_merged = true;
    }
    return has_merged;
}

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    const ranges, const remaining = try parseRanges(alloc, input);
    defer alloc.free(ranges);
    var lineiter = std.mem.splitAny(u8, remaining, "\n");
    var fresh_count: usize = 0;
    while (lineiter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) break;
        const id = try Id.parse(trimmed);
        for (ranges) |range| {
            if (range.containsId(id)) {
                fresh_count += 1;
                break;
            }
        }
    }
    return fresh_count;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    const ranges, _ = try parseRanges(alloc, input);
    defer alloc.free(ranges);
    var range_list = std.ArrayList(IdRange){
        .items = ranges,
        .capacity = ranges.len,
    };
    // go backwards so, we can safely remove items
    _ = mergeRanges(&range_list);

    var id_count: usize = 0;
    for (range_list.items) |range| {
        id_count += @as(usize, @intCast(range.end.num - range.start.num)) + 1;
    }
    return id_count;
}
