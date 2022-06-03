const std = @import("std");
const mem = std.mem;
const os = std.os;
const ArrayList = std.ArrayList;

fn call(comptime Context: type, context: Context, func: fn(Context, []const u8) void, message: []const u8) void {
    func(context, message);
}

const Foo = struct {
    fn printHi(self: *Foo, message: []const u8) void {
        _ = self;
        std.log.info("{s}", .{ message });
    }

    fn runCall(self: *Foo) void {
        call(*Foo, self, printHi, "hi!");
    }
};

pub fn main() anyerror!void {
    var foo = Foo{};
    foo.runCall();
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
