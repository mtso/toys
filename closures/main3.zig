const std = @import("std");

fn makeGreeter() fn () void {
    const greeting = "hi!";

    return struct {
        fn greet() void {
            std.log.info("greeting: {s}", .{ greeting });
        }
    }.greet;
}

pub fn main() anyerror!void {
    const greet = makeGreeter();

    greet();
    // > info: greeting: hi!
    // :O
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
