const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        const Node = struct {
            value: T,
            refs: usize,

            pub fn ref(self: *Node) void {
                self.refs += 1;
            }

            pub fn unref(self: *Node) void {
                self.refs -= 1;
                assert(self.refs >= 0);
            }
        };

        nodes: []Node,

        pub fn init(allocator: mem.Allocator, size: usize) !Self {
            const nodes = try allocator.alloc(Node, size);
            for (nodes) |*node| node.* = mem.zeroes(Node);
            return Self{
                .nodes = nodes,
            };
        }

        pub fn deinit(self: *Self, allocator: mem.Allocator) void {
            allocator.free(self.nodes);
        }

        pub fn newRef(self: *Self) ?*Node {
            for (self.nodes) |*node| {
                if (node.refs > 0) continue;
                node.refs = 1;
                return node;
            }
            return null;
        }
    };
}

const Foo = struct {
    code: [32]u8,
};

test "Pool" {
    var pool = try Pool(Foo).init(std.testing.allocator, 4);
    defer pool.deinit(std.testing.allocator);

    var foo1 = pool.newRef().?;
    try std.testing.expect(foo1.refs == 1);

    const msg = "hi";
    mem.copy(u8, foo1.value.code[0..msg.len], msg[0..]);

    foo1.ref();
    try std.testing.expect(foo1.refs == 2);

    foo1.unref();
    try std.testing.expect(foo1.refs == 1);

    var foo2 = pool.newRef().?;
    try std.testing.expect(foo2.refs == 1);
    var foo3 = pool.newRef().?;
    try std.testing.expect(foo3.refs == 1);
    var foo4 = pool.newRef().?;
    try std.testing.expect(foo4.refs == 1);

    var foo5 = pool.newRef();
    try std.testing.expect(foo5 == null);

    foo4.unref();

    var foo6 = pool.newRef().?;
    try std.testing.expect(foo6.refs == 1);
}
