const std = @import("std");
const ArrayList = std.ArrayList;
const Queue = @import("queue.zig").Queue;

// An event loop which allows callers to schedule timeouts to delay
// the execution of callback functions to a future point in time.
const EventLoop = struct {
    timers: Queue(Timeout) = .{},
    ticks: u64 = 0,
    tasks: u64 = 0,

    const Timeout = struct {
        expire_time: i64,
        // A pointer reference to the struct that will be passed back to the callback.
        context: *anyopaque,
        callback: fn (*Timeout) void,
        // The reference to the next node as specified by the Queue data structure.
        next: ?*Timeout,
    };

    // - The Timeout is passed in by the caller so that the timeout remains on the stack
    //   for as long as the caller is also on the stack.
    // - The Context type declares the type of the calling struct and is used
    //   to convert the type-erased pointer back into the correct type
    //   for invoking the callback function with.
    pub fn setTimeout(self: *EventLoop, delay: i64, timeout: *Timeout, comptime Context: type, context: Context, comptime callback: fn (Context) void) void {
        self.tasks += 1;

        // The expire time is set based on the delay from the current timestamp.
        // A negative or zero delay will be executed immediately on the next tick
        // of the event loop.
        const expire_time = std.time.milliTimestamp() + delay;

        // This wrapper struct allows timeouts to be queued for
        // functions with different type signatures.
        const typed_callback = struct {
            fn wrapped(_timeout: *Timeout) void {
                // The type-erased pointer "*anyopaque" is
                // converted into usize and then back into a pointer
                // that matches the Context type.
                const typed_context = @intToPtr(Context, @ptrToInt(_timeout.context));
                callback(typed_context);
            }
        }.wrapped;

        timeout.* = .{
            .expire_time = expire_time,
            .context = context,
            .callback = typed_callback,
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
                // timeout.callback : fn(*Timeout) void
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
    // A reference to a Timeout struct is held on the stack for the event loop.
    timeout: EventLoop.Timeout = undefined,

    fn schedule(self: *DelayedPrinter, event_loop: *EventLoop, delay: i64) void {
        // onTimeout contains a reference to this instance of DelayedPrinter,
        // which contains the message, so the context must be set to *DelayedPrinter.
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
