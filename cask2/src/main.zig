const std = @import("std");

test "stringmap" {
    var map = std.StringHashMap([]const u8).init(std.testing.allocator);
    defer map.deinit();
    // REF https://github.com/ziglang/zig/blob/5c20c7036bebe443a22a4961ee8f2cd37f65a643/lib/std/hash_map.zig#L543
    try map.put("foo", "bar");

    const val = map.get("foo").?;
    const expect = std.testing.expect;

    try expect(std.mem.eql(u8, val, "bar"));
}

const DB = struct {
    const Self = @This();

    map: std.StringHashMap([]const u8),
    file: std.fs.File,

    pub fn open(name: []const u8, allocator: std.mem.Allocator) !Self {
        const file = try std.fs.cwd().createFile(name, .{
            .truncate = false,
            .read = true,
        });

        return Self{
            .map = std.StringHashMap([]const u8).init(allocator),
            .file = file,
        };
    }

    pub fn close(self: *Self) void {
        self.file.close();
        self.map.deinit();
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.map.put(key, value);
    }

    pub fn get(self: *Self, key: []const u8) ?[]const u8 {
       return self.map.get(key);
    }
};


pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();


    var db = try DB.open("foo.db", allocator);
    defer db.close();

    try db.set("hi", "boo");
    const value = db.get("hi").?;
    std.debug.assert(std.mem.eql(u8, value, "boo"));
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
