const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const AutoArrayHashMap = std.AutoArrayHashMap;

const IntPtrMap = AutoArrayHashMap(*u32, usize);

const IntPool = struct {
    allocator: mem.Allocator,
    ints: []u32,
    refs: IntPtrMap,

    pub fn init(allocator: mem.Allocator, size: usize) !IntPool {
        var ints = try allocator.alloc(u32, size);
        for (ints) |*int| int.* = 0;

        var refs = IntPtrMap.init(allocator);
        try refs.ensureTotalCapacity(size);
        return IntPool{
            .ints = ints,
            .refs = refs,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IntPool) void {
        self.allocator.free(self.ints);
        self.refs.deinit();
    }

    pub fn get(self: *IntPool) ?*u32 {
        for (self.ints) |*int| {
            if (self.refs.contains(int)) continue;
            self.refs.put(int, 1) catch return null;
            return int;
        }
        return null;
    }

    pub fn ref(self: *IntPool, ptr: *u32) !void {
        if (self.refs.get(ptr)) |n| {
            self.refs.put(ptr, n + 1) catch unreachable;
        } else {
            return error.InvalidRef;
        }
    }

    pub fn unref(self: *IntPool, ptr: *u32) !void {
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

    pub fn refCount(self: *IntPool, ptr: *u32) usize {
        if (self.refs.get(ptr)) |n| {
            return n;
        } else {
            return 0;
        }
    }

    pub fn refed(self: *IntPool, ptr: *u32) bool {
        return self.refs.contains(ptr);
    }
};

test "IntPool" {
    var pool = try IntPool.init(std.testing.allocator, 4);
    defer pool.deinit();

    const int0 = pool.get();
    try std.testing.expect(int0 != null);
    try std.testing.expect(pool.refed(int0.?));
    try pool.unref(int0.?);

    const int1 = pool.get();
    try std.testing.expect(int1 != null);
    const int2 = pool.get();
    try std.testing.expect(int2 != null);
    const int3 = pool.get();
    try std.testing.expect(int3 != null);
    const int4 = pool.get();
    try std.testing.expect(int4 != null);
    const int5 = pool.get();
    try std.testing.expectEqual(@as(?*u32, null), int5);

    try pool.ref(int4.?);
    try std.testing.expectEqual(@as(usize, 2), pool.refCount(int4.?));
}
