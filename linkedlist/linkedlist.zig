const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const stdout = std.io.getStdOut().writer();

const Node = struct {
    value: []u8,
    next: ?*Node = null,
};

pub const LinkedList = struct {
    const Self = @This();
    // const Allocator = (std.heap.GeneralPurposeAllocator(.{}){}).allocator;

    len: usize = 0,
    head: ?*Node = null,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn insert(self: *Self, comptime value: []const u8) !void {
        // self.head = Node{ .value = value };
        // const m = try LinkedList.Allocator.alloc(u8, @sizeOf(value));
        // @alignOf(@TypeOf(value));
        var new_mem = try self.allocator.alloc(u8, value.len);
        // const stdout = std.io.getStdOut().writer();
        // try stdout.print("len {d}\n", .{ new_mem.len });

        mem.copy(u8, new_mem[0..value.len], value[0..value.len]);
        self.head = &Node {
            .value = new_mem[0..new_mem.len],
        };
        self.len += 1;
        // self.allocator.free(new_mem.ptr[0..new_mem.len]);
    }

    // pub fn find(self: *Self, ) ?[]u8 {

    // }

    pub fn find(self: *Self, needle: []const u8) ?[]u8 {
        // if (mem.eql(u8, "asdf", needle)) {
        //     return null;
        // }
        // if (self.head) |node| {
        // }

        return null;
    }

    pub fn testHead(self: *Self) !void {
        // const first = list.first orelse return;

        var ptr: *Node = self.head.?;
        // try stdout.print("len {d}\n", .{ @TypeOf(ptr.value) });
        try stdout.print("len {s}\n", .{ ptr.value });
        // try stdout.print("len {d}\n", .{ ptr.value.len });
        // if (self.head) |node| {
        //     const stdout = std.io.getStdOut().writer();
        //     try stdout.print("len {d}\n", .{ node.value });
        //     try stdout.print("len {d}\n", .{ node.value.len });
        // }
    }

    pub fn pop(self: *Self) !void {
        // var ptr: *Node = list.head.?;
        if (self.head) |node| {
        // const stdout = std.io.getStdOut().writer();
        // try stdout.print("len {d}\n", .{ node.value.len });
        //     self.allocator.free(node.value[0..node.value.len]);
        //     // self.head = node.next;
        }
        // if (self.head == null) {
        //     return;
        // }
        // else {
        //     var ptr: *Node = self.head.?;
        //     self.head = ptr.next;
        //     self.allocator.free(ptr.value);
        // }
    }

    // pub fn deinit(self: *Self) void {
    //     self.allocator.free(self.)
    // }
};

test "insert" {
//   const eql = std.mem.eql;
// const ArrayList = std.ArrayList;
// const test_allocator = std.testing.allocator;

// test "arraylist" {
    // var list = ArrayList(u8).init(test_allocator);
    // defer list.deinit();
    // try list.append('H');
        // try expect(eql(u8, list.items, "Hello World!"));


    const expect = std.testing.expect;
    const test_allocator = std.testing.allocator;
    // defer list.deinit();
    var list = LinkedList.init(test_allocator);
    try list.insert("hi");
    // list.insert("hiwhat");
    try expect(list.len == 1);
    // const n = list.head;
    // try list.testHead();
    // try expect(mem.eql(u8, ptr.value, "hi"));

    // try list.pop();
    // var str = list.find("hi");
    // if (str) |s| {
    //     try stdout.print("str {s}", .{s});
    // }

    // _ = mem.eql(u8, "asdf", "hi");

    var ptr: *Node = (list.head.?);
    try stdout.print("str {s}\n", .{ptr.value[0..2]});
    test_allocator.free(ptr.value);
}

// test "allocation" {
//     const allocator = std.heap.page_allocator;

//     const memory = try allocator.alloc(u8, 100);
//     defer allocator.free(memory);

//     try expect(memory.len == 100);
//     try expect(@TypeOf(memory) == []u8);
// }