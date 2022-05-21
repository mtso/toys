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

test "DB" {
    const file = try std.fs.cwd().createFile("foo.db", .{ .truncate = true });
    file.close();

    if (true) {
        var db = try DB.open("foo.db", std.testing.allocator);
        try db.set("foo", "bar");
        const value = db.get("foo");
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
    }

    if (true) {
        var db = try DB.open("foo.db", std.testing.allocator);
        const value = db.get("foo");
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
    }

    if (true) {
        var db = try DB.open("foo.db", std.testing.allocator);
        try db.set("foo", "bar");
        const value = db.get("foo");
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
    }

    if (true) {
        var db = try DB.open("foo.db", std.testing.allocator);
        const value = db.get("foo");
        try std.testing.expect(std.mem.eql(u8, value, "bar"));
        db.close();
    }
}

test "DB get2" {
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

    keydir: std.StringHashMap(*ValueInfo),
    map: std.StringHashMap([]const u8),
    file: std.fs.File,
    cursor: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn open(name: []const u8, allocator: std.mem.Allocator) !Self {
        const file = try std.fs.cwd().createFile(name, .{
            .truncate = false,
            .read = true,
        });

        var self = Self{
            .keydir = std.StringHashMap(*ValueInfo).init(allocator),
            .map = std.StringHashMap([]const u8).init(allocator),
            .file = file,
            .allocator = allocator,
        };
        //try self.keydir.ensureTotalCapacity(10_000);
        try self.reconstitute();
        return self;
    }

    pub fn close(self: *Self) void {
        self.file.close();

        {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
        }

        {
            var it = self.keydir.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.destroy(entry.value_ptr.*);
            }
            self.keydir.deinit();
        }
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.setInmemory(
            try self.toOwned(key),
            try self.toOwned(value)
        );

        try self.file.seekFromEnd(0);
        const head = try self.writeHead(key.len, value.len);
        const key_bytes_written = try self.file.write(key);
        assert(key_bytes_written == key.len);
        const value_bytes_written = try self.file.write(value);
        assert(value_bytes_written == value.len);

        var vi = try self.allocator.create(ValueInfo);
        vi.* = ValueInfo{
            .timestamp = head.timestamp,
            .value_size = value.len,
            .value_pos = self.cursor + @sizeOf(Head) + key.len,
        };
        self.cursor += @sizeOf(Head) + key.len + value.len;
        if (self.keydir.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.destroy(kv.value);
        }
        try self.keydir.put(
            try self.toOwned(key),
            vi
        );
    }

    /// Caller owns the memory of the returned string!
    pub fn get2(self: *Self, key: []const u8, allocator: std.mem.Allocator) ![]const u8 {
       if (self.keydir.get(key)) |info| {
           try self.file.seekTo(info.value_pos);
           var bytes = try allocator.alloc(u8, info.value_size);
           const bytes_read = try self.file.readAll(bytes[0..]);
           assert(bytes_read == bytes.len);
           return bytes;
       } else {
           return "";
       }
    }

    pub fn get(self: *Self, key: []const u8) []const u8 {
       if (self.map.get(key)) |value| {
           return value;
       } else {
           return "";
       }
    }

    fn setInmemory(self: *Self, key: []u8, value: []u8) !void {
        if (self.map.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
        try self.map.put(key, value);
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
        const bytes = @bitCast([@sizeOf(Head)]u8, head);
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
            std.debug.print("i={d} timestamp={d} key_size={d} value_size={d}\n", .{
                i,
                head.timestamp,
                head.key_size,
                head.value_size,
            });

            var key = try self.readFileBytes(head.key_size);
            var value = try self.readFileBytes(head.value_size);
            try self.setInmemory(key, value);

            var vi = try self.allocator.create(ValueInfo);
            vi.* = ValueInfo{
                .timestamp = head.timestamp,
                .value_size = head.value_size,
                .value_pos = self.cursor + @sizeOf(Head) + key.len,
            };
            if (self.keydir.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
                self.allocator.destroy(kv.value);
            }
            try self.keydir.put(
                try self.toOwned(key),
                vi
            );

            self.cursor += bytes_read + head.key_size + head.value_size;
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

