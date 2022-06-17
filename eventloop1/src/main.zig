const std = @import("std");
const ArrayList = std.ArrayList;
const Queue = @import("queue.zig").Queue;

const EventLoop = struct {
    timers: Queue(Timeout) = .{},
    ticks: u64 = 0,
    tasks: u64 = 0,

    const Timeout = struct {
        expire_time: i64,
        context: *anyopaque,
        callback: fn (*Timeout) void,
        next: ?*Timeout,
    };

    pub fn setTimeout(self: *EventLoop, delay: i64, timeout: *Timeout, comptime Context: type, context: Context, comptime callback: fn (Context) void) void {
        self.tasks += 1;

        const wrapped_callback = struct {
            fn callback(_timeout: *Timeout) void {
                const typed_context = @intToPtr(Context, @ptrToInt(_timeout.context));
                callback(typed_context);
            }
        }.callback;

        timeout.* = .{
            .expire_time = std.time.milliTimestamp() + delay,
            .context = context,
            .callback = wrapped_callback,
            .next = null,
        };

        self.timers.push(timeout);
    }

    pub fn hasTasks(self: *EventLoop) bool {
        return self.timers.peek() != null;
    }

    pub fn tick(self: *EventLoop) void {
        self.ticks += 1;

        // A temporary reference to the list of timers
        // is held because callbacks may add tasks and mutate the queue
        // while we are evaluating the outstanding ones.
        var timers = self.timers;
        self.timers = .{};

        while (timers.pop()) |timeout| {
            // If the expire time has passed the current time,
            // execute the callback.
            if (std.time.milliTimestamp() >= timeout.expire_time) {
                timeout.callback(timeout);
            } else {
                // Otherwise, add the timeout back into the queue at the end.
                self.timers.push(timeout);
            }
        }
    }
};

const DelayedPrinter = struct {
    start: i64,
    message: []const u8,
    timeout: EventLoop.Timeout = undefined,

    fn schedule(self: *DelayedPrinter, event_loop: *EventLoop, delay: i64) void {
        event_loop.setTimeout(delay, &self.timeout, *DelayedPrinter, self, onTimeout);
    }

    fn onTimeout(self: *DelayedPrinter) void {
        const elapsed = std.time.timestamp() - self.start;
        std.log.info("({d}s) {s}", .{ elapsed, self.message });
    }
};

pub fn main() anyerror!void {
    var event_loop = EventLoop{};
    const start = std.time.timestamp();

    std.log.info("scheduling tasks...", .{});

    var printer1 = DelayedPrinter{ .message = "hi", .start = start };
    printer1.schedule(&event_loop, 2000);
    var printer2 = DelayedPrinter{ .message = "hello", .start = start };
    printer2.schedule(&event_loop, 4000);
    var printer3 = DelayedPrinter{ .message = "hello, world!", .start = start };
    printer3.schedule(&event_loop, 6000);

    std.log.info("running event loop...", .{});

    while (event_loop.hasTasks()) {
        event_loop.tick();
    }

    std.log.info("event loop has no more tasks, bye!", .{});
    std.log.info("stats ticks={d} tasks={d}", .{ event_loop.ticks, event_loop.tasks });
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
