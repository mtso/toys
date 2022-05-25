const std = @import("std");
const ulid = @import("main.zig");
const time = std.time;

fn waitForNextMillis() void {
    var waitTime = time.milliTimestamp();
    while (time.milliTimestamp() == waitTime) continue;
}

const runFn = fn (usize) anyerror!i128;

fn nextHandler(iterations: usize) !i128 {
    var monotonicFactory = ulid.DefaultMonotonicFactory.init();
    var i: usize = 0;

    waitForNextMillis();

    const start = time.nanoTimestamp();
    std.log.info("START: ulid benchmark MonotonicFactory.next()", .{});
    while (i < iterations) {
        _ = try monotonicFactory.next();
        i += 1;
    }
    const diff = time.nanoTimestamp() - start;
    const diff_ms = @divTrunc(diff, 1000_000);
    const per_second = @divTrunc(iterations, diff_ms) * 1000;
    std.log.info("END iterations={d} diff={d}ms per_second={d}/s", .{ iterations, diff_ms, per_second });

    return diff_ms;
}

fn nextFillHandler(iterations: usize) !i128 {
    var monotonicFactory = ulid.DefaultMonotonicFactory.init();
    var i: usize = 0;

    waitForNextMillis();

    const start = time.nanoTimestamp();
    std.log.info("START: ulid benchmark MonotonicFactory.next()|Ulid.fillBase32()", .{});
    var buf: [26]u8 = undefined;
    while (i < iterations) {
        const id = try monotonicFactory.next();
        id.fillBase32(buf[0..]);
        i += 1;
    }
    const diff = time.nanoTimestamp() - start;
    const diff_ms = @divTrunc(diff, 1000_000);
    const per_second = @divTrunc(iterations, diff_ms) * 1000;
    std.log.info("END iterations={d} diff={d}ms per_second={d}/s", .{ iterations, diff_ms, per_second });

    return diff_ms;
}

pub fn main() anyerror!void {
    _ = try nextHandler(100_000_000);
    _ = try nextFillHandler(100_000_000);
}
