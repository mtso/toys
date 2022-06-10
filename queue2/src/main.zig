const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

/// A first-in, first-out queue for signed integers.
/// - enqueue: adds a number to the end of the queue
/// - dequeue: removes and returns the number at the beginning if it exists
/// - peekFirst: returns the first number
/// - peekLast: returns the last number
///
/// Queue with 3 elements. Elements are enqueued at the end, and then
/// removed from the front.
/// ===
///   first                                 last
///     v                                    v
///   node1              node2              node3
///   [ value, next ] -> [ value, next ] -> [ value, next: NULL ]
const IntQueue = struct {
    const IntNode = struct {
        value: i32,
        next: ?*IntNode,
    };

    allocator: mem.Allocator,
    first: ?*IntNode,
    last: ?*IntNode,

    fn init(allocator: mem.Allocator) IntQueue {
        return .{
            .allocator = allocator,
            .first = null,
            .last = null,
        };
    }

    fn deinit(self: *IntQueue) void {
        while (self.first) |_| _ = self.dequeue();
    }

    /// Queue with 0 elements
    /// ===
    ///   first  last
    ///    v      v
    ///   NULL   NULL
    ///
    ///
    /// Queue with 1 element
    /// ===
    ///   first  last
    ///    v      v
    ///   [ value, next: NULL ]
    ///
    /// Queue with 3 elements
    /// ===
    ///   first                                 last
    ///     v                                    v
    ///   node1              node2              node3
    ///   [ value, next ] -> [ value, next ] -> [ value, next: NULL ]
    ///
    fn enqueue(self: *IntQueue, value: i32) !void {
        var node = try self.allocator.create(IntNode);
        node.* = .{
            .value = value,
            .next = null,
        };

        if (self.last) |last| {
            last.next = node;
            self.last = node;
        } else {
            self.last = node;
            self.first = node;
        }
    }

    fn dequeue(self: *IntQueue) ?i32 {
        const first = if (self.first) |first| first else return null;
        const value = first.value;
        self.first = first.next;

        // When the queue has 1 node:
        // ===
        //   first  last
        //    v      v
        //   [ number, next: NULL ]
        //
        // If both first and last point to the same node,
        // the queue is emptied out into initial state
        // by ensuring both first and last pointers are NULL.
        if (self.last == first) {
            self.last = null;
            assert(self.first == null);
        }
        self.allocator.destroy(first);
        return value;
    }

    fn peekFirst(self: *IntQueue) ?i32 {
        return if (self.first) |first| first.value else null;
    }

    fn peekLast(self: *IntQueue) ?i32 {
        return if (self.last) |last| last.value else null;
    }
};

test "IntQueue" {
    var queue = IntQueue.init(std.testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    try std.testing.expectEqual(@as(i32, 1), queue.peekFirst().?);
    try std.testing.expectEqual(@as(i32, 3), queue.peekLast().?);
    try std.testing.expectEqual(@as(i32, 1), queue.dequeue().?);
}

test "IntQueue deinit" {
    var queue = IntQueue.init(std.testing.allocator);
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    queue.deinit();
    queue.deinit();
}

/// The Queue data structure is a first-in, first-out list.
/// Meaning that items that are added first, are also
/// removed first (before items added afterwards).
///
/// Queue data structure provides:
/// - enqueue: adds an element to the end
/// - dequeue: removes and returns the element at the head if it exists
/// - peekFirst: returns the first value
/// - peekLast: returns the last value
/// Additional methods:
/// - isEmpty: returns true if there are no elements in the queue
/// - size: returns the number of elements in the queue, O(n) runtime!
fn Queue(comptime T: type) type {
    return struct {
        const Node = struct {
            value: T,
            next: ?*Node,
        };

        allocator: mem.Allocator,
        first: ?*Node,
        last: ?*Node,

        fn init(allocator: mem.Allocator) Queue(T) {
            return .{
                .allocator = allocator,
                .first = null,
                .last = null,
            };
        }

        fn deinit(self: *Queue(T)) void {
            while (self.first) |_| _ = self.dequeue();
        }

        fn enqueue(self: *Queue(T), value: T) !void {
            var node = try self.allocator.create(Node);
            node.* = .{
                .value = value,
                .next = null,
            };

            if (self.last) |last| {
                last.next = node;
                self.last = node;
            } else {
                self.last = node;
                self.first = node;
            }
        }

        fn dequeue(self: *Queue(T)) ?T {
            const first = if (self.first) |first| first else return null;
            const value = first.value;
            self.first = first.next;

            // Queue with 1 element
            // ===
            //   first  last
            //    v      v
            //   [ value, next: NULL ]
            //
            // If both first and last point to the same node,
            // the queue is emptied out into initial state
            // by ensuring both first and last pointers are NULL.
            if (self.last == first) {
                self.last = null;
                assert(self.first == null);
            }
            self.allocator.destroy(first);
            return value;
        }

        fn peekFirst(self: *Queue(T)) ?T {
            return if (self.first) |first| first.value else null;
        }

        fn peekLast(self: *Queue(T)) ?T {
            return if (self.last) |last| last.value else null;
        }

        /// Extra
        fn isEmpty(self: *Queue(T)) bool {
            return self.first == null;
        }

        fn size(self: *Queue(T)) usize {
            var _size: usize = 0;
            var cursor: ?*Node = self.first;
            while (cursor) |node| : (cursor = node.next) _size += 1;
            return _size;
        }
    };
}

test "queue" {
    var queue = Queue(u32).init(std.testing.allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    try std.testing.expectEqual(@as(u32, 1), queue.peekFirst().?);
    try std.testing.expectEqual(@as(u32, 3), queue.peekLast().?);
    try std.testing.expectEqual(@as(u32, 1), queue.dequeue().?);
}

test "deinit" {
    var queue = Queue(u32).init(std.testing.allocator);
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    queue.deinit();
    queue.deinit();
}

test "isEmpty" {
    var queue = Queue(u32).init(std.testing.allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());

    try queue.enqueue(1);
    try std.testing.expect(!queue.isEmpty());
}

test "size" {
    var queue = Queue(u32).init(std.testing.allocator);
    defer queue.deinit();

    try std.testing.expectEqual(@as(usize, 0), queue.size());

    try queue.enqueue(1);
    try std.testing.expectEqual(@as(usize, 1), queue.size());

    try queue.enqueue(2);
    try queue.enqueue(3);
    try std.testing.expectEqual(@as(usize, 3), queue.size());

    _ = queue.dequeue();
    try std.testing.expectEqual(@as(usize, 2), queue.size());
}
