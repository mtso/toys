const std = @import("std");
const ArrayList = std.ArrayList;

const EventLoop = struct {
    queue: ArrayList(Callback),
    elapsed: i64,
    start: i64,
    previous: i64,

    const Callback = struct {
        func: fn () void,
        delay: i64,
        from: i64,
    };

    pub fn setTimer(self: *EventLoop, delay: i64, func: fn () void) !void {
        try self.queue.append(.{
            .func = func,
            .delay = delay,
            .from = std.time.milliTimestamp(),
        });
    }

    pub fn shouldContinue(self: *EventLoop) bool {
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
            // std.debug.print("start={} elapsed={} currentT={} callbackFrom={} callbackDelay={} callbackExecTime={}\n", .{
            //     self.start,
            //     self.elapsed,
            //     self.start + self.elapsed,
            //     callback.from,
            //     callback.delay,
            //     execTime,
            // });
            if (execTime <= self.start + self.elapsed) {
                callback.func();
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

    try event_loop.setTimer(5000, printFoo);
    try event_loop.setTimer(2000, printBar);

    while (event_loop.shouldContinue()) {
        event_loop.run();
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
