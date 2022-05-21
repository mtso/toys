const std = @import("std");

test "test map" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap([]const u8).init(allocator);

    const key = "foo";
    const key2 = "fooz";
    const k = try allocator.alloc(u8, key.len);
    std.mem.copy(u8, k, key);
    //allocator.free(k);

    defer map.deinit();
    try map.put(k, "bar");
    try map.put(key2, "bar");

    if (map.getKeyPtr(key2)) |kp| {
        allocator.free(kp.*);
    }

    if (map.getKeyPtr(k)) |kp| {
        allocator.free(kp.*);
    }
}

pub fn main() anyerror!void {
    // Note that info level log messages are by default printed only in Debug
    // and ReleaseSafe build modes.
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
