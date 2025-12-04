const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Grid = struct {
    width: usize,
    height: usize,
    cells: []Cell,

    pub fn parse(alloc: Allocator, input: []const u8) !Grid {
        var splitter = std.mem.tokenizeAny(u8, input, "\n\r");
        const first_line = splitter.next() orelse return error.InvalidInput;
        const width = first_line.len;
        const guessed_height = (input.len + 3) / (width + 1);
        var cells_list = try std.ArrayList(Cell).initCapacity(alloc, guessed_height * width);
        defer cells_list.deinit(alloc);

        cells_list.appendSliceAssumeCapacity(@ptrCast(first_line));
        var height: usize = 1;

        while (splitter.next()) |line| {
            if (line.len != width) {
                return error.InvalidInput;
            }
            cells_list.appendSliceAssumeCapacity(@ptrCast(line));
            height += 1;
        }
        return Grid{
            .width = width,
            .height = height,
            .cells = try cells_list.toOwnedSlice(alloc),
        };
    }

    pub fn deinit(self: *Grid, alloc: Allocator) void {
        alloc.free(self.cells);
    }

    pub fn getCell(self: *const Grid, pos: Pos) Cell {
        std.debug.assert(pos.inBounds(self));
        return self.cells[pos.toIndex(self)];
    }

    pub fn setCell(self: *Grid, pos: Pos, value: Cell) void {
        std.debug.assert(pos.inBounds(self));
        self.cells[pos.toIndex(self)] = value;
    }

    pub fn format(self: *const Grid, writer: *std.Io.Writer) !void {
        var row_iter = std.mem.window(u8, @ptrCast(self.cells), self.width, self.width);
        while (row_iter.next()) |row| {
            try writer.writeAll(row);
            try writer.writeByte('\n');
        }
    }

    pub fn markRolls(self: *Grid) usize {
        var pos = Pos.zero;
        const directions = Pos.directions ++ Pos.diagonal_directions;
        var valid_rolls: usize = 0;

        while (pos.moveWrappingDown(.right, self)) |next_pos| {
            pos = next_pos;
            if (self.getCell(pos) != .roll) continue;
            var roll_count: usize = 0;
            for (&directions) |dir| {
                const check_pos = pos.move(dir);
                if (!check_pos.inBounds(self)) continue;
                if (self.getCell(check_pos) == .empty) continue;
                roll_count += 1;
            }

            if (roll_count < 4) {
                self.setCell(pos, .marked);
                valid_rolls += 1;
            }
        }
        return valid_rolls;
    }

    pub fn removeMarked(self: *Grid) void {
        for (self.cells) |*cell| {
            if (cell.* == .marked) {
                cell.* = .empty;
            }
        }
    }
};

const Pos = struct {
    x: isize,
    y: isize,
    pub const zero = Pos{ .x = 0, .y = 0 };
    pub const one = Pos{ .x = 1, .y = 1 };
    pub const up = Pos{ .x = 0, .y = -1 };
    pub const down = Pos{ .x = 0, .y = 1 };
    pub const left = Pos{ .x = -1, .y = 0 };
    pub const right = Pos{ .x = 1, .y = 0 };
    const directions = [_]Pos{
        .right,
        .down,
        .left,
        .up,
    };
    const diagonal_directions = [_]Pos{
        Pos.up.move(.right),
        Pos.up.move(.left),
        Pos.down.move(.right),
        Pos.down.move(.left),
    };

    pub fn move(self: Pos, other: Pos) Pos {
        return Pos{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn moveWrappingDown(self: Pos, other: Pos, grid: *const Grid) ?Pos {
        var new_x = self.x + other.x;
        var new_y = self.y + other.y;
        if (new_x < 0) {
            new_x += @as(isize, @intCast(grid.width));
            new_y -= 1;
        } else if (@as(usize, @intCast(new_x)) >= grid.width) {
            new_x -= @as(isize, @intCast(grid.width));
            new_y += 1;
        }
        if (new_y < 0 or @as(usize, @intCast(new_y)) >= grid.height) {
            return null;
        }
        return Pos{
            .x = new_x,
            .y = new_y,
        };
    }

    pub fn toIndex(self: Pos, grid: *const Grid) usize {
        return @as(usize, @intCast(self.y)) * grid.width + @as(usize, @intCast(self.x));
    }

    pub fn inBounds(self: Pos, grid: *const Grid) bool {
        return self.x >= 0 and self.y >= 0 and
            @as(usize, @intCast(self.x)) < grid.width and
            @as(usize, @intCast(self.y)) < grid.height;
    }
};

const Cell = enum(u8) {
    empty = '.',
    roll = '@',
    marked = 'x',
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);
    return grid.markRolls();
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);
    var total_removed: usize = 0;
    while (true) {
        const marked = grid.markRolls();
        if (marked == 0) break;
        grid.removeMarked();
        total_removed += marked;
    }
    return total_removed;
}
