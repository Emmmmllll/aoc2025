const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

pub const main = utils.buildMain(.{
    .challenge1 = challenge1,
    .challenge2 = challenge2,
});

const Label = struct {
    raw: [3]u8,

    pub fn parse(input: []const u8) !Label {
        if (input.len != 3) {
            return error.InvalidLabelLength;
        }
        return Label.fromRaw(input[0..3]);
    }

    pub fn fromRaw(raw: *const [3]u8) Label {
        return Label{
            .raw = raw.*,
        };
    }

    pub fn is(self: Label, other: Label) bool {
        return std.mem.eql(u8, &self.raw, &other.raw);
    }
};

const Immediate = struct {
    both: usize = 0,
    dac: usize = 0,
    fft: usize = 0,
    none: usize = 0,

    pub fn add(self: Immediate, other: Immediate) Immediate {
        return Immediate{
            .both = self.both + other.both,
            .dac = self.dac + other.dac,
            .fft = self.fft + other.fft,
            .none = self.none + other.none,
        };
    }
    fn process(self: Immediate, current: Label) Immediate {
        var result = self;
        if (current.is(Label.fromRaw("dac"))) {
            result.both += result.fft;
            result.fft = 0;
            result.dac += result.none;
            result.none = 0;
        }
        if (current.is(Label.fromRaw("fft"))) {
            result.both += result.dac;
            result.dac = 0;
            result.fft += result.none;
            result.none = 0;
        }
        return result;
    }
};

const Cache = struct {
    map: std.AutoHashMap(Label, Immediate),

    pub fn init(alloc: Allocator) Cache {
        return Cache{
            .map = std.AutoHashMap(Label, Immediate).init(alloc),
        };
    }

    pub fn put(self: *Cache, label: Label, value: Immediate) !void {
        try self.map.put(label, value);
    }

    pub fn get(self: *const Cache, label: Label) ?Immediate {
        return self.map.get(label);
    }

    pub fn deinit(self: *Cache) void {
        self.map.deinit();
    }
};

const Map = struct {
    map: std.AutoArrayHashMap(Label, []const Label),
    pub fn parse(input: []const u8, alloc: Allocator) !Map {
        var map = std.AutoArrayHashMap(Label, []const Label).init(alloc);
        errdefer {
            var m = Map{
                .map = map,
            };
            m.deinit();
        }
        var lines = std.mem.tokenizeAny(u8, input, "\r\n");
        while (lines.next()) |line| {
            var splitter = std.mem.tokenizeAny(u8, line, ": ");
            const key = try Label.parse(splitter.next() orelse return error.InvalidMapEntry);
            const before_values = splitter;
            var value_count: usize = 0;
            while (splitter.next()) |_| {
                value_count += 1;
            }
            const values = try alloc.alloc(Label, value_count);
            errdefer alloc.free(values);
            splitter = before_values;
            for (values) |*value| {
                const v = try Label.parse(splitter.next() orelse return error.InvalidMapEntry);
                value.* = v;
            }
            try map.put(key, values);
        }
        return Map{
            .map = map,
        };
    }

    pub fn deinit(self: *Map) void {
        var it = self.map.iterator();
        const alloc = self.map.allocator;
        while (it.next()) |entry| {
            alloc.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn countPaths(self: *const Map, from: Label, to: Label) !usize {
        var sum: usize = 0;
        for (self.map.get(from) orelse return error.NoSuchLabel) |connection| {
            if (connection.is(to)) {
                sum += 1;
            } else {
                sum += try self.countPaths(connection, to);
            }
        }
        return sum;
    }

    pub fn countPaths2(self: *const Map, from: Label, to: Label, cache: *Cache) !Immediate {
        var imm = Immediate{};
        if (cache.get(from)) |cached| {
            return cached;
        }
        for (self.map.get(from) orelse return error.NoSuchLabel) |connection| {
            if (connection.is(to)) {
                imm.none += 1;
            } else {
                imm = imm.add(try self.countPaths2(connection, to, cache));
            }
        }
        imm = imm.process(from);
        try cache.put(from, imm);
        return imm;
    }
};

pub fn challenge1(alloc: Allocator, input: []const u8) !usize {
    var map = try Map.parse(input, alloc);
    defer map.deinit();

    return map.countPaths(Label.fromRaw("you"), Label.fromRaw("out"));
}

pub fn challenge2(alloc: Allocator, input: []const u8) !usize {
    var map = try Map.parse(input, alloc);
    defer map.deinit();

    var cache = Cache.init(alloc);
    defer cache.deinit();

    const res = try map.countPaths2(
        Label.fromRaw("svr"),
        Label.fromRaw("out"),
        &cache,
    );
    return res.both;
}
