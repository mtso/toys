const std = @import("std");
const assert = std.debug.assert;

test "Keydir" {
    var keydir = Keydir.init(std.testing.allocator);
    defer keydir.deinit();
    const v = ValueInfo{
        .timestamp = 0,
        .value_size = 0,
        .value_pos = 0,
    };
    try keydir.put("foo", v);
    const v2 = keydir.get("foo").?;
    try std.testing.expectEqual(v2.value_size, v.value_size);
}

test "DB get2 simple" {
    if (true) return;

    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("foo.db", .{ .truncate = true });
    file.close();

    if (true) {
        var db = try DB.open("foo.db", allocator);
        try db.set("foo", "bar");
        try db.set("foos", "bars");
        const value = try db.get2("foo", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
        allocator.free(value);
    }
    if (true) {
        var db = try DB.open("foo.db", allocator);
        const value = try db.get2("foo", allocator);
        const value2 = try db.get2("foos", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        try std.testing.expect(std.mem.eql(u8, value2, "bars"));
        db.close();
        allocator.free(value);
        allocator.free(value2);
    }
}

test "DB get2" {
    if (false) return;
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("foo.db", .{ .truncate = true });
    file.close();

    if (true) {
        var db = try DB.open("foo.db", allocator);
        try db.set("foo", "bar");
        const value = try db.get2("foo", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
        allocator.free(value);
    }
    if (true) {
        var db = try DB.open("foo.db", allocator);
        const value = try db.get2("foo", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
        allocator.free(value);
    }

    if (true) {
        var db = try DB.open("foo.db", allocator);
        defer db.close();
        try db.set("foos", "bars");
        const value = try db.get2("foos", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bars"));
        allocator.free(value);
    }
    if (true) {
        var db = try DB.open("foo.db", allocator);
        const value = try db.get2("foos", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "bars"));

        const value2 = try db.get2("foo", allocator);
        std.debug.print("whatwasthis: {s}\n", .{ value2 });
        try std.testing.expect(std.mem.eql(u8, value2, "bar"));
        db.close();
        allocator.free(value);
        allocator.free(value2);
    }

    if (true) {
        var db = try DB.open("foo.db", allocator);
        try db.set("foo", "quux");
        const value = try db.get2("foo", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "quux"));
        db.close();
        allocator.free(value);
    }
    if (true) {
        var db = try DB.open("foo.db", allocator);
        const value = try db.get2("foo", allocator);
        try std.testing.expect(std.mem.eql(u8, value, "quux"));
        db.close();
        allocator.free(value);
    }
}

const Head = packed struct {
    timestamp: i64,
    key_size: u64,
    value_size: u64,
};

const ValueInfo = packed struct {
    timestamp: i64,
    value_size: u64,
    value_pos: u64,
};

pub const Keydir = std.StringHashMap(ValueInfo);

pub const DB = struct {
    const Self = @This();

    keydir: std.StringHashMap(ValueInfo),
    file: std.fs.File,
    cursor: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn open(name: []const u8, allocator: std.mem.Allocator) !Self {
        const file = try std.fs.cwd().createFile(name, .{
            .truncate = false,
            .read = true,
        });

        var self = Self{
            .keydir = std.StringHashMap(ValueInfo).init(allocator),
            .file = file,
            .allocator = allocator,
        };
        // Ensuring total capacity here impacts the amount of memory
        // allocated at init time.
        //try self.keydir.ensureTotalCapacity(10_000);
        try self.reconstitute();
        return self;
    }

    pub fn close(self: *Self) void {
        self.file.close();

        {
            var it = self.keydir.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            self.keydir.deinit();
        }
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.file.seekFromEnd(0);
        const head = try self.writeHead(key.len, value.len);
        const key_bytes_written = try self.file.write(key);
        assert(key_bytes_written == key.len);
        const value_bytes_written = try self.file.write(value);
        assert(value_bytes_written == value.len);

        const vi = ValueInfo{
            .timestamp = head.timestamp,
            .value_size = value.len,
            .value_pos = self.cursor + @sizeOf(Head) + key.len,
        };
        self.cursor += @sizeOf(Head) + key.len + value.len;
        if (self.keydir.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
        }
        try self.keydir.put(
            try self.toOwned(key),
            vi
        );
    }

    /// Caller owns the memory of the returned string!
    /// Implementation note: get2 uses the keydir to locate
    /// the correct key from the data file.
    pub fn get2(self: *Self, key: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        if (self.keydir.get(key)) |info| {
            std.debug.print("sushi get2 t={d} value_size={d} value_pos={d} key={s}\n", .{
                info.timestamp,
                info.value_size,
                info.value_pos,
                key,
            });

            try self.file.seekTo(info.value_pos);
            var bytes = try allocator.alloc(u8, info.value_size);
            const bytes_read = try self.file.readAll(bytes[0..]);
            assert(bytes_read == bytes.len);
            return bytes;
        } else {
            return "";
        }
    }

    pub fn delete(self: *Self, key: []const u8) !void {
        try self.set(key, "");
    }

    // Allocates memory to copy the string and returns its pointer.
    fn toOwned(self: *Self, src: []const u8) ![]u8 {
        var bytes = try self.allocator.alloc(u8, src.len);
        std.mem.copy(u8, bytes, src);
        return bytes; 
    }

    fn writeHead(self: *Self, key_size: u64, value_size: u64) !Head {
        const head = Head{
            .timestamp = std.time.milliTimestamp(),
            .key_size = key_size,
            .value_size = value_size,
        };
        const Headtype = [@sizeOf(Head)]u8;
        const bytes = @bitCast(Headtype, head);
        const bytes_written = try self.file.write(bytes[0..]);
        assert(bytes_written == bytes.len);
        return head;
    }

    fn reconstitute(self: *Self) !void {
        try self.file.seekTo(0);

        var i: u64 = 0;
        while (true) {
            var bytes: [@sizeOf(Head)]u8 = undefined;
            const bytes_read = try self.file.readAll(bytes[0..]);
            if (bytes_read < bytes.len) {
                return;
            }

            const head = @bitCast(Head, bytes);

            i += 1;
            std.debug.print("i={d} timestamp={d} key_size={d} value_size={d} cursor={d} value_pos={d}\n", .{
                i,
                head.timestamp,
                head.key_size,
                head.value_size,
                self.cursor,
                self.cursor + @sizeOf(Head) + head.key_size,
            });

            var key = try self.readFileBytes(head.key_size);
            try self.file.seekBy(@intCast(i64, head.value_size));

            const vi = ValueInfo{
                .timestamp = head.timestamp,
                .value_size = head.value_size,
                .value_pos = self.cursor + @sizeOf(Head) + key.len,
            };
            if (self.keydir.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
            }
            try self.keydir.put(
                key,
                vi
            );

            self.cursor += @sizeOf(Head) + head.key_size + head.value_size;
        }
    }

    // Reads the number of bytes from the opened file as specified per `size`.
    // Caller owns the memory of the returned slice.
    fn readFileBytes(self: *Self, size: usize) ![]u8 {
        var bytes = try self.allocator.alloc(u8, size);
        const bytes_read = try self.file.readAll(bytes[0..]);
        assert(bytes_read == size);
        return bytes;
    }
};

