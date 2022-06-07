const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

const EventLoop = struct {
    // allocator: mem.Allocator,
    queue: ArrayList(Callback),
    elapsed: i64,
    start: i64,
    previous: i64,

    const Callback = struct {
        // func: fn (*anyopaque) void,
        delay: i64,
        from: i64,
        context: ?*anyopaque,
        func: fn(*EventLoop, Callback) void,
    };

    pub fn setTimer(
        self: *EventLoop,
        delay: i64,
        comptime Context: anytype,
        context: Context,
        comptime func: fn(context: Context, callback: Callback) void,
    ) !void {
        const callbackFn = struct {
            fn onCall(_: *EventLoop, _callback: Callback) void {
                if (_callback.context) |_| {
                    func(@intToPtr(Context, @ptrToInt(_callback.context.?)), _callback);
                }
            }
        }.onCall;

        try self.queue.append(EventLoop.Callback{
            .delay = delay,
            .from = std.time.milliTimestamp(),
            .context = context,
            .func = callbackFn,
        });
        // std.debug.print("append {d}\n", .{ self.queue.items.len });
        assert(self.queue.items.len >= 0);
    }

    pub fn shouldContinue(self: *EventLoop) bool {
        // std.debug.print("shouldContinue {d}\n", .{ self.queue.items.len });
        return self.queue.items.len > 0;
    }

    pub fn run(self: *EventLoop) void {
        const now = std.time.milliTimestamp();
        const diff = now - self.previous;
        self.elapsed += diff;
        self.previous = now;

        if (self.queue.items.len > 0) {
            const callback = self.queue.orderedRemove(0);
            const execTime = callback.from + callback.delay;
            if (execTime <= self.start + self.elapsed) {
                callback.func(self, callback);
            } else {
                self.queue.append(callback) catch {
                    @panic("failed to append callback!");
                };
            }
        }
    }
};

fn printFoo() void {
    std.log.info("foo", .{});
}

fn printBar() void {
    std.log.info("bar", .{});
}

const User1 = struct {
    counter: i64,
    messages: ArrayList([]const u8),
    event_loop: EventLoop,

    pub fn testRun(self: *User1) !void {
        self.counter += 1;
        while (self.counter <= 3) : (self.counter += 1) {
            std.debug.print("setting timer {d}\n", .{ self.counter });
            try self.messages.append("hi");
            try self.event_loop.setTimer(self.counter * 1000, *User1, self, printNext);
        }

        std.debug.print("event loop: {d}\n", .{ self.event_loop.queue.items.len });
        assert(self.event_loop.queue.items.len == 3);
    }

    fn printNext(self: *User1, _: EventLoop.Callback) void {
        const message = self.messages.popOrNull();
        std.log.info("{} printNext message: {s}", .{ std.time.timestamp(), message });
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var queue = ArrayList(EventLoop.Callback).init(allocator);
    defer queue.deinit();
    var event_loop = EventLoop{
        .queue = queue,
        .elapsed = 0,
        .start = std.time.milliTimestamp(),
        .previous = std.time.milliTimestamp(),
    };

    var user = User1 {
        .counter = 0,
        .messages = ArrayList([]const u8).init(allocator),
        .event_loop = event_loop,
    };

    try user.testRun();

    std.debug.print("user ev {*}\n", .{ &user.event_loop.queue });
    std.debug.print("ev {*}\n", .{ &event_loop.queue });

    assert(user.event_loop.queue.items.len == 3);

    // try event_loop.setTimer(5000, printFoo);
    // try event_loop.setTimer(2000, printBar);

    while (user.event_loop.shouldContinue()) {
        user.event_loop.run();
    }
    // while (event_loop.shouldContinue()) {
    //     event_loop.run();
    // }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
