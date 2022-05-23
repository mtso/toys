const std = @import("std");
const mem = std.mem;
const math = std.math;
const time = std.time;
const crypto = std.crypto;

const base32crockford = [_]u8{
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'X',
    'Y', 'Z',
};

const base32crockfordreversed = [_]u48{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, // 48 0 digits
    2, 3, 4, 5, 6, 7, 8, 9, 0, 0,
    0,  0,  0,  0,  0,  10, 11, 12, 13, 14, // 65 A uppercase
    15, 16, 17, 0,  18, 19, 0,  20, 21, 0,
    22, 23, 24, 25, 26, 0,  27, 28, 29, 30,
    31, 0,  0,  0,  0,  0,  0,  10, 11, 12, // 97 a lowercase
    13, 14, 15, 16, 17, 0,  18, 19, 0,  20,
    21, 0,  22, 23, 24, 25, 26, 0,  27, 28,
    29, 30, 31, 0,  0,  0,  0,  0,  0,  0,
};

const base32crockfordreversed_u80 = [_]u80{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, // 48 0 digits
    2, 3, 4, 5, 6, 7, 8, 9, 0, 0,
    0,  0,  0,  0,  0,  10, 11, 12, 13, 14, // 65 A uppercase
    15, 16, 17, 0,  18, 19, 0,  20, 21, 0,
    22, 23, 24, 25, 26, 0,  27, 28, 29, 30,
    31, 0,  0,  0,  0,  0,  0,  10, 11, 12, // 97 a lowercase
    13, 14, 15, 16, 17, 0,  18, 19, 0,  20,
    21, 0,  22, 23, 24, 25, 26, 0,  27, 28,
    29, 30, 31, 0,  0,  0,  0,  0,  0,  0,
};

pub fn order(a: Ulid, b: Ulid) math.Order {
    const timestamp_order = math.order(a.timestamp, b.timestamp);
    if (timestamp_order == .eq) {
        return math.order(a.randomness, b.randomness);
    } else {
        return timestamp_order;
    }
}

test "order" {
    const a = Ulid.init(1, 2);
    const b = Ulid.init(1, 2);
    try std.testing.expectEqual(math.Order.eq, order(a, a));
    try std.testing.expectEqual(math.Order.eq, order(a, b));

    const c = Ulid.init(1, 1);
    try std.testing.expectEqual(math.Order.gt, order(a, c));
    try std.testing.expectEqual(math.Order.lt, order(c, a));
}

const u40max = math.maxInt(u40);

pub const ParseError = error{
    WouldOverflowTimestamp,
};

pub const Ulid = struct {
    const Self = @This();

    timestamp: u48,
    randomness: u80,

    pub fn init(timestamp: u48, randomness: u80) Self {
        return .{
            .timestamp = timestamp,
            .randomness = randomness,
        };
    }

    pub fn fromBytes(bytes: [16]u8) Self {
        const timestamp: u48 = @intCast(u48, bytes[0]) << 40 |
            @intCast(u48, bytes[1]) << 32 |
            @intCast(u48, bytes[2]) << 24 |
            @intCast(u48, bytes[3]) << 16 |
            @intCast(u48, bytes[4]) << 8 |
            @intCast(u48, bytes[5]);
        const randomness: u80 = @intCast(u80, bytes[6]) << 72 |
            @intCast(u80, bytes[7]) << 64 |
            @intCast(u80, bytes[8]) << 56 |
            @intCast(u80, bytes[9]) << 48 |
            @intCast(u80, bytes[10]) << 40 |
            @intCast(u80, bytes[11]) << 32 |
            @intCast(u80, bytes[12]) << 24 |
            @intCast(u80, bytes[13]) << 16 |
            @intCast(u80, bytes[14]) << 8 |
            @intCast(u80, bytes[15]);
        return .{
            .timestamp = timestamp,
            .randomness = randomness,
        };
    }

    pub fn fromBase32(bytes: [26]u8) ParseError!Self {
        if (bytes[0] > '7') {
            return error.WouldOverflowTimestamp;
        }
        const timestamp: u48 = base32crockfordreversed[bytes[0]] << 45 |
            base32crockfordreversed[bytes[1]] << 40 |
            base32crockfordreversed[bytes[2]] << 35 |
            base32crockfordreversed[bytes[3]] << 30 |
            base32crockfordreversed[bytes[4]] << 25 |
            base32crockfordreversed[bytes[5]] << 20 |
            base32crockfordreversed[bytes[6]] << 15 |
            base32crockfordreversed[bytes[7]] << 10 |
            base32crockfordreversed[bytes[8]] << 5 |
            base32crockfordreversed[bytes[9]];
        const randomness: u80 = base32crockfordreversed_u80[bytes[10]] << 75 |
            base32crockfordreversed_u80[bytes[11]] << 70 |
            base32crockfordreversed_u80[bytes[12]] << 65 |
            base32crockfordreversed_u80[bytes[13]] << 60 |
            base32crockfordreversed_u80[bytes[14]] << 55 |
            base32crockfordreversed_u80[bytes[15]] << 50 |
            base32crockfordreversed_u80[bytes[16]] << 45 |
            base32crockfordreversed_u80[bytes[17]] << 40 |
            base32crockfordreversed_u80[bytes[18]] << 35 |
            base32crockfordreversed_u80[bytes[19]] << 30 |
            base32crockfordreversed_u80[bytes[20]] << 25 |
            base32crockfordreversed_u80[bytes[21]] << 20 |
            base32crockfordreversed_u80[bytes[22]] << 15 |
            base32crockfordreversed_u80[bytes[23]] << 10 |
            base32crockfordreversed_u80[bytes[24]] << 5 |
            base32crockfordreversed_u80[bytes[25]];

        return Self{
            .timestamp = timestamp,
            .randomness = randomness,
        };
    }

    pub fn fillBytes(self: Self, bytes: *[16]u8) void {
        bytes[0] = @intCast(u8, self.timestamp >> 40);
        bytes[1] = @intCast(u8, self.timestamp >> 32 & 0xFF);
        bytes[2] = @intCast(u8, self.timestamp >> 24 & 0xFF);
        bytes[3] = @intCast(u8, self.timestamp >> 16 & 0xFF);
        bytes[4] = @intCast(u8, self.timestamp >> 8 & 0xFF);
        bytes[5] = @intCast(u8, self.timestamp & 0xFF);

        bytes[6] = @intCast(u8, self.randomness >> 72);
        bytes[7] = @intCast(u8, self.randomness >> 64 & 0xFF);
        bytes[8] = @intCast(u8, self.randomness >> 56 & 0xFF);
        bytes[9] = @intCast(u8, self.randomness >> 48 & 0xFF);
        bytes[10] = @intCast(u8, self.randomness >> 40 & 0xFF);
        bytes[11] = @intCast(u8, self.randomness >> 32 & 0xFF);
        bytes[12] = @intCast(u8, self.randomness >> 24 & 0xFF);
        bytes[13] = @intCast(u8, self.randomness >> 16 & 0xFF);
        bytes[14] = @intCast(u8, self.randomness >> 8 & 0xFF);
        bytes[15] = @intCast(u8, self.randomness & 0xFF);
    }

    pub fn fillBase32(self: Self, bytes: *[26]u8) void {
        const r1 = @intCast(u40, self.randomness >> 40);
        const r2 = @intCast(u40, self.randomness & u40max);
        const str = [26]u8{
            base32crockford[self.timestamp >> 45],
            base32crockford[self.timestamp >> 40 & 0x1F],
            base32crockford[self.timestamp >> 35 & 0x1F],
            base32crockford[self.timestamp >> 30 & 0x1F],
            base32crockford[self.timestamp >> 25 & 0x1F],
            base32crockford[self.timestamp >> 20 & 0x1F],
            base32crockford[self.timestamp >> 15 & 0x1F],
            base32crockford[self.timestamp >> 10 & 0x1F],
            base32crockford[self.timestamp >> 5 & 0x1F],
            base32crockford[self.timestamp & 0x1F],
            base32crockford[r1 >> 35],
            base32crockford[r1 >> 30 & 0x1F],
            base32crockford[r1 >> 25 & 0x1F],
            base32crockford[r1 >> 20 & 0x1F],
            base32crockford[r1 >> 15 & 0x1F],
            base32crockford[r1 >> 10 & 0x1F],
            base32crockford[r1 >> 5 & 0x1F],
            base32crockford[r1 & 0x1F],
            base32crockford[r2 >> 35],
            base32crockford[r2 >> 30 & 0x1F],
            base32crockford[r2 >> 25 & 0x1F],
            base32crockford[r2 >> 20 & 0x1F],
            base32crockford[r2 >> 15 & 0x1F],
            base32crockford[r2 >> 10 & 0x1F],
            base32crockford[r2 >> 5 & 0x1F],
            base32crockford[r2 & 0x1F],
        };

        std.mem.copy(u8, bytes, str[0..]);
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        var str: [26]u8 = undefined;
        value.fillBase32(str[0..]);
        _ = try writer.print("{s}", .{str});
    }
};

test "from base32" {
    const strtmpl = "7ZZZZZZZZZZZZZZZZZZZZZZZZZ";
    var str: [26]u8 = undefined;
    std.mem.copy(u8, str[0..], strtmpl);
    const expected = Ulid.init(math.maxInt(u48), math.maxInt(u80));

    const ulid = try Ulid.fromBase32(str);
    try std.testing.expectEqual(expected, ulid);
}

test "from base32 lowercase" {
    const strtmpl = "7zzzzzzzzzzzzzzzzzzzzzzzzz";
    var str: [26]u8 = undefined;
    std.mem.copy(u8, str[0..], strtmpl);
    const expected = Ulid.init(math.maxInt(u48), math.maxInt(u80));

    const ulid = try Ulid.fromBase32(str);
    try std.testing.expectEqual(expected, ulid);
}

test "from base32 overflow" {
    const strtmpl = "8ZZZZZZZZZ0000000000000002";
    var str: [26]u8 = undefined;
    std.mem.copy(u8, str[0..], strtmpl);

    const ulid = Ulid.fromBase32(str);
    try std.testing.expectError(error.WouldOverflowTimestamp, ulid);
}

test "base32 repr" {
    var str: [26]u8 = undefined;
    const ulid = Ulid.init(math.maxInt(u48), 2);
    const expected = "7ZZZZZZZZZ0000000000000002";
    ulid.fillBase32(str[0..]);
    try std.testing.expect(std.mem.eql(u8, expected, str[0..]));
}

test "max" {
    var str: [26]u8 = undefined;
    const ulid = Ulid.init(math.maxInt(u48), math.maxInt(u80));
    const expected = "7ZZZZZZZZZZZZZZZZZZZZZZZZZ";
    ulid.fillBase32(str[0..]);
    try std.testing.expect(std.mem.eql(u8, expected, str[0..]));
}

test "fill" {
    const ulid = Ulid.init(math.maxInt(u48), 2);
    const expected = [16]u8{ 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 };
    var bytes: [16]u8 = undefined;
    ulid.fillBytes(bytes[0..]);

    try std.testing.expect(std.mem.eql(u8, expected[0..], bytes[0..]));
}

test "fromBytes" {
    const bytes = [16]u8{ 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 };
    const expected = "7ZZZZZZZZZ0000000000000002";
    const ulid = Ulid.fromBytes(bytes);
    var str: [26]u8 = undefined;
    ulid.fillBase32(str[0..]);
    try std.testing.expect(std.mem.eql(u8, expected, str[0..]));
}

pub const UlidError = error{
    /// Generating a next Ulid would overflow the current
    /// millisecond's randomness component. Try again on
    /// the next millisecond.
    WouldOverflowRandomness,
};

const u80max = math.maxInt(u80);

fn cryptoRandom() u80 {
    return crypto.random.int(u80);
}

pub const DefaultMonotonicFactory = MonotonicFactory(cryptoRandom);

test "default" {
    var factory = DefaultMonotonicFactory.init();
    _ = try factory.next();
    const id1 = try factory.next();
    const id2 = try factory.next();
    var id3 = try factory.next();
    id3.randomness = id1.randomness;
    try std.testing.expectEqual(id1, id1);
    try std.testing.expectEqual(id1, id3);
    try std.testing.expectEqual(id1.timestamp, id2.timestamp);
    try std.testing.expectEqual(id1.randomness + @intCast(u80, 1), id2.randomness);
}

test "default waitForNext" {
    // TODO Add time as injected dependency to test this.
    var factory = DefaultMonotonicFactory.init();
    _ = factory.waitForNext();
}

pub fn MonotonicFactory(comptime randomFn: fn () u80) type {
    return struct {
        const Self = @This();

        current_millis: i64 = 0,
        randomness: u80 = 0,

        pub fn init() Self {
            return Self{};
        }

        /// Generates a next ULID.
        /// Returns an error if incrementing the random component
        /// would overflow, in which case it is the caller's responsibility
        /// to try again the following millisecond.
        pub fn next(self: *Self) UlidError!Ulid {
            const now = time.milliTimestamp();
            if (self.current_millis != now) {
                self.current_millis = now;
                self.randomness = randomFn();
            } else if (self.randomness < u80max) {
                self.randomness += 1;
            } else {
                return error.WouldOverflowRandomness;
            }

            return Ulid.init(@intCast(u48, now), self.randomness);
        }

        pub fn waitForNext(self: *Self) Ulid {
            while (true) {
                return self.next() catch {
                    continue;
                };
            }
        }
    };
}

test "ulid" {
    const ulid = Ulid.init(1, 2);
    try std.testing.expectEqual(@intCast(u48, 1), ulid.timestamp);
    try std.testing.expectEqual(@intCast(u80, 2), ulid.randomness);
}

/// randomFn for testing that returns the maximum value of u80.
fn staticRandMax() u80 {
    return u80max;
}

test "overflow" {
    var monotonicFactory = MonotonicFactory(staticRandMax).init();
    // It should always succeed at least once per millisecond.
    _ = try monotonicFactory.next();
    const result = monotonicFactory.next();
    try std.testing.expectError(error.WouldOverflowRandomness, result);
    monotonicFactory.current_millis -= 1;
    _ = try monotonicFactory.next();
    const result2 = monotonicFactory.next();
    try std.testing.expectError(error.WouldOverflowRandomness, result2);
}
