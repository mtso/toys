const std = @import("std");

const PriorityDequeue = std.PriorityDequeue;

const Entry = struct {
    key: u128,
    value: u128,
};

fn lessThanComparison(context: void, a: Entry, b: Entry) std.math.Order {
    _ = context;
    return std.math.order(a.key, b.key);
}

const NumDQ = PriorityDequeue(Entry, void, lessThanComparison);

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var q = NumDQ.init(allocator, {});
    defer q.deinit();

    try q.add(Entry{ .key = 1, .value = 1 });
    try q.add(Entry{ .key = 3, .value = 3 });
    try q.add(Entry{ .key = 2, .value = 2 });

    var iter = q.iterator();
    while (iter.next()) |e| {
        std.debug.print("k:{d} v:{d}\n", .{
            e.key, e.value,
        });
    }
}
