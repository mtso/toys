const std = @import("std");
const mem = std.mem;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var pts: [5][]u8 = undefined;

    var pi: usize = 0;
    while (pi < 5) : (pi += 1) {
        var pt = &pts[pi];

        const start = std.time.milliTimestamp();
        const t = allocator.alloc(u8, 1000 * 1000 * 1000) catch |err| {
            std.log.err("failed: {any}", .{err});
            std.os.exit(1);
        };
        var i: usize = 0;
        while (i < 1000 * 1000 * 1000) : (i += 1000 * 1000) {
            const zeroes = std.mem.zeroes([1000 * 1000]u8);
            mem.copy(u8, t[i..i+1000*1000], zeroes[0..]);
        }
        pt.* = t;
        const diff = std.time.milliTimestamp() - start;
        std.log.info("t={p} len={any} elapsed={d}ms", .{ &t, t.len, diff });
    }
    // for (pts) |*pt| {
    //     const start = std.time.milliTimestamp();
    //     const t = allocator.alloc(u8, 1000 * 1000 * 1000) catch |err| {
    //         std.log.err("failed: {any}", .{err});
    //         std.os.exit(1);
    //     };
    //     var i: usize = 0;
    //     while (i < 1000 * 1000 * 1000) : (i += 1000 * 1000) {
    //         const zeroes = std.mem.zeroes([1000 * 1000]u8);
    //         mem.copy(u8, t[i..i+1000*1000], zeroes[0..]);
    //     }
    //     pt.* = t;
    //     const diff = std.time.milliTimestamp() - start;
    //     std.log.info("t={any} len={any} elapsed={d}ms", .{ &t, t.len, diff });
    // }

    // var chunk = try allocator.alloc(u8, 1000 * 1000 * 1000);
    // for (pts) |pt| {
    //     std.log.info("len={any}", .{ pt.len });
    // }

    for (pts) |*pt| {
        std.log.info("pt={any}", .{ pt });
        allocator.free(pt.*);
    }

    // const stdout = std.io.getStdOut().writer();
    // try stdout.print("greetings, {}!\n", .{"world"});
}
