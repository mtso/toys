pub fn Queue(comptime T: anytype) type {
    return struct {
        const Self = @This();

        in: ?*T = null,
        out: ?*T = null,

        pub fn push(self: *Self, item: *T) void {
            item.next = null;
            if (self.in != null) {
                self.in.?.next = item;
                self.in = item;
            } else {
                self.in = item;
                self.out = item;
            }
        }

        pub fn pop(self: *Self) ?*T {
            if (self.out != null) {
                const out = self.out;
                self.out = out.?.next;
                if (out == self.in) {
                    self.in = null;
                }
                return out;
            }
            return null;
        }

        pub fn peek(self: *Self) ?*T {
            return self.out;
        }
    };
}

const Foo = struct {
    value: u64,
    next: ?*Foo,
};

test "insert" {
    const std = @import("std");

    var fifo = Queue(Foo){};

    var foo1 = Foo{ .value = 1, .next = null };
    var foo2 = Foo{ .value = 2, .next = null };

    fifo.push(&foo1);
    fifo.push(&foo2);

    const f1 = fifo.pop();
    try std.testing.expectEqual(@as(u64, 1), f1.?.value);
    const f2 = fifo.pop();
    try std.testing.expectEqual(@as(u64, 2), f2.?.value);
    const f3 = fifo.pop();
    try std.testing.expect(null == f3);
    try std.testing.expectEqual(@as(?*Foo, null), f3);
}
