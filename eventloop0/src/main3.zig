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

fn printFoo() void {
    std.log.info("foo", .{});
}

fn printBar() void {
    std.log.info("bar", .{});
}

pub fn main() anyerror!void {
    var foo = Foo{ .message = "hi!" };
    foo.runCall();

    event_loop.set_timer(5000, printFoo);
    event_loop.set_timer(2000, printBar);
    // bar
    // foo

    while (event_loop.continue()) {
        event_loop.run();
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
