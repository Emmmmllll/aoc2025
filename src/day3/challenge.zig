const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Bank = struct {
    pub fn find_max(input: []const u8, start: usize) usize {
        std.debug.assert(input.len > 0);
        std.debug.assert(start < input.len);
        var max: u8 = 0;
        var max_index: usize = 0;

        for (input[start..], start..) |char, i| {
            if (char > max) {
                max = char;
                max_index = i;
            }
        }
        return max_index;
    }

    pub fn max_two_component_joltage(input: []const u8) usize {
        var first_max_index = Bank.find_max(input, 0);
        var second_max_index: usize = undefined;
        if (first_max_index == input.len - 1) {
            second_max_index = first_max_index;
            first_max_index = Bank.find_max(input[0..first_max_index], 0);
        } else {
            second_max_index = Bank.find_max(input, first_max_index + 1);
        }

        const first_val = input[first_max_index] - '0';
        const second_val = input[second_max_index] - '0';
        return first_val * 10 + second_val;
    }

    pub fn max_twelve_component_joltage(input: []const u8) usize {
        var indices: [12]usize = undefined;

        var last_index: ?usize = null;
        for (&indices, 0..) |*index, i| {
            const found_index = Bank.find_max(
                input[0 .. input.len - indices.len + i + 1],
                if (last_index) |li| li + 1 else 0,
            );
            last_index = found_index;
            index.* = found_index;
        }

        var val: usize = 0;
        for (indices) |index| {
            val = val * 10 + (input[index] - '0');
        }
        return val;
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    _ = alloc;
    var line_iter = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
    var sum: usize = 0;
    while (line_iter.next()) |line| {
        const result = Bank.max_two_component_joltage(line);
        sum += result;
    }
    return sum;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    _ = alloc;
    var line_iter = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
    var sum: usize = 0;
    while (line_iter.next()) |line| {
        const result = Bank.max_twelve_component_joltage(line);
        sum += result;
    }
    return sum;
}
