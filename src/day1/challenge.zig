const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Direction = enum {
    left,
    right,

    fn parse(s: u8) !Direction {
        return switch (s) {
            'L' => Direction.left,
            'R' => Direction.right,
            else => return error.InvalidDirection,
        };
    }
};

const Rotation = struct {
    direction: Direction,
    amount: usize,

    pub fn parse(s: []const u8) !Rotation {
        if (s.len < 1) {
            return error.InvalidRotation;
        }
        const dir = try Direction.parse(s[0]);
        const amt = try std.fmt.parseInt(usize, s[1..], 10);
        return Rotation{
            .direction = dir,
            .amount = amt,
        };
    }

    pub fn offset(self: Rotation) isize {
        const iamount: isize = @intCast(self.amount);
        return switch (self.direction) {
            .left => -iamount,
            .right => iamount,
        };
    }

    pub fn format(self: Rotation, writer: *std.Io.Writer) !void {
        try writer.print("{c}{d}", .{
            @as(u8, switch (self.direction) {
                .left => 'L',
                .right => 'R',
            }),
            self.amount,
        });
    }
};

const Dial = struct {
    number: usize,

    const max_value = 99;
    pub fn rotate(self: *Dial, rotation: Rotation) void {
        const inumber: isize = @intCast(self.number);
        const iamount: isize = rotation.offset();
        self.number = @intCast(@mod((inumber + iamount), @as(isize, max_value + 1)));
    }

    pub fn rotateAndEndZero(self: *Dial, rotation: Rotation) bool {
        self.rotate(rotation);
        return self.number == 0;
    }
    pub fn rotateAndClickZero(self: *Dial, rotation: Rotation) usize {
        const zero_offset = switch (rotation.direction) {
            .left => if (self.number == 0) 0 else max_value - self.number + 1,
            .right => self.number,
        };
        self.rotate(rotation);
        return (rotation.amount + zero_offset) / (max_value + 1);
    }
};

fn challenge1(_: Allocator, input: []const u8) !usize {
    var dial = Dial{ .number = 50 };
    var lines = std.mem.splitScalar(u8, input, '\n');
    var password: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const rotation = try Rotation.parse(std.mem.trim(u8, line, " \r"));
        if (dial.rotateAndEndZero(rotation)) {
            password += 1;
        }
    }
    return password;
}

fn challenge2(_: Allocator, input: []const u8) !usize {
    var dial = Dial{ .number = 50 };
    var lines = std.mem.splitScalar(u8, input, '\n');
    var password: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const rotation = try Rotation.parse(std.mem.trim(u8, line, " \r"));
        const clicks = dial.rotateAndClickZero(rotation);
        password += clicks;
    }
    return password;
}
