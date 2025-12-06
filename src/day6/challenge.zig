const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
    // .input_file = "testinput",
});

const Operation = enum(u8) {
    add = '+',
    mul = '*',

    pub fn fromChar(c: u8) !Operation {
        return switch (c) {
            '+' => Operation.add,
            '*' => Operation.mul,
            else => return error.InvalidOperation,
        };
    }

    pub fn parse(s: []const u8) !Operation {
        if (s.len != 1) {
            return error.InvalidOperation;
        }
        return Operation.fromChar(s[0]);
    }
};

const Problem = struct {
    numbers: []u32,
    operation: Operation,

    pub fn compute(self: *const Problem) u64 {
        switch (self.operation) {
            .add => {
                var sum: u64 = 0;
                for (self.numbers) |num| {
                    sum += @intCast(num);
                }
                return sum;
            },
            .mul => {
                var product: u64 = 1;
                for (self.numbers) |num| {
                    product *= @intCast(num);
                }
                return product;
            },
        }
    }
};

const Problems = struct {
    problems: []Problem,

    fn parseL2R(alloc: Allocator, input: []const u8) !Problems {
        const problem_number_count, const last_line = countNumberLines(input);
        const problems = try parseOperationLine(last_line, alloc);
        errdefer alloc.free(problems);

        const numbers_buffer = try allocL2RNumberBuffer(alloc, problems, problem_number_count);
        errdefer alloc.free(numbers_buffer);

        try parseL2RNumbers(problems, input, problem_number_count);
        return Problems{ .problems = problems };
    }

    fn parseT2B(alloc: Allocator, input: []const u8) !Problems {
        const number_lines_count, const last_line = countNumberLines(input);
        const problems = try parseOperationLine(last_line, alloc);
        errdefer alloc.free(problems);

        const numbers_buffer = try allocT2BNumberBuffer(alloc, problems, input, number_lines_count);
        errdefer alloc.free(numbers_buffer);

        try parseT2BNumbers(problems, input, number_lines_count);
        return Problems{ .problems = problems };
    }

    fn countNumberLines(input: []const u8) struct { usize, []const u8 } {
        var count: usize = 0;
        var last_line: []const u8 = &[_]u8{};
        var line_iter = lineIter(input);
        while (line_iter.next()) |line| {
            count += 1;
            last_line = line;
        }
        return .{ count - 1, last_line };
    }

    fn parseOperationLine(operation_line: []const u8, alloc: Allocator) ![]Problem {
        var col_iter = colIter(operation_line);
        var problem_count: usize = 0;
        while (col_iter.next()) |_| {
            problem_count += 1;
        }
        const problems = try alloc.alloc(Problem, problem_count);
        errdefer alloc.free(problems);

        col_iter = colIter(operation_line);
        for (problems) |*problem| {
            const op_str = col_iter.next() orelse return error.MissingOperation;
            problem.operation = try Operation.parse(op_str);
        }
        return problems;
    }

    fn allocL2RNumberBuffer(alloc: Allocator, problems: []Problem, problem_number_count: usize) ![]u32 {
        if (problems.len == 0) return &[_]u32{};
        const total_numbers = problems.len * problem_number_count;
        const buffer = try alloc.alloc(u32, total_numbers);
        var rest = buffer;
        for (problems) |*problem| {
            problem.numbers = rest[0..problem_number_count];
            rest = rest[problem_number_count..];
        }
        return buffer;
    }

    fn allocT2BNumberBuffer(alloc: Allocator, problems: []Problem, input: []const u8, number_lines_count: usize) ![]u32 {
        if (problems.len == 0) return &[_]u32{};
        var line_iter = lineIter(input);

        for (problems) |*problem| {
            problem.numbers = &[_]u32{};
        }

        for (0..number_lines_count) |_| {
            const line = line_iter.next().?;
            var col_iter = colIter(line);
            for (problems) |*problem| {
                const item = col_iter.next() orelse return error.MissingNumber;
                problem.numbers.len = @max(problem.numbers.len, item.len);
            }
        }

        var total_numbers: usize = 0;
        for (problems) |problem| {
            total_numbers += problem.numbers.len;
        }
        const buffer = try alloc.alloc(u32, total_numbers);
        @memset(buffer, 0);
        var rest = buffer;
        for (problems) |*problem| {
            problem.numbers.ptr = rest.ptr;
            rest = rest[problem.numbers.len..];
        }
        return buffer;
    }

    fn parseL2RNumbers(problems: []Problem, input: []const u8, number_lines_count: usize) !void {
        var line_iter = lineIter(input);
        for (0..number_lines_count) |i| {
            const line = line_iter.next().?;
            var col_iter = colIter(line);
            for (problems) |*problem| {
                const num_str = col_iter.next() orelse return error.MissingNumber;
                const num = try std.fmt.parseInt(u32, num_str, 10);
                problem.numbers[i] = num;
            }
        }
    }

    fn parseT2BNumbers(problems: []Problem, input: []const u8, number_lines_count: usize) !void {
        var line_iter = lineIter(input);
        for (0..number_lines_count) |_| {
            var line = line_iter.next().?;
            for (problems) |*problem| {
                const digits = line[0..problem.numbers.len];
                line = line[@min(problem.numbers.len + 1, line.len)..];
                for (digits, 0..) |digit, idx| {
                    switch (digit) {
                        '0'...'9' => {
                            const val = digit - '0';
                            problem.numbers[idx] *= 10;
                            problem.numbers[idx] += @intCast(val);
                        },
                        ' ' => {},
                        else => return error.InvalidNumberCharacter,
                    }
                }
            }
        }
    }

    fn lineIter(input: []const u8) std.mem.TokenIterator(u8, .any) {
        return std.mem.tokenizeAny(u8, input, "\r\n");
    }

    fn colIter(line: []const u8) std.mem.TokenIterator(u8, .any) {
        return std.mem.tokenizeAny(u8, std.mem.trim(u8, line, &std.ascii.whitespace), " ");
    }

    fn getNumberBuffer(problems: []Problem) []u32 {
        if (problems.len == 0) return &[_]u32{};
        var total_numbers: usize = 0;
        for (problems) |problem| {
            total_numbers += problem.numbers.len;
        }
        return problems[0].numbers.ptr[0..total_numbers];
    }

    pub fn deinit(self: *const Problems, alloc: Allocator) void {
        alloc.free(getNumberBuffer(self.problems));
        alloc.free(self.problems);
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var problems = try Problems.parseL2R(alloc, input);
    defer problems.deinit(alloc);
    var sum: u64 = 0;
    for (problems.problems) |problem| {
        sum += problem.compute();
    }
    return sum;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var problems = try Problems.parseT2B(alloc, input);
    defer problems.deinit(alloc);
    var sum: u64 = 0;
    for (problems.problems) |problem| {
        sum += problem.compute();
    }
    return sum;
}
