const std = @import("std");
const mem = std.mem;
const math = std.math;

fn Tree(comptime T: anytype, compareFn: fn (anytype, anytype) math.Order) type {
    return struct {
        const Self = @This();

        const Node = struct {
            value: T,
            left: ?*Node,
            right: ?*Node,
        };

        allocator: mem.Allocator,
        root: ?*Node,
        len: usize,

        pub fn init(allocator: mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .root = null,
                .len = 0,
            };
        }

        pub fn deinit(self: Self) void {
            if (self.root) |root| {
                self.deinitNode(root);
            }
        }

        fn deinitNode(self: Self, node: *Node) void {
            if (node.left) |left| {
                self.deinitNode(left);
            }
            if (node.right) |right| {
                self.deinitNode(right);
            }
            self.allocator.destroy(node);
        }

        pub fn insert(self: *Self, value: T) !void {
            var node = try self.allocator.create(Node);
            node.* = Node{
                .value = value,
                .left = null,
                .right = null,
            };
            defer self.len += 1;

            if (self.root) |rootNode| {
                // compare rootNode value and our new value
                // add to left or right properties in the rootNode
                var curr: ?*Node = rootNode;

                while (true) {
                    if (compareFn(curr.?.value, value) == .lt) {
                        if (curr.?.right) |rightNode| {
                            curr = rightNode;
                        } else {
                            curr.?.right = node;
                            return;
                        }
                    } else {
                        if (curr.?.left) |leftNode| {
                            curr = leftNode;
                        } else {
                            curr.?.left = node;
                            return;
                        }
                    }
                }
            } else {
                self.root = node;
            }
        }

        pub fn get(self: *Self, value: T) ?T {
            if (self.root) |rootNode| {
                // compare rootNode value and our new value
                // add to left or right properties in the rootNode
                var curr: ?*Node = rootNode;

                while (true) {
                    switch (compareFn(curr.?.value, value)) {
                        .eq => return curr.?.value,
                        .lt => {
                            if (curr.?.right) |right| {
                                curr = right;
                            } else {
                                return null;
                            }
                        },
                        .gt => {
                            if (curr.?.left) |left| {
                                curr = left;
                            } else {
                                return null;
                            }
                        },
                    }
                }
            } else {
                return null;
            }
        }

        pub fn removeAll(self: *Self) void {
            if (self.root) |root| {
                self.removeNode(root);
                self.root = null;
            }
        }

        fn removeNode(self: *Self, n: ?*Node) void {
            if (n) |node| {
                if (node.left) |left| {
                    self.removeNode(left);
                    node.left = null;
                }
                if (node.right) |right| {
                    self.removeNode(right);
                    node.right = null;
                }
                self.allocator.destroy(node);
                self.len -= 1;
            }
        }

        pub fn tryCompare(_: Self, a: T, b: T) math.Order {
            return compareFn(a, b);
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = value;
            _ = fmt;
            _ = options;
            // TODO traverse the nodes and print
            _ = try writer.write("I'm a tree");
        }
    };
}

test "inserts" {
    var tree = Tree(u128, std.math.order).init(std.testing.allocator);
    defer tree.deinit();
    try tree.insert(5);
    try tree.insert(6);

    try std.testing.expectEqual(@as(usize, 2), tree.len);

    const value = tree.get(6);
    try std.testing.expectEqual(@as(u128, 6), value.?);
    try std.testing.expectEqual(@as(usize, 2), tree.len);

    tree.removeAll();
    try std.testing.expectEqual(@as(usize, 0), tree.len);
    try std.testing.expect(null == tree.root);

    try tree.insert(4);
    try tree.insert(1);
    try tree.insert(2);
    try tree.insert(10);
    try tree.insert(17);
    try tree.insert(7);
    std.debug.print("{any}\n", .{tree.root});
}

const Entry = struct {
    key: u128,
    value: u128,
};

fn entryOrder(a: anytype, b: anytype) math.Order {
    return std.math.order(a.key, b.key);
}

test "with value" {
    var entries = [_]Entry{
        .{ .key = 1, .value = 2 },
    };

    var tree = Tree(Entry, entryOrder).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(entries[0]);

    const entry = tree.get(.{ .key = 1, .value = undefined });
    try std.testing.expectEqual(@as(u128, 2), entry.?.value);
}

fn couldBeTruthy() ?bool {
    // return null;
    return false;
}

//
// var tree = Tree(???).init(allocator);
// try tree.insert(???);
//
pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var tree = Tree(u128, std.math.order).init(allocator);
    try tree.insert(5);
    try tree.insert(6);

    // const comparison = tree.tryCompare(1, 2);
    if (tree.root) |node| {
        std.debug.print("result: {any}\n", .{node.value});
        if (node.right) |node2| {
            std.debug.print("result2: {any}\n", .{node2.value});
        }
    }

    // const result = couldBeTruthy();
    // if (result) |unwrapped| {
    //     std.debug.print("result: {any}\n", .{ unwrapped });
    // } else {
    //     std.debug.print("unreachable?\n", .{});
    // }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
