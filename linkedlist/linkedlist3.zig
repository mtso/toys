const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn LinkedList(comptime Value: type) type {
    return struct{
        const Self = @This();

        const Node = struct {
            value: Value,
            next: ?*Node = null,
            prev: ?*Node = null,
        };

        const ListError = error{
            NotFound,
        };

        len: usize = 0,
        head: ?*Node = null,
        tail: ?*Node = null,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn insert(self: *Self, value: Value) !void {
            var node = try self.allocator.create(Node);
            node.* = .{ .value = value };
            self.len += 1;

            if (self.tail) |tail| {
                tail.next = node;
                node.prev = tail;
            } else {
                self.head = node;
            }

            self.tail = node;
        }

        pub fn removeLast(self: *Self) void {
            if (self.tail) |tail| {
                if (tail.prev) |prev| {
                    prev.next = null;
                    self.tail = prev;
                } else {
                    self.head = null;
                    self.tail = null;
                }
                self.allocator.destroy(tail);
                self.len -= 1;
            }
        }

        pub fn deinit(self: *Self) void {
            while (self.len > 0) {
                self.removeLast();
            }
        }
    };
}

test "with u128" {
    var ll = LinkedList(u128).init(std.testing.allocator);
    defer ll.deinit();

    try ll.insert(128);
    try ll.insert(256);
    try ll.insert(512);
}

test "with comptime strings" {
    var ll = LinkedList([]const u8).init(std.testing.allocator);
    defer ll.deinit();

    try ll.insert("128");
    try ll.insert("256");
    try ll.insert("512");
}

const TestNode = struct {
    value: u128,
};

test "with struct" {
    var nodes = try std.testing.allocator.alloc(TestNode, 3);
    defer std.testing.allocator.free(nodes);
    nodes[0] = .{ .value = 128 };
    nodes[1] = .{ .value = 256 };
    nodes[2] = .{ .value = 512 };

    var ll = LinkedList(TestNode).init(std.testing.allocator);
    defer ll.deinit();

    try ll.insert(nodes[0]);
    try ll.insert(nodes[1]);
    try ll.insert(nodes[2]);
}
