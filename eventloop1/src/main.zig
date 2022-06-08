const std = @import("std");
const ArrayList = std.ArrayList;
const Fifo = @import("fifo.zig").Fifo;

const EventLoop = struct {
    timers: Fifo(Callback) = .{},

    const Callback = struct {
        start: i64,
        delay: i64,
        context: ?*anyopaque,
        callback: fn (*EventLoop, *Callback) void,
        next: ?*Callback,
    };

    pub fn setTimer(self: *EventLoop, delay: i64, callback: *Callback, comptime Context: type, context: Context, comptime func: fn (Context, *Callback) void) void {
        const callbackFn = struct {
            fn onCall(_: *EventLoop, _callback: *Callback) void {
                func(@intToPtr(Context, @ptrToInt(_callback.context.?)), _callback);
            }
        }.onCall;

        callback.* = .{
            .start = std.time.milliTimestamp(),
            .delay = delay,
            .context = context,
            .callback = callbackFn,
            .next = null,
        };

        self.timers.push(callback);
    }

    pub fn shouldContinue(self: *EventLoop) bool {
        return self.timers.peek() != null;
    }

    pub fn tick(self: *EventLoop) void {
        const top = self.timers.pop();
        var next = top;

        while (next) |callback| {
            if (self.timers.peek() == top) break else next = self.timers.pop();
            const expires = callback.start + callback.delay;
            if (expires > std.time.milliTimestamp()) {
                self.timers.push(callback);
            } else {
                callback.callback(self, callback);
            }
        }
    }

    pub fn run(self: *EventLoop) void {
        while (self.shouldContinue()) self.tick();
    }
};

const User1 = struct {
    callCount: u64 = 0,
    callback: EventLoop.Callback = undefined,
    event_loop: *EventLoop,

    pub fn setupTimers(self: *User1) !void {
        self.event_loop.setTimer(5000, &self.callback, *User1, self, print);
    }

    fn print(self: *User1, _: *EventLoop.Callback) void {
        self.callCount += 1;
        std.log.info("{} message n: {d}", .{ std.time.timestamp(), self.callCount });

        self.event_loop.setTimer(5000, &self.callback, *User1, self, print);
    }
};

pub fn main() anyerror!void {
    var event_loop = EventLoop{};
    var user = User1{ .event_loop = &event_loop };

    try user.setupTimers();
    event_loop.run();
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
