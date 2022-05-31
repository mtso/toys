const std = @import("std");

pub fn main() anyerror!void {
    const greeting = "hi!";

    const greet = struct {
        fn greet() void {
            std.log.info("greeting: {s}", .{ greeting });
        }
    }.greet;

    greet();
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
