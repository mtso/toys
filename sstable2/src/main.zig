const std = @import("std");
const rb = @import("rb.zig");
const ulid = @import("ulid.zig");
const assert = std.debug.assert;

const Entry = struct {
    key: ulid.Ulid,
    value: u128,
};

const EntryNode = struct {
    const Self = @This();

    node: rb.Node,
    entry: Entry,

    pub fn from(node: *rb.Node) *Self {
        return @fieldParentPtr(Self, "node", node);
    }

    pub fn order(l: *rb.Node, r: *rb.Node) std.math.Order {
        const left = EntryNode.from(l);
        const right = EntryNode.from(r);
        return ulid.order(left.entry.key, right.entry.key);
    }
};

pub fn main() anyerror!void {
    var tree: rb.Tree = undefined;
    tree.init(EntryNode.order);
    var nodes: [10]EntryNode = undefined;
    var monotonicFactory = ulid.DefaultMonotonicFactory.init();

    nodes[0].entry = Entry{ .key = try monotonicFactory.next(), .value = 0 };
    nodes[1].entry = Entry{ .key = try monotonicFactory.next(), .value = 1 };
    nodes[2].entry = Entry{ .key = try monotonicFactory.next(), .value = 2 };
    nodes[3].entry = Entry{ .key = try monotonicFactory.next(), .value = 3 };
    nodes[4].entry = Entry{ .key = try monotonicFactory.next(), .value = 4 };
    nodes[5].entry = Entry{ .key = try monotonicFactory.next(), .value = 5 };
    nodes[6].entry = Entry{ .key = try monotonicFactory.next(), .value = 6 };
    nodes[7].entry = Entry{ .key = try monotonicFactory.next(), .value = 7 };
    nodes[8].entry = Entry{ .key = try monotonicFactory.next(), .value = 8 };
    nodes[9].entry = Entry{ .key = try monotonicFactory.next(), .value = 9 };

    _ = tree.insert(&nodes[2].node);
    _ = tree.insert(&nodes[4].node);
    _ = tree.insert(&nodes[0].node);
    _ = tree.insert(&nodes[1].node);
    _ = tree.insert(&nodes[5].node);

    var it = tree.iterator();
    while (it.next()) |node| {
        var entry = EntryNode.from(node).entry;
        std.debug.print("{?} -> {d}\n", .{ entry.key, entry.value });
    }
}
