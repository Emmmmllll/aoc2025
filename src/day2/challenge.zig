const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Id = struct {
    number: u64,

    /// An invalid ID which only contains of a pattern repeated twice.\
    /// e.g. \
    /// 11 \
    /// 22 \
    /// 333 \
    /// 1212 \
    /// 123123123
    fn contains_pattern_twice(self: Id) bool {
        var digit_buffer: [32]u8 = undefined;
        const num_digits = std.fmt.printInt(&digit_buffer, self.number, 10, .lower, .{});
        const digits = digit_buffer[0..num_digits];
        if (num_digits % 2 != 0) {
            return false;
        }
        const half = digits[0 .. num_digits / 2];
        const other_half = digits[num_digits / 2 ..];
        return std.mem.eql(u8, half, other_half);
    }

    /// An invalid ID which only consists of a repeating
    /// pattern. \
    /// e.g. \
    /// 11 \
    /// 22 \
    /// 333 \
    /// 1212 \
    /// 123123123
    fn contains_pattern_any(self: Id) bool {
        var digit_buffer: [32]u8 = undefined;
        const num_digits = std.fmt.printInt(&digit_buffer, self.number, 10, .lower, .{});
        const digits = digit_buffer[0..num_digits];

        var pattern_len: usize = 1;
        while (pattern_len <= num_digits / 2) : (pattern_len += 1) {
            const pattern = digits[0..pattern_len];
            var window_iter = std.mem.window(u8, digits[pattern_len..], pattern_len, pattern_len);
            while (window_iter.next()) |window| {
                if (!std.mem.eql(u8, window, pattern)) {
                    break;
                }
            } else return true;
        }
        return false;
    }

    pub inline fn next(self: Id) Id {
        return Id{
            .number = self.number + 1,
        };
    }
};

const Range = struct {
    start: u64,
    end: u64,

    pub fn parse(s: []const u8) !Range {
        var parts = std.mem.splitScalar(u8, s, '-');
        const part1 = parts.next() orelse return error.InvalidRangeFormat;
        const part2 = parts.next() orelse return error.InvalidRangeFormat;
        const start = try std.fmt.parseInt(u64, std.mem.trim(u8, part1, &std.ascii.whitespace), 10);
        const end = try std.fmt.parseInt(u64, std.mem.trim(u8, part2, &std.ascii.whitespace), 10);
        return Range{
            .start = start,
            .end = end,
        };
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var set = std.AutoHashMap(u64, void).init(alloc);
    defer set.deinit();
    var iter = std.mem.tokenizeAny(u8, input, ",\n\r ");
    var invalid_sum: u64 = 0;
    while (iter.next()) |field| {
        const range = try Range.parse(std.mem.trim(u8, field, &std.ascii.whitespace));
        var current_id = Id{ .number = range.start };
        while (current_id.number <= range.end) : (current_id = current_id.next()) {
            if (!set.contains(current_id.number) and current_id.contains_pattern_twice()) {
                invalid_sum += current_id.number;
                try set.put(current_id.number, {});
            }
        }
    }
    return invalid_sum;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var set = std.AutoHashMap(u64, void).init(alloc);
    defer set.deinit();
    var iter = std.mem.tokenizeAny(u8, input, ",\n\r ");
    var invalid_sum: u64 = 0;
    while (iter.next()) |field| {
        const range = try Range.parse(std.mem.trim(u8, field, &std.ascii.whitespace));
        var current_id = Id{ .number = range.start };
        while (current_id.number <= range.end) : (current_id = current_id.next()) {
            if (!set.contains(current_id.number) and current_id.contains_pattern_any()) {
                invalid_sum += current_id.number;
                try set.put(current_id.number, {});
            }
        }
    }
    return invalid_sum;
}
