const std = @import("std");
const mem = std.mem;

// Follows FIFO: First In First Out
//     Insertion can take place from the rear end.
//     Deletion can take place from the front end.
//     Eg: queue at ticket counters, bus station
// 4 major operations:
//     enqueue(ele) – used to insert element at top
//     dequeue() – removes the top element from queue 
//     peekfirst() – to get the first element of the queue 
//     peeklast() – to get the last element of the queue 
// All operation works in constant time i.e, O(1)
// Advantages
//     Maintains data in FIFO manner
//     Insertion from beginning and deletion from end takes O(1) time

// Queue(u64){
//     .allocator = Allocator{ .ptr = anyopaque@16ba3efb8, .vtable = VTable{ .alloc = fn(*anyopaque, usize, u29, u29, usize) std.mem.Allocator.Error![]u8@1043c4eec, .resize = fn(*anyopaque, []u8, u29, usize, u29, usize) ?usize@1043c4fbc, .free = fn(*anyopaque, []u8, u29, usize) void@1043c507c } },
//     .head = null,
//     .tail = null
// }

// .head = Node{ .value = 42, .next = null },
// .tail = Node{ .value = 42, .next = null } }

// .head = Node{ .value = 36, .next = Node{ .value = 42, .next = null } },
// .tail = Node{ .value = 42, .next = null } }

fn Queue(comptime T: anytype) type {
    return struct {
        const Self = @This();

        const Node = struct {
            value: T,
            prev: ?*Node,
        };

        allocator: mem.Allocator,
        head: ?*Node = null,
        tail: ?*Node = null,

        pub fn enqueue(self: *Self, value: T) !void {
            // const ref = try allocator.create(T);
            // allocator.destroy(ref)
            // const ref = try allocator.alloc(T, length);
            // allocator.free(ref)

            var newNode: *Node = try self.allocator.create(Node);
            errdefer self.allocator.destroy(newNode);

            newNode.* = .{
                .value = value,
                .prev = null,
            };

            if (self.head) |head| {
                head.prev = newNode;
            }

            self.head = newNode;

            if (null == self.tail) {
                self.tail = newNode;
            }
        }

        // head v                tail v
        // [3, -> ] [ 2, -> ] [ 1, -> ]    return value is 1
        //
        // head v      tail v
        // [3, -> ] [ 2, -> ]

        // head v                tail v
        // [3, <- ] [ 2, <- ] [ 1, <- ]    return value is 1
        //
        // head v     tail v
        // [3, <- ] [ 2, <- ]    return value is 1

        // head v   tail v
        // [ 2, <-          ]       return value is 2

        pub fn dequeue(self: *Self) ?T {
            if (self.peekFirst()) |v| {
                var nodeToRemove: ?*Node = self.tail;
                self.tail = nodeToRemove.?.prev;
                self.allocator.destroy(nodeToRemove.?);
                // in the case where this element was the last one
                // update head
                if (null == self.tail) {
                    self.head = null;
                }

                return v;
            } else {
                return null;
            }
        }

        pub fn peekFirst(self: *Self) ?T {
            return if (self.tail) |tail| tail.value else null;
        }

        // pub fn peekFirstPtr(self: *Self) ?*Node {
        //     return self.tail;
        // }
    };
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var queue = Queue(u64){ .allocator = allocator };
    std.debug.print("{any}\n", .{ queue.peekFirst() });
    std.debug.print("{any} == null\n", .{ queue.dequeue() });

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    // first-in [1, 2, 3]
    //           ^

    // std.debug.print("{any}\n", .{ queue });
    std.debug.print("{any}\n", .{ queue.peekFirst() });
    std.debug.print("{any} == 1\n", .{ queue.dequeue() });
    std.debug.print("{any} == 2\n", .{ queue.dequeue() });
    std.debug.print("{any} == 3\n", .{ queue.dequeue() });
    std.debug.print("{any} == null\n", .{ queue.dequeue() });
    std.debug.print("{any} == null\n", .{ queue.dequeue() });
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
