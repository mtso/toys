const std = @import("std");
const rb = @import("rb.zig");

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
};

pub fn main() anyerror!void {
    var tree: rb.Tree = undefined;
    tree.init(Number.order);

    var n = Number{
        .node = undefined,
        .value = 1,
    };

    _ = tree.insert(&n.node);

    if (tree.first()) |node| {
        const value = Number.from(node).value;
        std.debug.print("first: {d}\n", .{ value });
    }
}
