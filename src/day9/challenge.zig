const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
    // .input_file = "testinput",
});

const Pos = packed struct {
    x: u32,
    y: u32,

    pub fn parse(input: []const u8) !Pos {
        var parts = std.mem.splitScalar(u8, input, ',');
        const x_str = std.mem.trim(
            u8,
            parts.next() orelse return error.InvalidInput,
            &std.ascii.whitespace,
        );
        const x = try std.fmt.parseInt(u32, x_str, 10);
        const y_str = std.mem.trim(
            u8,
            parts.next() orelse return error.InvalidInput,
            &std.ascii.whitespace,
        );
        const y = try std.fmt.parseInt(u32, y_str, 10);
        return Pos{ .x = x, .y = y };
    }

    pub fn area(self: Pos, other_corner: Pos) usize {
        const width = if (other_corner.x > self.x) other_corner.x - self.x else self.x - other_corner.x;
        const height = if (other_corner.y > self.y) other_corner.y - self.y else self.y - other_corner.y;
        return @as(usize, width + 1) * @as(usize, height + 1);
    }
};

const Offset = packed struct {
    x: i32,
    y: i32,

    pub fn fromPositions(start: Pos, end: Pos) Offset {
        return Offset{
            .x = @as(i32, @intCast(end.x)) - @as(i32, @intCast(start.x)),
            .y = @as(i32, @intCast(end.y)) - @as(i32, @intCast(start.y)),
        };
    }

    pub fn normalize(self: Offset) Offset {
        return Offset{
            .x = if (self.x > 0) 1 else if (self.x < 0) -1 else 0,
            .y = if (self.y > 0) 1 else if (self.y < 0) -1 else 0,
        };
    }

    pub fn turn(self: Offset, dir: PathDirection) Offset {
        return switch (dir) {
            .right => Offset{ .x = -self.y, .y = self.x },
            .left => Offset{ .x = self.y, .y = -self.x },
        };
    }
};

const PathDirection = enum {
    left,
    right,

    /// we assume, that start -> corner and corner -> end are always straight lines
    /// also, start, corner and end are never the same point and corner -> end is never
    /// in the opposite direction to start -> corner
    ///
    /// @return null if start -> corner and corner -> end are in the same direction
    /// otherwise, return the direction to turn at the corner
    fn fromCorner(start: Pos, corner: Pos, end: Pos) ?PathDirection {
        const first_offset = Offset.fromPositions(start, corner).normalize();
        const second_offset = Offset.fromPositions(corner, end).normalize();

        if (first_offset.turn(.left) == second_offset) {
            return .left;
        }

        if (first_offset.turn(.right) == second_offset) {
            return .right;
        }
        return null;
    }
};

const Corner = enum {
    top_left,
    top_right,
    bottom_left,
    bottom_right,

    pub fn frmPoints(start: Pos, corner: Pos, end: Pos) Corner {
        if (start.x == corner.x) {
            if (start.y < corner.y) {
                if (end.x < corner.x) {
                    return .bottom_right;
                } else {
                    return .bottom_left;
                }
            } else {
                if (end.x < corner.x) {
                    return .top_right;
                } else {
                    return .top_left;
                }
            }
        } else {
            if (start.x < corner.x) {
                if (end.y < corner.y) {
                    return .bottom_right;
                } else {
                    return .top_right;
                }
            } else {
                if (end.y < corner.y) {
                    return .bottom_left;
                } else {
                    return .top_left;
                }
            }
        }
    }
};

const Rect = struct {
    start: Pos,
    size: Pos,

    fn new(corner_a: Pos, corner_b: Pos) Rect {
        const start = Pos{
            .x = @min(corner_a.x, corner_b.x),
            .y = @min(corner_a.y, corner_b.y),
        };
        const size = Pos{
            .x = @max(corner_a.x, corner_b.x) - start.x + 1,
            .y = @max(corner_a.y, corner_b.y) - start.y + 1,
        };
        return Rect{
            .start = start,
            .size = size,
        };
    }

    fn hasArea(self: Rect) bool {
        return self.size.x != 0 and self.size.y != 0;
    }

    fn clamp(self: Rect, bounding: Rect) Rect {
        const start = Pos{
            .x = @min(@max(self.start.x, bounding.start.x), bounding.start.x + bounding.size.x),
            .y = @min(@max(self.start.y, bounding.start.y), bounding.start.y + bounding.size.y),
        };
        const size = Pos{
            .x = @min(
                self.start.x + self.size.x,
                bounding.start.x + bounding.size.x,
            ) -| start.x,
            .y = @min(
                self.start.y + self.size.y,
                bounding.start.y + bounding.size.y,
            ) -| start.y,
        };
        return Rect{
            .start = start,
            .size = size,
        };
    }

    pub fn unify(self: Rect, parts: *std.ArrayList(Rect), alloc: Allocator) !void {
        if (!self.hasArea()) {
            return;
        }
        try parts.append(alloc, self);
    }

    pub fn exclude(orig_self: Rect, parts: *std.ArrayList(Rect), alloc: Allocator) !void {
        if (!orig_self.hasArea()) {
            return;
        }
        var i: usize = parts.items.len;
        next_part: while (i != 0) {
            i -= 1;
            const part = parts.items[i];
            const self = orig_self.clamp(part);
            // fully covered
            if (part.size == self.size or !part.hasArea()) {
                _ = parts.orderedRemove(i);
                continue;
            }
            // no overlap
            if (!self.hasArea()) {
                continue;
            }
            // shared width
            if (part.size.x == self.size.x) {
                // horizontal split
                if (part.start.y == self.start.y) {
                    // cut off bottom
                    parts.items[i] = Rect{
                        .start = Pos{
                            .x = part.start.x,
                            .y = part.start.y + self.size.y,
                        },
                        .size = Pos{
                            .x = part.size.x,
                            .y = part.size.y - self.size.y,
                        },
                    };
                    continue;
                }
                if (part.start.y + part.size.y == self.start.y + self.size.y) {
                    // cut off top
                    parts.items[i] = Rect{
                        .start = part.start,
                        .size = Pos{
                            .x = part.size.x,
                            .y = part.size.y - self.size.y,
                        },
                    };
                    continue;
                }
                // reduce to bottom part and append top part
                parts.items[i] = Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = part.size.x,
                        .y = self.start.y - part.start.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = part.start.x,
                        .y = self.start.y + self.size.y,
                    },
                    .size = Pos{
                        .x = part.size.x,
                        .y = part.start.y + part.size.y - (self.start.y + self.size.y),
                    },
                });
                continue;
            }
            // shared height
            if (part.size.y == self.size.y) {
                // vertical split
                if (part.start.x == self.start.x) {
                    // cut off right
                    parts.items[i] = Rect{
                        .start = Pos{
                            .x = part.start.x + self.size.x,
                            .y = part.start.y,
                        },
                        .size = Pos{
                            .x = part.size.x - self.size.x,
                            .y = part.size.y,
                        },
                    };
                    continue;
                }
                if (part.start.x + part.size.x == self.start.x + self.size.x) {
                    // cut off left
                    parts.items[i] = Rect{
                        .start = part.start,
                        .size = Pos{
                            .x = part.size.x - self.size.x,
                            .y = part.size.y,
                        },
                    };
                    continue;
                }
                // reduce to left part and append right part
                parts.items[i] = Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = self.start.x - part.start.x,
                        .y = part.size.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = self.start.x + self.size.x,
                        .y = part.start.y,
                    },
                    .size = Pos{
                        .x = part.start.x + part.size.x - (self.start.x + self.size.x),
                        .y = part.size.y,
                    },
                });
                continue;
            }
            // one shared corner
            for (&self.corners(), &part.corners(), 0..) |own_corner, part_corner, j| {
                const corner_tag: Corner = @enumFromInt(j);
                if (own_corner == part_corner) {
                    switch (corner_tag) {
                        .top_left => {
                            // cut off bottom and apeend (right - bottom)
                            parts.items[i] = Rect{
                                .start = Pos{
                                    .x = part.start.x,
                                    .y = part.start.y + self.size.y,
                                },
                                .size = Pos{
                                    .x = part.size.x,
                                    .y = part.size.y - self.size.y,
                                },
                            };
                            try parts.append(alloc, Rect{
                                .start = Pos{
                                    .x = part.start.x + self.size.x,
                                    .y = part.start.y,
                                },
                                .size = Pos{
                                    .x = part.size.x - self.size.x,
                                    .y = self.size.y,
                                },
                            });
                        },
                        .top_right => {
                            // cut off bottom and append (left - bottom)
                            parts.items[i] = Rect{
                                .start = Pos{
                                    .x = part.start.x,
                                    .y = part.start.y + self.size.y,
                                },
                                .size = Pos{
                                    .x = part.size.x,
                                    .y = part.size.y - self.size.y,
                                },
                            };
                            try parts.append(alloc, Rect{
                                .start = part.start,
                                .size = Pos{
                                    .x = part.size.x - self.size.x,
                                    .y = self.size.y,
                                },
                            });
                        },
                        .bottom_left => {
                            // cut off top and append (right - top)
                            parts.items[i] = Rect{
                                .start = part.start,
                                .size = Pos{
                                    .x = part.size.x,
                                    .y = part.size.y - self.size.y,
                                },
                            };
                            try parts.append(alloc, Rect{
                                .start = Pos{
                                    .x = part.start.x + self.size.x,
                                    .y = self.start.y,
                                },
                                .size = Pos{
                                    .x = part.size.x - self.size.x,
                                    .y = self.size.y,
                                },
                            });
                        },
                        .bottom_right => {
                            // cut off top and append (left - top)
                            parts.items[i] = Rect{
                                .start = part.start,
                                .size = Pos{
                                    .x = part.size.x,
                                    .y = part.size.y - self.size.y,
                                },
                            };
                            try parts.append(alloc, Rect{
                                .start = Pos{
                                    .x = part.start.x,
                                    .y = self.start.y,
                                },
                                .size = Pos{
                                    .x = part.size.x - self.size.x,
                                    .y = self.size.y,
                                },
                            });
                        },
                    }
                    continue :next_part;
                }
            }
            // shared left edge
            if (part.start.x == self.start.x) {
                // cut off right and append (top and bottom - right)
                parts.items[i] = Rect{
                    .start = Pos{
                        .x = part.start.x + self.size.x,
                        .y = part.start.y,
                    },
                    .size = Pos{
                        .x = part.size.x - self.size.x,
                        .y = part.size.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = self.size.x,
                        .y = self.start.y - part.start.y,
                    },
                });
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = part.start.x,
                        .y = self.start.y + self.size.y,
                    },
                    .size = Pos{
                        .x = self.size.x,
                        .y = part.start.y + part.size.y - (self.start.y + self.size.y),
                    },
                });
            }
            // shared right edge
            if (part.start.x + part.size.x == self.start.x + self.size.x) {
                // cut off left and append (top and bottom - left)
                parts.items[i] = Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = part.size.x - self.size.x,
                        .y = part.size.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = self.start.x,
                        .y = part.start.y,
                    },
                    .size = Pos{
                        .x = self.size.x,
                        .y = self.start.y - part.start.y,
                    },
                });
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = self.start.x,
                        .y = self.start.y + self.size.y,
                    },
                    .size = Pos{
                        .x = self.size.x,
                        .y = part.start.y + part.size.y - (self.start.y + self.size.y),
                    },
                });
                continue;
            }
            // shared top edge
            if (part.start.y == self.start.y) {
                // cut off bottom and append (left and right - bottom)
                parts.items[i] = Rect{
                    .start = Pos{
                        .x = part.start.x,
                        .y = part.start.y + self.size.y,
                    },
                    .size = Pos{
                        .x = part.size.x,
                        .y = part.size.y - self.size.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = self.start.x - part.start.x,
                        .y = self.size.y,
                    },
                });
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = self.start.x + self.size.x,
                        .y = part.start.y,
                    },
                    .size = Pos{
                        .x = part.start.x + part.size.x - (self.start.x + self.size.x),
                        .y = self.size.y,
                    },
                });
                continue;
            }
            // shared bottom edge
            if (part.start.y + part.size.y == self.start.y + self.size.y) {
                // cut off top and append (left and right - top)
                parts.items[i] = Rect{
                    .start = part.start,
                    .size = Pos{
                        .x = part.size.x,
                        .y = part.size.y - self.size.y,
                    },
                };
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = part.start.x,
                        .y = self.start.y,
                    },
                    .size = Pos{
                        .x = self.start.x - part.start.x,
                        .y = self.size.y,
                    },
                });
                try parts.append(alloc, Rect{
                    .start = Pos{
                        .x = self.start.x + self.size.x,
                        .y = part.start.y,
                    },
                    .size = Pos{
                        .x = part.start.x + part.size.x - (self.start.x + self.size.x),
                        .y = self.size.y,
                    },
                });
                continue;
            }
            // self is in the middle of part -> split into 4 parts
            // cut top and append bottom and (left and right - top - bottom)
            parts.items[i] = Rect{
                .start = part.start,
                .size = Pos{
                    .x = part.size.x,
                    .y = self.start.y - part.start.y,
                },
            };
            try parts.append(alloc, Rect{
                .start = Pos{
                    .x = part.start.x,
                    .y = self.start.y + self.size.y,
                },
                .size = Pos{
                    .x = part.size.x,
                    .y = part.start.y + part.size.y - (self.start.y + self.size.y),
                },
            });
            try parts.append(alloc, Rect{
                .start = Pos{
                    .x = part.start.x,
                    .y = self.start.y,
                },
                .size = Pos{
                    .x = self.start.x - part.start.x,
                    .y = self.size.y,
                },
            });
            try parts.append(alloc, Rect{
                .start = Pos{
                    .x = self.start.x + self.size.x,
                    .y = self.start.y,
                },
                .size = Pos{
                    .x = part.start.x + part.size.x - (self.start.x + self.size.x),
                    .y = self.size.y,
                },
            });
            continue;
        }
        i = parts.items.len;
        while (i > 1) {
            i -= 1;
            var j = i - 1;
            while (j > 0) {
                j -= 1;
                if (parts.items[i].includesRect(parts.items[j])) {
                    _ = parts.orderedRemove(j);
                    i -= 1;
                } else if (parts.items[j].includesRect(parts.items[i])) {
                    _ = parts.orderedRemove(i);
                    break;
                }
            }
        }
    }

    pub fn includesPos(self: Rect, pos: Pos) bool {
        return pos.x >= self.start.x and pos.x < self.start.x + self.size.x and
            pos.y >= self.start.y and pos.y < self.start.y + self.size.y;
    }

    pub fn includesRect(self: Rect, other: Rect) bool {
        return self.includesPos(other.start) and
            self.includesPos(Pos{
                .x = other.start.x + other.size.x - 1,
                .y = other.start.y + other.size.y - 1,
            });
    }

    pub fn excludeCorner(self: Rect, corner: Corner) Rect {
        switch (corner) {
            .top_left => {
                return Rect{
                    .start = Pos{
                        .x = self.start.x + 1,
                        .y = self.start.y + 1,
                    },
                    .size = Pos{
                        .x = self.size.x -| 1,
                        .y = self.size.y -| 1,
                    },
                };
            },
            .top_right => {
                return Rect{
                    .start = Pos{
                        .x = self.start.x,
                        .y = self.start.y + 1,
                    },
                    .size = Pos{
                        .x = self.size.x -| 1,
                        .y = self.size.y -| 1,
                    },
                };
            },
            .bottom_left => {
                return Rect{
                    .start = Pos{
                        .x = self.start.x + 1,
                        .y = self.start.y,
                    },
                    .size = Pos{
                        .x = self.size.x -| 1,
                        .y = self.size.y -| 1,
                    },
                };
            },
            .bottom_right => {
                return Rect{
                    .start = self.start,
                    .size = Pos{
                        .x = self.size.x -| 1,
                        .y = self.size.y -| 1,
                    },
                };
            },
        }
    }

    fn corners(self: Rect) [4]Pos {
        return .{
            self.start,
            Pos{
                .x = self.start.x + self.size.x - 1,
                .y = self.start.y,
            },
            Pos{
                .x = self.start.x,
                .y = self.start.y + self.size.y - 1,
            },
            Pos{
                .x = self.start.x + self.size.x - 1,
                .y = self.start.y + self.size.y - 1,
            },
        };
    }
};

const Tiles = struct {
    red_tiles: []Pos,

    pub fn parse(alloc: Allocator, input: []const u8) !Tiles {
        var red_tiles = std.ArrayList(Pos).empty;
        defer red_tiles.deinit(alloc);
        var lines = std.mem.tokenizeAny(u8, input, "\r\n");
        while (lines.next()) |line| {
            const pos = try Pos.parse(line);
            try red_tiles.append(alloc, pos);
        }
        return Tiles{
            .red_tiles = try red_tiles.toOwnedSlice(alloc),
        };
    }

    pub fn deinit(self: *Tiles, alloc: Allocator) void {
        alloc.free(self.red_tiles);
    }

    pub fn findLargestArea(self: *const Tiles) usize {
        var largest_area: usize = 0;
        for (self.red_tiles[0 .. self.red_tiles.len - 1], 0..) |tile, i| {
            for (self.red_tiles[i + 1 ..]) |other_tile| {
                const area = tile.area(other_tile);
                if (area > largest_area) {
                    largest_area = area;
                }
            }
        }
        return largest_area;
    }

    pub fn findLargestAreaInRed(self: *const Tiles, alloc: Allocator) !usize {
        var missing_rects = try std.ArrayList(Rect).initCapacity(alloc, 1);
        defer missing_rects.deinit(alloc);
        var largest_area: usize = 0;
        const path_dir = self.pathDirection();
        for (self.red_tiles[0 .. self.red_tiles.len - 1], 0..) |tile, i| {
            for (self.red_tiles[i + 1 ..]) |other_tile| {
                const area = tile.area(other_tile);
                if (area > largest_area) {
                    missing_rects.clearRetainingCapacity();
                    if (try self.isRectInPath(
                        Rect.new(tile, other_tile),
                        path_dir,
                        alloc,
                        &missing_rects,
                    )) {
                        largest_area = area;
                    }
                }
            }
        }
        return largest_area;
    }

    fn pathDirection(self: *const Tiles) PathDirection {
        var left_turns: usize = 0;
        var right_turns: usize = 0;
        for (0..self.red_tiles.len) |i| {
            const first = self.red_tiles[i];
            const second = self.red_tiles[(i + 1) % self.red_tiles.len];
            const third = self.red_tiles[(i + 2) % self.red_tiles.len];
            const dir = PathDirection.fromCorner(first, second, third) orelse continue;
            switch (dir) {
                .left => left_turns += 1,
                .right => right_turns += 1,
            }
        }
        return if (left_turns >= right_turns) PathDirection.left else PathDirection.right;
    }

    fn isRectInPath(self: *const Tiles, rect: Rect, path_dir: PathDirection, alloc: Allocator, missing_rects: *std.ArrayList(Rect)) !bool {
        missing_rects.appendAssumeCapacity(rect);
        for (0..self.red_tiles.len) |i| {
            const first = self.red_tiles[i];
            const second = self.red_tiles[(i + 1) % self.red_tiles.len];
            const third = self.red_tiles[(i + 2) % self.red_tiles.len];
            const dir = PathDirection.fromCorner(first, second, third) orelse continue;
            const current_rect = Rect.new(first, third).clamp(rect);
            if (dir == path_dir) {
                try current_rect.exclude(missing_rects, alloc);
            } else {
                try current_rect.excludeCorner(.frmPoints(first, second, third)).unify(missing_rects, alloc);
            }
        }
        return missing_rects.items.len == 0;
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var tiles = try Tiles.parse(alloc, input);
    defer tiles.deinit(alloc);
    return tiles.findLargestArea();
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var tiles = try Tiles.parse(alloc, input);
    defer tiles.deinit(alloc);
    return try tiles.findLargestAreaInRed(alloc);
}
