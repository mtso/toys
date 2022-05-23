const std = @import("std");
const rb = @import("rb.zig");
const assert = std.debug.assert;

const Number = struct {
    const Self = @This();

    node: rb.Node,
    value: u64,

    pub fn from(node: *rb.Node) *Self {
        return @fieldParentPtr(Self, "node", node);
    }

    pub fn order(l: *rb.Node, r: *rb.Node) std.math.Order {
        const left = Number.from(l);
        const right = Number.from(r);
        return std.math.order(left.value, right.value);
    }

    pub fn reverseOrder(l: *rb.Node, r: *rb.Node) std.math.Order {
        return std.math.Order.invert(Number.order(l, r));
    }
};

pub fn main() anyerror!void {
    var tree: rb.Tree = undefined;
    tree.init(Number.reverseOrder);
    var nodes: [5]Number = undefined;

    nodes[0].value = 0;
    nodes[1].value = 1;
    nodes[2].value = 2;
    nodes[3].value = 3;
    nodes[4].value = 4;

    _ = tree.insert(&nodes[4].node);
    _ = tree.insert(&nodes[0].node);
    _ = tree.insert(&nodes[1].node);
    _ = tree.insert(&nodes[2].node);
    _ = tree.insert(&nodes[3].node);

    var it = tree.iterator();
    while (it.next()) |node| {
        var value = Number.from(node).value;
        std.debug.print("{d}\n", .{ value });
    }
    it.reset();
    while (it.next()) |node| {
        var value = Number.from(node).value;
        std.debug.print("{d}\n", .{ value });
    }

    var first: ?*rb.Node = undefined;
    var last: ?*rb.Node = undefined;
    if (tree.first()) |node| {
        first = node;
    }
    if (tree.last()) |node | {
        last = node;
    }
    assert(first.?.next().?.next().?.next().?.next().? == last.?);
}
