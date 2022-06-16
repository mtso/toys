const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const AutoArrayHashMap = std.AutoArrayHashMap;

fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: mem.Allocator,
        items: []T,
        refs: AutoArrayHashMap(*T, usize),

        pub fn init(allocator: mem.Allocator, size: usize) !Self {
            var items = try allocator.alloc(T, size);
            for (items) |*item| item.* = mem.zeroes(T);
            var refs = AutoArrayHashMap(*T, usize).init(allocator);
            try refs.ensureTotalCapacity(size);
            return Self{
                .allocator = allocator,
                .items = items,
                .refs = refs,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
            self.refs.deinit();
        }

        pub fn newRef(self: *Self) ?*T {
            for (self.items) |*ptr| {
                if (self.refs.contains(ptr)) continue;
                // error.OutOfMemory is unexpected because total capacity
                // is ensured at init.
                self.refs.put(ptr, 1) catch unreachable;
                return ptr;
            }
            return null;
        }

        pub fn ref(self: *Self, ptr: *T) !void {
            if (self.refs.get(ptr)) |n| {
                self.refs.put(ptr, n + 1) catch unreachable;
            } else {
                return error.InvalidRef;
            }
        }

        pub fn unref(self: *Self, ptr: *T) !void {
            if (self.refs.get(ptr)) |n| {
                if (n == 1) {
                    const removed = self.refs.swapRemove(ptr);
                    assert(removed);
                } else {
                    self.refs.put(ptr, n - 1) catch unreachable;
                }
            } else {
                return error.InvalidRef;
            }
        }

        pub fn refCount(self: *Self, ptr: *T) usize {
            return self.refs.get(ptr) orelse 0;
        }
    };
}

test "Pool" {
    var pool = try Pool([]const u8).init(std.testing.allocator, 4);
    defer pool.deinit();

    var ref1 = pool.newRef().?;
    ref1.* = "hi";

    try pool.ref(ref1);
    try std.testing.expectEqual(@as(usize, 2), pool.refCount(ref1));

    try pool.unref(ref1);
    try std.testing.expectEqual(@as(usize, 1), pool.refCount(ref1));

    // std.debug.print("{any}\n", .{ pool.items });
}
