const std = @import("std");
const crypto = std.crypto;
const math = std.math;
const time = std.time;
const mem = std.mem;

const base32crockford = [_]u8{
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'X',
    'Y', 'Z',
};

const base32crockfordreversed = [_]u8{
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
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
};

pub fn order(a: Ulid, b: Ulid) math.Order {
    const timestamp_order = math.order(a.timestamp(), b.timestamp());
    if (timestamp_order == .eq) {
        return math.order(a.randomness(), b.randomness());
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

pub const Ulid = packed struct {
    const Self = @This();

    bytes: [16]u8,

    pub fn init(timestamp_: u48, randomness_: u80) Self {
        return Self{
            .bytes = [16]u8{
                @intCast(u8, timestamp_ >> 40),
                @intCast(u8, timestamp_ >> 32 & 0xFF),
                @intCast(u8, timestamp_ >> 24 & 0xFF),
                @intCast(u8, timestamp_ >> 16 & 0xFF),
                @intCast(u8, timestamp_ >> 8 & 0xFF),
                @intCast(u8, timestamp_ & 0xFF),

                @intCast(u8, randomness_ >> 72),
                @intCast(u8, randomness_ >> 64 & 0xFF),
                @intCast(u8, randomness_ >> 56 & 0xFF),
                @intCast(u8, randomness_ >> 48 & 0xFF),
                @intCast(u8, randomness_ >> 40 & 0xFF),
                @intCast(u8, randomness_ >> 32 & 0xFF),
                @intCast(u8, randomness_ >> 24 & 0xFF),
                @intCast(u8, randomness_ >> 16 & 0xFF),
                @intCast(u8, randomness_ >> 8 & 0xFF),
                @intCast(u8, randomness_ & 0xFF),
            },
        };
    }

    pub fn fillBase32(self: Self, bytes: *[26]u8) void {
        bytes[0] = base32crockford[self.bytes[0] >> 5 & 0x1F];
        bytes[1] = base32crockford[self.bytes[0] & 0x1F];
        bytes[2] = base32crockford[self.bytes[1] >> 3];
        bytes[3] = base32crockford[self.bytes[1] << 2 & 0x1F | self.bytes[2] >> 6];
        bytes[4] = base32crockford[self.bytes[2] >> 1 & 0x1F];
        bytes[5] = base32crockford[self.bytes[2] << 4 & 0x1F | self.bytes[3] >> 4];
        bytes[6] = base32crockford[self.bytes[3] << 1 & 0x1F | self.bytes[4] >> 7];
        bytes[7] = base32crockford[self.bytes[4] >> 2 & 0x1F];
        bytes[8] = base32crockford[self.bytes[4] << 3 & 0x1F | self.bytes[5] >> 5];
        bytes[9] = base32crockford[self.bytes[5] & 0x1F];
        bytes[10] = base32crockford[self.bytes[6] >> 3];
        bytes[11] = base32crockford[self.bytes[6] << 2 & 0x1F | self.bytes[7] >> 6];
        bytes[12] = base32crockford[self.bytes[7] >> 1 & 0x1F];
        bytes[13] = base32crockford[self.bytes[7] << 4 & 0x1F | self.bytes[8] >> 4];
        bytes[14] = base32crockford[self.bytes[8] << 1 & 0x1F | self.bytes[9] >> 7];
        bytes[15] = base32crockford[self.bytes[9] >> 2 & 0x1F];
        bytes[16] = base32crockford[self.bytes[9] << 3 & 0x1F | self.bytes[10] >> 5];
        bytes[17] = base32crockford[self.bytes[10] & 0x1F];
        bytes[18] = base32crockford[self.bytes[11] >> 3];
        bytes[19] = base32crockford[self.bytes[11] << 2 & 0x1F | self.bytes[12] >> 6];
        bytes[20] = base32crockford[self.bytes[12] >> 1 & 0x1F];
        bytes[21] = base32crockford[self.bytes[12] << 4 & 0x1F | self.bytes[13] >> 4];
        bytes[22] = base32crockford[self.bytes[13] << 1 & 0x1F | self.bytes[14] >> 7];
        bytes[23] = base32crockford[self.bytes[14] >> 2 & 0x1F];
        bytes[24] = base32crockford[self.bytes[14] << 3 & 0x1F | self.bytes[15] >> 5];
        bytes[25] = base32crockford[self.bytes[15] & 0x1F];
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        var str: [26]u8 = undefined;
        value.fillBase32(str[0..]);
        _ = try writer.print("{s}", .{str});
    }

    pub fn timestamp(self: Self) u48 {
        return @intCast(u48, self.bytes[0]) << 40 |
            @intCast(u48, self.bytes[1]) << 32 |
            @intCast(u48, self.bytes[2]) << 24 |
            @intCast(u48, self.bytes[3]) << 16 |
            @intCast(u48, self.bytes[4]) << 8 |
            @intCast(u48, self.bytes[5]);
    }

    pub fn randomness(self: Self) u80 {
        return @intCast(u80, self.bytes[6]) << 72 |
            @intCast(u80, self.bytes[7]) << 64 |
            @intCast(u80, self.bytes[8]) << 56 |
            @intCast(u80, self.bytes[9]) << 48 |
            @intCast(u80, self.bytes[10]) << 40 |
            @intCast(u80, self.bytes[11]) << 32 |
            @intCast(u80, self.bytes[12]) << 24 |
            @intCast(u80, self.bytes[13]) << 16 |
            @intCast(u80, self.bytes[14]) << 8 |
            @intCast(u80, self.bytes[15]);
    }

    pub fn equals(self: Self, other: Self) bool {
        return mem.eql(u8, self.bytes[0..], other.bytes[0..]);
    }

    pub const ParseError = error{
        StringTooShort,
        WouldOverflowTimestamp,
    };

    pub fn parseBase32(bytes: []const u8) ParseError!Self {
        if (bytes.len < 26) return error.StringTooShort;
        if (bytes[0] > '7') return error.WouldOverflowTimestamp;
        return Self{
            .bytes = [16]u8{
                base32crockfordreversed[bytes[0]] << 5 | base32crockfordreversed[bytes[1]],
                base32crockfordreversed[bytes[2]] << 3 | base32crockfordreversed[bytes[3]] >> 2,
                base32crockfordreversed[bytes[3]] << 6 | base32crockfordreversed[bytes[4]] << 1 | base32crockfordreversed[bytes[5]] >> 4,
                base32crockfordreversed[bytes[5]] << 4 | base32crockfordreversed[bytes[6]] >> 1,
                base32crockfordreversed[bytes[6]] << 7 | base32crockfordreversed[bytes[7]] << 2 | base32crockfordreversed[bytes[8]] >> 3,
                base32crockfordreversed[bytes[8]] << 5 | base32crockfordreversed[bytes[9]],
                base32crockfordreversed[bytes[10]] << 3 | base32crockfordreversed[bytes[11]] >> 2,
                base32crockfordreversed[bytes[11]] << 6 | base32crockfordreversed[bytes[12]] << 1 | base32crockfordreversed[bytes[13]] >> 4,
                base32crockfordreversed[bytes[13]] << 4 | base32crockfordreversed[bytes[14]] >> 1,
                base32crockfordreversed[bytes[14]] << 7 | base32crockfordreversed[bytes[15]] << 2 | base32crockfordreversed[bytes[16]] >> 3,
                base32crockfordreversed[bytes[16]] << 5 | base32crockfordreversed[bytes[17]],
                base32crockfordreversed[bytes[18]] << 3 | base32crockfordreversed[bytes[19]] >> 2,
                base32crockfordreversed[bytes[19]] << 6 | base32crockfordreversed[bytes[20]] << 1 | base32crockfordreversed[bytes[21]] >> 4,
                base32crockfordreversed[bytes[21]] << 4 | base32crockfordreversed[bytes[22]] >> 1,
                base32crockfordreversed[bytes[22]] << 7 | base32crockfordreversed[bytes[23]] << 2 | base32crockfordreversed[bytes[24]] >> 3,
                base32crockfordreversed[bytes[24]] << 5 | base32crockfordreversed[bytes[25]],
            },
        };
    }
};

// INVALID
// 01G3WB8CZJNHD67Q7N2APFN4XI
// 01G3WB8CZJNHD67Q7N2APFN4XL
test "parseBase32" {
    const strings = [_][]const u8{
        // "01G3WB8CZJNHD67Q7N2APFN4XI",
        "7ZZZZZZZZZZZZZZZZZZZZZZZZZ",
    };
    for (strings) |str| {
        const ulid = try Ulid.parseBase32(str);
        const expected: [16]u8 = [_]u8{0xFF} ** 16;
        try std.testing.expect(std.mem.eql(u8, expected[0..], ulid.bytes[0..]));
    }
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

test "base32" {
    const ulid = Ulid.init(std.math.maxInt(u48), std.math.maxInt(u80));
    const expected = "7ZZZZZZZZZZZZZZZZZZZZZZZZZ";
    var bytes: [26]u8 = undefined;
    ulid.fillBase32(&bytes);
    try std.testing.expect(std.mem.eql(u8, expected, bytes[0..]));

    var ulid2 = Ulid.init(0, 0);
    ulid2.bytes = [16]u8{ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    ulid2.fillBase32(&bytes);
    try std.testing.expect(std.mem.eql(u8, expected, bytes[0..]));
}

test "is it created" {
    const ulid = Ulid.init(1, 2);
    const bytes = @bitCast([16]u8, ulid);
    try std.testing.expect(std.mem.eql(u8, bytes[0..], ulid.bytes[0..]));
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

test "default waitForNext" {
    // TODO Add time as injected dependency to test this.
    var factory = DefaultMonotonicFactory.init();
    _ = factory.waitForNext();
}

test "ulid" {
    const ulid = Ulid.init(1, 2);
    try std.testing.expectEqual(@intCast(u48, 1), ulid.timestamp());
    try std.testing.expectEqual(@intCast(u80, 2), ulid.randomness());
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
