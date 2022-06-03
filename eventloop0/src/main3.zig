const std = @import("std");
const mem = std.mem;
const os = std.os;
const ArrayList = std.ArrayList;

fn call(comptime Context: type, context: Context, func: fn (Context) void) void {
    func(context);
}

const Foo = struct {
    message: []const u8,

    fn printHi(self: *Foo) void {
        _ = self;
        std.log.info("{s}", .{self.message});
    }

    fn runCall(self: *Foo) void {
        call(*Foo, self, printHi);
    }
};

pub fn main() anyerror!void {
    var foo = Foo{ .message = "hi!" };
    foo.runCall();
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
