const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    // .challenge1 = challenge1,
    .challenge2 = challenge2,
    // .input_file = "testinput",
});

const MachineLightManual = struct {
    data_ptr: [*]const u8,
    target_len: usize,
    button_count: usize,

    fn getTarget(self: MachineLightManual) []const LightStatus {
        return @ptrCast(self.data_ptr[0..self.target_len]);
    }

    fn getButton(self: MachineLightManual, i: usize) Button {
        return Button{
            .affected_lights = @ptrCast(self.data_ptr[self.target_len * (i + 1) ..][0..self.target_len]),
        };
    }

    pub fn parse(alloc: Allocator, input: []const u8) !MachineLightManual {
        var splitter = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
        const lights_part = splitter.next() orelse return error.InvalidInput;
        if (lights_part[0] != '[' or lights_part[lights_part.len - 1] != ']') {
            return error.InvalidInput;
        }
        const lights = lights_part[1 .. lights_part.len - 1];
        const button_count = try countButtons(splitter);
        const data_buf = try alloc.alloc(u8, lights.len * (button_count + 1));
        errdefer alloc.free(data_buf);
        @memcpy(data_buf[0..lights.len], lights);
        var rest = data_buf[lights.len..];

        for (0..button_count) |_| {
            const button_part = splitter.next() orelse return error.InvalidInput;
            var button_light_iter = std.mem.splitScalar(u8, button_part[1 .. button_part.len - 1], ',');
            const button_lights: []LightStatus = @ptrCast(rest[0..lights.len]);
            rest = rest[lights.len..];
            @memset(button_lights, .off);
            while (button_light_iter.next()) |token| {
                const light_idx = try std.fmt.parseInt(usize, token, 10);
                if (light_idx >= lights.len) {
                    return error.InvalidInput;
                }
                button_lights[light_idx] = .on;
            }
        }

        return MachineLightManual{
            .data_ptr = data_buf.ptr,
            .target_len = lights.len,
            .button_count = button_count,
        };
    }

    fn countButtons(splitter: std.mem.TokenIterator(u8, .any)) !usize {
        var iter = splitter;
        var count: usize = 0;
        while (iter.next()) |token| {
            if (token[0] == '{' and token[token.len - 1] == '}') {
                return count;
            }
            if (token[0] != '(' or token[token.len - 1] != ')') {
                return error.InvalidInput;
            }
            count += 1;
        }
        return error.InvalidInput;
    }

    pub fn deinit(self: *const MachineLightManual, alloc: Allocator) void {
        alloc.free(self.data_ptr[0 .. self.target_len * (self.button_count + 1)]);
    }

    pub fn newMachine(self: *const MachineLightManual, alloc: Allocator) !MachineLights {
        const lights_buf = try alloc.alloc(LightStatus, self.target_len);
        @memset(lights_buf, .off);
        return MachineLights{
            .lights = lights_buf,
        };
    }
};

const LightStatus = enum(u8) {
    off = '.',
    on = '#',
    pub fn toggle(self: LightStatus) LightStatus {
        return switch (self) {
            .off => .on,
            .on => .off,
        };
    }
};

const Button = struct {
    affected_lights: []const LightStatus,
    pub fn apply(self: *const Button, lights: []LightStatus) void {
        for (self.affected_lights, lights) |affected, *light| {
            if (affected == .off) continue;
            light.* = light.toggle();
        }
    }
};

const MachineJoltageManual = struct {
    data_ptr: [*]const u32,
    target_len: usize,
    button_count: usize,

    pub fn parse(alloc: Allocator, input: []const u8) !MachineJoltageManual {
        var splitter = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
        _ = splitter.next();
        const button_count, const button_value_count, const target_len = try countButtonsAndRequirements(splitter);
        const data_buf = try alloc.alloc(u32, target_len + button_count * 2 + button_value_count);
        errdefer alloc.free(data_buf);
        var rest = data_buf[target_len..];
        var button_index: usize = target_len + button_count * 2;

        for (0..button_count) |_| {
            const button_part = splitter.next() orelse return error.InvalidInput;
            var button_light_iter = std.mem.splitScalar(u8, button_part[1 .. button_part.len - 1], ',');
            rest[0] = @intCast(button_index);
            var value_count: usize = 0;
            while (button_light_iter.next()) |token| : ({
                button_index += 1;
                value_count += 1;
            }) {
                const index = try std.fmt.parseInt(u32, token, 10);
                data_buf[button_index] = index;
            }
            rest[1] = @intCast(value_count);
            rest = rest[2..];
        }

        const reqs_input = splitter.next() orelse return error.InvalidInput;
        var req_splitter = std.mem.splitScalar(u8, reqs_input[1 .. reqs_input.len - 1], ',');
        for (data_buf[0..target_len]) |*req| {
            req.* = try std.fmt.parseInt(u32, req_splitter.next() orelse return error.InvalidInput, 10);
        }

        return MachineJoltageManual{
            .data_ptr = data_buf.ptr,
            .target_len = target_len,
            .button_count = button_count,
        };
    }

    fn countButtonsAndRequirements(splitter: std.mem.TokenIterator(u8, .any)) !struct { usize, usize, usize } {
        var iter = splitter;
        var count: usize = 0;
        var value_count: usize = 0;
        while (iter.next()) |token| {
            if (token[0] == '{' and token[token.len - 1] == '}') {
                return .{
                    count,
                    value_count,
                    try countRequirements(token[1 .. token.len - 1]),
                };
            }
            if (token[0] != '(' or token[token.len - 1] != ')') {
                return error.InvalidInput;
            }
            count += 1;
            var value_splitter = std.mem.splitScalar(u8, token[1 .. token.len - 1], ',');
            while (value_splitter.next()) |_| {
                value_count += 1;
            }
        }
        return error.InvalidInput;
    }

    fn countRequirements(input: []const u8) !usize {
        var splitter = std.mem.splitScalar(u8, input, ',');
        var count: usize = 0;
        while (splitter.next()) |_| {
            count += 1;
        }
        return count;
    }

    pub fn getTarget(self: MachineJoltageManual) []const u32 {
        return self.data_ptr[0..self.target_len];
    }

    pub fn getButton(self: MachineJoltageManual, i: usize) JoltageButton {
        const start, const len = self.data_ptr[self.target_len + i * 2 ..][0..2].*;
        return JoltageButton{
            .affected_joltages = self.data_ptr[start..][0..len],
        };
    }

    pub fn deinit(self: *const MachineJoltageManual, alloc: Allocator) void {
        const start, const len = self.data_ptr[self.target_len + (self.button_count - 1) * 2 ..][0..2].*;
        alloc.free(self.data_ptr[0 .. start + len]);
    }
};

const JoltageButton = struct {
    affected_joltages: []const u32,
    pub fn apply(self: *const JoltageButton, joltages: []u32) void {
        for (self.affected_joltages) |affected| {
            joltages[affected] += 1;
        }
    }
};

const MachineLights = struct {
    lights: []LightStatus,

    pub fn deinit(self: *const MachineLights, alloc: Allocator) void {
        alloc.free(self.lights);
    }

    pub fn hasReachedTarget(self: *const MachineLights, target: []const LightStatus) bool {
        return std.mem.eql(LightStatus, self.lights, target);
    }

    pub fn reset(self: *const MachineLights) void {
        @memset(self.lights, .off);
    }

    // returns the minum required button presses to reach the target lights
    pub fn enableLights(self: *const MachineLights, manual: *const MachineLightManual) usize {
        const target = manual.getTarget();
        var press_buffer: [64]u8 = undefined;
        const button_count = manual.button_count;
        var presses = std.ArrayList(u8).initBuffer(&press_buffer);

        while (true) {
            self.reset();
            for (presses.items) |p| {
                const button = manual.getButton(p);
                button.apply(self.lights);
            }
            if (self.hasReachedTarget(target)) {
                return presses.items.len;
            }
            var i = presses.items.len;
            while (i > 0) {
                i -= 1;
                if (presses.items[i] + 1 < button_count) {
                    presses.items[i] += 1;
                    break;
                } else {
                    presses.items[i] = 0;
                }
            } else {
                presses.appendAssumeCapacity(0);
            }
        }
    }
};

const MachineJoltages = struct {

    // returns the minum required button presses to reach the target lights
    pub fn configureJoltages(manual: *const MachineJoltageManual, alloc: Allocator) !usize {
        const target = manual.getTarget();
        const button_count = manual.button_count;

        const matrix = try Matrix.alloc(manual.target_len, button_count + 1, alloc);
        defer matrix.deinit(alloc);
        matrix.fill(0);

        for (0..button_count) |i| {
            const button = manual.getButton(i);
            for (button.affected_joltages) |joltage_idx| {
                matrix.setCell(@intCast(joltage_idx), i, 1);
            }
        }
        matrix.setColumn(button_count, @ptrCast(target));

        for (0..@min(button_count, target.len)) |row_i| {
            if (matrix.getRow(row_i)[row_i] == 1) continue;
            for (0..target.len) |other_i| {
                if (row_i == other_i) continue;
                if (matrix.getRow(other_i)[row_i] == 0) continue;
                if (other_i < button_count and matrix.getRow(row_i)[other_i] == 0) continue;
                matrix.swapRows(row_i, other_i);
                break;
            }
        }

        std.log.debug("\n{f}", .{matrix});

        while (true) {
            var subtracted = false;
            for (0..target.len) |row_i| {
                for (0..target.len) |other_i| {
                    if (row_i == other_i) continue;
                    if (matrix.hasSubPattern(
                        row_i,
                        other_i,
                        row_i,
                        button_count,
                    )) {
                        matrix.subtractRows(row_i, other_i);
                        if (row_i < button_count) {
                            const pivot = matrix.getRow(row_i)[row_i];
                            if (pivot > 1 and matrix.canDivRow(row_i, pivot)) {
                                matrix.divRow(row_i, pivot);
                            }
                        }
                        const annotation = try std.fmt.allocPrint(alloc, "- row {d}", .{other_i});
                        defer alloc.free(annotation);
                        std.log.debug("\n{f}", .{
                            matrix.formatWithAnnotations(&.{.{ row_i, annotation }}),
                        });
                        subtracted = true;
                    }
                }
            }

            if (subtracted) continue;
            var added = false;
            adding: for (0..target.len) |row_i| {
                for (0..target.len) |other_i| {
                    if (row_i == other_i) continue;
                    if (matrix.hasExtendingPattern(
                        row_i,
                        other_i,
                        row_i,
                        button_count,
                    )) {
                        matrix.addRows(row_i, other_i);
                        const annotation = try std.fmt.allocPrint(alloc, "+ row {d}", .{other_i});
                        defer alloc.free(annotation);
                        std.log.debug("\n{f}", .{
                            matrix.formatWithAnnotations(&.{.{ row_i, annotation }}),
                        });
                        added = true;
                        break :adding;
                    }
                }
            }
            if (added) continue;
            var sum: usize = 0;
            check_finished: for (0..target.len) |row_i| {
                const row = matrix.getRow(row_i);
                for (row, 0..) |val, i| {
                    if (i >= button_count) {
                        if (val < 0) {
                            break :check_finished;
                        }
                        sum += @intCast(val);
                        continue;
                    }
                    const expected: i32 = if (i == row_i) 1 else 0;
                    if (val != expected) {
                        break :check_finished;
                    }
                }
            } else {
                return sum;
            }
            std.log.err("\n{f}", .{matrix});
            return error.Unimplemented;
        }
    }
};

const Matrix = struct {
    data: []i32,
    rows: usize,
    cols: usize,

    pub fn alloc(row: usize, col: usize, allocator: Allocator) !Matrix {
        const data = try allocator.alloc(i32, row * col);
        return Matrix{
            .data = data,
            .rows = row,
            .cols = col,
        };
    }

    pub fn fill(self: *const Matrix, value: i32) void {
        @memset(self.data, value);
    }

    pub fn deinit(self: *const Matrix, allocator: Allocator) void {
        allocator.free(self.data);
    }

    pub fn setColumn(self: *const Matrix, col: usize, values: []const i32) void {
        std.debug.assert(values.len == self.rows);
        for (0..self.rows) |r| {
            self.data[r * self.cols + col] = values[r];
        }
    }

    pub fn setCell(self: *const Matrix, row: usize, col: usize, value: i32) void {
        self.data[row * self.cols + col] = value;
    }

    pub fn getRow(self: *const Matrix, row: usize) []i32 {
        return self.data[row * self.cols ..][0..self.cols];
    }

    pub fn swapRows(self: *const Matrix, row_a: usize, row_b: usize) void {
        const row_data_a = self.getRow(row_a);
        const row_data_b = self.getRow(row_b);
        for (row_data_a, row_data_b) |*val_a, *val_b| {
            std.mem.swap(i32, val_a, val_b);
        }
    }

    pub fn subtractRows(self: *const Matrix, row: usize, subtractor: usize) void {
        const row_a = self.getRow(row);
        const row_b = self.getRow(subtractor);
        for (row_a, row_b) |*val_a, val_b| {
            val_a.* -= val_b;
        }
    }

    pub fn canDivRow(self: *const Matrix, row: usize, divisor: i32) bool {
        const row_data = self.getRow(row);
        for (row_data) |val| {
            if (@rem(val, divisor) != 0) {
                return false;
            }
        }
        return true;
    }

    pub fn divRow(self: *const Matrix, row: usize, divisor: i32) void {
        const row_data = self.getRow(row);
        for (row_data) |*val| {
            val.* = @divTrunc(val.*, divisor);
        }
    }

    pub fn addRows(self: *const Matrix, target: usize, addend: usize) void {
        const row_a = self.getRow(target);
        const row_b = self.getRow(addend);
        for (row_a, row_b) |*val_a, val_b| {
            val_a.* += val_b;
        }
    }

    pub fn hasSubPattern(self: *const Matrix, pattern_row: usize, comparator_row: usize, pivot_col: usize, max: usize) bool {
        const pattern = self.getRow(pattern_row);
        const comparator = self.getRow(comparator_row);
        var all_zero = true;
        for (pattern, comparator, 0..) |val_p, val_c, i| {
            if (i >= max) break;
            if (i == pivot_col and val_c != 0) return false;
            if (val_p != val_c and val_p == 0) {
                return false;
            }
            if (val_c != 0) {
                all_zero = false;
            }
        }
        return !all_zero;
    }

    pub fn hasExtendingPattern(self: *const Matrix, pattern_row: usize, comparator_row: usize, pivot_col: usize, max: usize) bool {
        const pattern = self.getRow(pattern_row);
        const comparator = self.getRow(comparator_row);
        var all_zero = true;
        if (pivot_col >= max) {
            return false;
        }
        for (pattern, comparator, 0..) |val_p, val_c, i| {
            if (i >= max) break;
            if (i == pivot_col) {
                if (val_c == 0) {
                    return false;
                }
                continue;
            }
            if (val_p == val_c and val_p != 0) {
                return false;
            }
            if (val_c != 0) {
                all_zero = false;
            }
        }
        return !all_zero;
    }

    pub fn print(self: *const Matrix, writer: *std.io.Writer, annotations: []const Annotation) !void {
        for (0..self.rows) |r| {
            const row = self.getRow(r);
            try writer.print("{d:>3}: ", .{r});
            for (row) |val| {
                try writer.print("{d: >} ", .{val});
            }
            for (annotations) |annotation| {
                const row_idx, const text = annotation;
                if (row_idx == r) {
                    try writer.print("; {s} ", .{text});
                }
            }
            try writer.print("\n", .{});
        }
    }

    pub fn format(self: *const Matrix, writer: *std.io.Writer) !void {
        return self.print(writer, &.{});
    }

    pub fn formatWithAnnotations(self: *const Matrix, annotations: []const Annotation) Formatter {
        return Formatter{
            .matrix = self,
            .annotations = annotations,
        };
    }

    const Annotation = struct { usize, []const u8 };
    const Formatter = struct {
        matrix: *const Matrix,
        annotations: []const Annotation,
        pub fn format(self: *const Formatter, writer: *std.io.Writer) !void {
            return self.matrix.print(writer, self.annotations);
        }
    };
};
pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var sum: usize = 0;
    while (lines.next()) |line| {
        const manual = try MachineLightManual.parse(alloc, line);
        defer manual.deinit(alloc);

        const machine = try manual.newMachine(alloc);
        defer machine.deinit(alloc);
        sum += machine.enableLights(&manual);
    }
    return sum;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var sum: usize = 0;
    while (lines.next()) |line| {
        const manual = try MachineJoltageManual.parse(alloc, line);
        defer manual.deinit(alloc);

        sum += try MachineJoltages.configureJoltages(&manual, alloc);
    }
    return sum;
}
