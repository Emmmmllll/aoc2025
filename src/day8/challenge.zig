const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Pos = struct {
    x: u32,
    y: u32,
    z: u32,

    pub fn distance_sqared(self: Pos, other: Pos) u64 {
        const dx: u64 = @intCast(if (self.x > other.x) self.x - other.x else other.x - self.x);
        const dy: u64 = @intCast(if (self.y > other.y) self.y - other.y else other.y - self.y);
        const dz: u64 = @intCast(if (self.z > other.z) self.z - other.z else other.z - self.z);
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn format(self: Pos, writer: *std.io.Writer) !void {
        try writer.print("({},{},{})", .{ self.x, self.y, self.z });
    }
};

const JBox = struct {
    pos: Pos,
    circuit_id: ?u32 = null,

    pub fn parse(input: []const u8) !JBox {
        var tokenizer = std.mem.tokenizeAny(u8, input, ",");
        const x_str = tokenizer.next() orelse return error.InvalidInput;
        const y_str = tokenizer.next() orelse return error.InvalidInput;
        const z_str = tokenizer.next() orelse return error.InvalidInput;
        const x = try std.fmt.parseInt(u32, x_str, 10);
        const y = try std.fmt.parseInt(u32, y_str, 10);
        const z = try std.fmt.parseInt(u32, z_str, 10);
        return JBox{
            .pos = Pos{
                .x = x,
                .y = y,
                .z = z,
            },
        };
    }
};

const ClosestPair = struct {
    index_a: u32,
    index_b: u32,
    distance_squared: u64,
};

const CircuitCount = struct {
    size: usize,
    count: usize,
};

const Boxes = struct {
    boxes: []JBox,
    next_circuit_id: u32 = 1,

    pub fn parse(alloc: Allocator, input: []const u8) !Boxes {
        var lines = std.mem.tokenizeAny(u8, input, "\r\n");
        var boxes = std.ArrayList(JBox).empty;
        while (lines.next()) |line| {
            try boxes.append(alloc, try JBox.parse(line));
        }
        return Boxes{
            .boxes = try boxes.toOwnedSlice(alloc),
        };
    }

    pub fn deinit(self: *const Boxes, alloc: Allocator) void {
        alloc.free(self.boxes);
    }

    pub fn findClosest(self: *Boxes, last: ?ClosestPair) ?ClosestPair {
        var closest: ?ClosestPair = null;
        for (self.boxes[0 .. self.boxes.len - 1], 0..) |*box_a, i| {
            for (self.boxes[i + 1 ..], i + 1..) |*box_b, j| {
                const dist = box_a.pos.distance_sqared(box_b.pos);
                if (last) |l| {
                    if (dist < l.distance_squared) continue;
                    if (dist == l.distance_squared and (i < l.index_a or (i == l.index_a and j <= l.index_b))) {
                        continue;
                    }
                }
                if (closest) |c| {
                    if (dist < c.distance_squared) {
                        closest = .{ .index_a = @intCast(i), .index_b = @intCast(j), .distance_squared = dist };
                    }
                } else {
                    closest = .{ .index_a = @intCast(i), .index_b = @intCast(j), .distance_squared = dist };
                }
            }
        }
        return closest;
    }

    pub fn connectBoxes(self: *Boxes, index_a: u32, index_b: u32) void {
        const box_a: *JBox = &self.boxes[index_a];
        const box_b: *JBox = &self.boxes[index_b];
        if (box_a.circuit_id == null and box_b.circuit_id == null) {
            box_a.circuit_id = self.next_circuit_id;
            box_b.circuit_id = self.next_circuit_id;
            self.next_circuit_id += 1;
        } else if (box_a.circuit_id != null and box_b.circuit_id == null) {
            box_b.circuit_id = box_a.circuit_id;
        } else if (box_a.circuit_id == null and box_b.circuit_id != null) {
            box_a.circuit_id = box_b.circuit_id;
        } else if (box_a.circuit_id != box_b.circuit_id) {
            const new_id = box_a.circuit_id.?;
            const old_id = box_b.circuit_id.?;
            for (self.boxes) |*b| {
                if (b.circuit_id == old_id) {
                    b.circuit_id = new_id;
                }
            }
        }
    }

    pub fn countCircuits(self: *const Boxes, alloc: Allocator) !usize {
        var seen = std.AutoHashMap(u32, void).init(alloc);
        defer seen.deinit();
        var count: usize = 0;
        for (self.boxes) |b| {
            if (b.circuit_id) |id| {
                if (seen.contains(id)) continue;
                count += 1;
                try seen.put(id, {});
            } else {
                count += 1;
            }
        }
        return count;
    }

    pub fn calcCircleSizes(self: *const Boxes, alloc: Allocator) ![]CircuitCount {
        var counts = std.AutoHashMap(u32, usize).init(alloc);
        defer counts.deinit();
        var unnamed_count: usize = 0;
        for (self.boxes) |b| {
            if (b.circuit_id) |id| {
                const current = counts.get(id) orelse 0;
                try counts.put(id, current + 1);
            } else unnamed_count += 1;
        }

        var circuits = try std.ArrayList(CircuitCount).initCapacity(alloc, counts.count());
        defer circuits.deinit(alloc);
        circuits.appendAssumeCapacity(CircuitCount{ .size = 1, .count = unnamed_count });
        var min_size: usize = 2;

        while (true) {
            var min: ?usize = null;
            var it = counts.valueIterator();
            while (it.next()) |size| {
                if (size.* < min_size) continue;
                if (min == null or size.* < min.?) min = size.*;
            }
            const curr_size = min orelse break;
            it = counts.valueIterator();
            var count: usize = 0;
            while (it.next()) |size| {
                if (size.* == curr_size) {
                    count += 1;
                }
            }
            try circuits.append(alloc, CircuitCount{ .size = curr_size, .count = count });
            min_size = curr_size + 1;
        }
        return circuits.toOwnedSlice(alloc);
    }

    pub fn connectNClosest(self: *Boxes, n: usize) void {
        var last: ?ClosestPair = null;
        for (0..n) |_| {
            const pair = self.findClosest(last) orelse return;
            self.connectBoxes(pair.index_a, pair.index_b);
            last = pair;
        }
    }

    pub fn connectClosestUntilAllConnected(self: *Boxes) ClosestPair {
        var last: ?ClosestPair = null;
        while (true) {
            const pair = self.findClosest(last) orelse unreachable;
            self.connectBoxes(pair.index_a, pair.index_b);
            last = pair;

            const circuit_id = self.boxes[0].circuit_id orelse continue;
            for (self.boxes) |b| {
                if (b.circuit_id != circuit_id) break;
            } else {
                return pair;
            }
        }
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var boxes = try Boxes.parse(alloc, input);
    defer boxes.deinit(alloc);
    boxes.connectNClosest(if (boxes.boxes.len == 20) 10 else 1000);
    std.log.info("Circuits: {}", .{try boxes.countCircuits(alloc)});
    const circuit_counts = try boxes.calcCircleSizes(alloc);
    defer alloc.free(circuit_counts);
    std.log.info("Circuit counts: {any}", .{circuit_counts});
    const largest_three = circuit_counts[circuit_counts.len -| 3..];
    var result: usize = 1;
    for (largest_three) |c| {
        result *= c.size;
    }
    return result;
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var boxes = try Boxes.parse(alloc, input);
    defer boxes.deinit(alloc);
    const last_pair = boxes.connectClosestUntilAllConnected();
    const box_a = boxes.boxes[last_pair.index_a];
    const box_b = boxes.boxes[last_pair.index_b];
    return box_a.pos.x * box_b.pos.x;
}
