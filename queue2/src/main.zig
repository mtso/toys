const std = @import("std");
const mem = std.mem;

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
            if (self.last == first) self.last = null;
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
