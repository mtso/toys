const std = @import("std");

fn Queue(comptime Node: type) type {
    return struct {
        first: ?*Node,
        last: ?*Node,

        fn enqueue(self: *Queue(Node), node: *Node) void {
            if (self.last) |last| {
                last.next = node;
                self.last = node;
            } else {
                self.first = node;
                self.last = node;
            }
        }

        fn dequeue(self: *Queue(Node)) ?*Node {
            const node = if (self.first) |first| first else return null;
            self.first = node.next;
            if (node == self.last) self.last = null;
            return node;
        }

        fn peekFirst(self: *Queue(Node)) ?*Node {
            return self.first;
        }
    };
}

const Element = struct {
    value: i32,
    next: ?*Element,
};

test "Queue" {
    var el1 = Element{ .value = 1, .next = null };
    var el2 = Element{ .value = 2, .next = null };
    var queue = Queue(Element){ .first = null, .last = null };
    queue.enqueue(&el1);
    queue.enqueue(&el2);
    try std.testing.expectEqual(@as(i32, 1), queue.peekFirst().?.value);

    const deq1 = queue.dequeue();
    try std.testing.expectEqual(@as(i32, 1), deq1.?.value);
    const deq2 = queue.dequeue();
    try std.testing.expectEqual(@as(i32, 2), deq2.?.value);
    const deq3 = queue.dequeue();
    try std.testing.expectEqual(@as(?*Element, null), deq3);
}
