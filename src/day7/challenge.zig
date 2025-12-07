const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Cell = enum(u8) {
    empty = '.',
    start = 'S',
    splitter = '^',
    beam = '|',
};
const Map = struct {
    width: usize,
    height: usize,
    cells: []Cell,

    pub fn parse(alloc: Allocator, input: []const u8) !Map {
        var lineiter = std.mem.tokenizeAny(u8, input, "\r\n");
        const width = lineiter.next().?.len;
        var height: usize = 1;
        while (lineiter.next()) |_| {
            height += 1;
        }
        const cells = try alloc.alloc(Cell, width * height);
        errdefer alloc.free(cells);
        lineiter = std.mem.tokenizeAny(u8, input, "\r\n");
        var rest = cells;
        while (lineiter.next()) |line| {
            @memcpy(rest[0..width], @as([]const Cell, @ptrCast(line)));
            rest = rest[width..];
        }

        return Map{
            .width = width,
            .height = height,
            .cells = cells,
        };
    }

    pub fn deinit(self: *const Map, alloc: Allocator) void {
        alloc.free(self.cells);
    }

    pub fn beamDown(self: *const Map, row: usize) usize {
        if (row >= self.height - 1) return 0;
        const current = self.getRow(row);
        const below = self.getRow(row + 1);
        var splits: usize = 0;
        for (current, 0..) |cell, col| {
            switch (cell) {
                .beam, .start => {},
                else => continue,
            }
            const below_cell: *Cell = &below[col];
            if (below_cell.* != .splitter) {
                below_cell.* = .beam;
                continue;
            }
            splits += 1;
            for (&[_]isize{ -1, 1 }) |offset| {
                const offset_col: usize = @intCast(@as(isize, @intCast(col)) + offset);
                const offset_cell: *Cell = &below[offset_col];
                if (offset_cell.* == .empty) {
                    offset_cell.* = .beam;
                }
            }
        }
        return splits;
    }

    pub fn beamDownTracking(self: *const Map, row: usize, beams: []usize, next_beams: []usize) void {
        if (row >= self.height - 1) return;
        if (row == 0) {
            const current = self.getRow(row);
            for (beams, current) |*beam_count, cell| {
                beam_count.* = if (cell == .start) 1 else 0;
            }
        }
        const below = self.getRow(row + 1);
        for (beams, 0..) |beam_count, col| {
            if (beam_count == 0) continue;
            const below_cell: *Cell = &below[col];
            if (below_cell.* != .splitter) {
                next_beams[col] += beam_count;
                continue;
            }
            for (&[_]isize{ -1, 1 }) |offset| {
                const offset_col: usize = @intCast(@as(isize, @intCast(col)) + offset);
                next_beams[offset_col] += beam_count;
            }
        }
    }

    fn getRow(self: *const Map, row: usize) []Cell {
        return self.cells[row * self.width .. (row + 1) * self.width];
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    const map = try Map.parse(alloc, input);
    defer map.deinit(alloc);
    var splits: usize = 0;
    for (0..map.height - 1) |row| {
        splits += map.beamDown(row);
    }
    return splits;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    const map = try Map.parse(alloc, input);
    defer map.deinit(alloc);
    var beam_buf = try alloc.alloc(usize, map.width * 2);
    defer alloc.free(beam_buf);
    var beams = beam_buf[0..map.width];
    var next_beams = beam_buf[map.width..];
    for (0..map.height - 1) |row| {
        @memset(next_beams, 0);
        map.beamDownTracking(row, beams, next_beams);
        std.mem.swap([]usize, &beams, &next_beams);
    }
    var total_beams: usize = 0;
    for (beams) |beam_count| {
        total_beams += beam_count;
    }
    return total_beams;
}
