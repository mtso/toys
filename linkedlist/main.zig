
const std = @import("std");
const list = @import("./list.zig");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const l = list.LinkedList.init();
    l.size = 3;
    try stdout.print("list {d}\n", .{ l.size });
}
