const std = @import("std");

const Counter = struct {
    const Self = @This();

    i: u32 = 0,

    fn incrementAndGet(self: *Self) u32 {
        self.i += 1;
        return self.i;
    }
};

fn makeCounter(state: *Counter) fn () u32 {
    return struct {
        fn incrementAndGet() u32 {
            state.i += 1;
            return state.i;
        }
    }.incrementAndGet;
}

// fn makeCounter(allocator: std.mem.Allocator) !@Frame(Counter.incrementAndGet) {//} fn () u32 {
//     const frame = try std.heap.page_allocator.create(@Frame(Counter.incrementAndGet));
//     var counter = try allocator.create(Counter);
//     frame.* = async counter.incrementAndGet();
//     return frame.*;
// }

pub fn main() anyerror!void {
    var counter = Counter{};
    const incrementAndGet = makeCounter(&counter);
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // // var allocator = gpa.allocator();
    // var incrementAndGet = try makeCounter(gpa.allocator());
    // std.debug.print("whatisthis: {any}\n", .{ incrementAndGet });
    // var incrementAndGet = makeCounter();

    // const n1 = counter.incrementAndGet();
    std.log.info("n: 1=={d}", .{ incrementAndGet() });
    std.log.info("n: 2=={d}", .{ incrementAndGet() });

    // greet();
    // > info: greeting: hi!
    // :O
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
