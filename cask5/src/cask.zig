const std = @import("std");
const assert = std.debug.assert;

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

const Head = packed struct {
    timestamp: i64,
    key_size: u64,
    value_size: u64,
};

pub const DB = struct {
    const Self = @This();

    map: std.StringHashMap([]const u8),
    file: std.fs.File,
    allocator: std.mem.Allocator,

    pub fn open(name: []const u8, allocator: std.mem.Allocator) !Self {
        const file = try std.fs.cwd().createFile(name, .{
            .truncate = false,
            .read = true,
        });

        var self = Self{
            .map = std.StringHashMap([]const u8).init(allocator),
            .file = file,
            .allocator = allocator,
        };
        try self.reconstitute();
        return self;
    }

    pub fn close(self: *Self) void {
        self.file.close();

        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.setInmemory(
            try self.toOwned(key),
            try self.toOwned(value)
        );
        try self.writeHead(key.len, value.len);
        const key_bytes_written = try self.file.write(key);
        assert(key_bytes_written == key.len);
        const value_bytes_written = try self.file.write(value);
        assert(value_bytes_written == value.len);
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

    fn writeHead(self: *Self, key_size: u64, value_size: u64) !void {
        const head = Head{
            .timestamp = std.time.milliTimestamp(),
            .key_size = key_size,
            .value_size = value_size,
        };
        const bytes = @bitCast([@sizeOf(Head)]u8, head);
        const bytes_written = try self.file.write(bytes[0..]);
        assert(bytes_written == bytes.len);
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

