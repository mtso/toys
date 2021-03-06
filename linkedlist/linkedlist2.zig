const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const stdout = std.io.getStdOut().writer();

pub const LinkedList = struct {
    const Self = @This();

    const Node = struct {
        value: []const u8,
        next: ?*Node = null,
        prev: ?*Node = null,
    };

    const ListError = error{NotFound};

    len: usize = 0,
    head: ?*Node = null,
    tail: ?*Node = null,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn insert(self: *Self, value: []const u8) !void {
        const node = try self.allocator.create(Node);
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

    pub fn insertFirst(self: *Self, value: []const u8) !void {
        const node = try self.allocator.create(Node);
        node.* = .{ .value = value };
        self.len += 1;

        if (self.head) |head| {
            head.prev = node;
            node.next = head;
        } else {
            self.tail = node;
        }
        self.head = node;
    }

    pub fn indexOf(self: *Self, value: []const u8) !usize {
        var curr = self.head;
        var i: usize = 0;
        while (curr) |c| : (i += 1) {
            if (std.mem.eql(u8, c.value, value)) {
                return i;
            }
            curr = c.next;
        }
        return ListError.NotFound;
    }

    // head a
    // tail a
    // a.next = null
    // a.prev = null
    pub fn remove(self: *Self) void {
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

    pub fn removeFirst(self: *Self) void {
        if (self.head) |head| {
            if (head.next) |next| {
                next.prev = null;
                self.head = next;
            } else {
                self.head = null;
                self.tail = null;
            }
            self.allocator.destroy(head);
            self.len -= 1;
        }
    }

    pub fn deinit(self: *Self) void {
        while (self.len > 0) {
            self.remove();
        }
    }

    pub fn iter(self: *Self) StringIterator {
        return StringIterator.init(self);
    }
};

pub const StringIterator = struct {
    const Self = @This();

    list: *LinkedList,
    curr: ?*LinkedList.Node,

    const IterError = error{End};

    pub fn init(list: *LinkedList) Self {
        return Self{ .list = list, .curr = list.head };
    }

    pub fn next(self: *Self) ![]const u8 {
        if (self.curr) |node| {
            const value = node.value;
            self.curr = node.next;
            return value;
        } else {
            return IterError.End;
        }
    }

    pub fn hasNext(self: *Self) bool {
        return self.curr != null;
    }
};

test "insert/remove/indexOf" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;
    var test_allocator = std.testing.allocator;

    var list = LinkedList.init(test_allocator);
    defer list.deinit();

    try list.insert("hi");
    try expect(1 == list.len);
    try expect(eql(u8, list.head.?.value, "hi"));
    try list.insert("world");
    try expect(2 == list.len);
    try expect(eql(u8, list.tail.?.value, "world"));
    try expect(0 == try list.indexOf("hi"));
    try expect(1 == try list.indexOf("world"));
    list.remove();
    try expect(1 == list.len);
    list.remove();
    if (list.indexOf("hi")) |_| {
        try expect(false);
    } else |err| switch (err) {
        LinkedList.ListError.NotFound => try expect(true),
    }
    try expect(0 == list.len);
}

test "iterator" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;
    var test_allocator = std.testing.allocator;

    var list = LinkedList.init(test_allocator);
    defer list.deinit();
    try list.insert("hi");
    try list.insert("world");

    var it = list.iter();
    const strs = [_][]const u8 {"hi", "world"};
    var i: usize = 0;
    while (it.hasNext()) : (i += 1) {
        try expect(eql(u8, try it.next(), strs[i]));
    }
}

test "deinit" {
    const expect = std.testing.expect;
    // const eql = std.mem.eql;
    var test_allocator = std.testing.allocator;

    var list = LinkedList.init(test_allocator);
    try list.insert("hi");
    try list.insert("world");
    try list.insert("!");
    try expect(3 == list.len);

    list.deinit();
    try expect(0 == list.len);
}

test "insertFirst/removeFirst/indexOf" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;
    var test_allocator = std.testing.allocator;

    var list = LinkedList.init(test_allocator);
    defer list.deinit();

    try list.insertFirst("hi");
    try expect(1 == list.len);
    try expect(eql(u8, list.tail.?.value, "hi"));
    try list.insertFirst("world");
    try expect(2 == list.len);
    try expect(eql(u8, list.head.?.value, "world"));
    try expect(1 == try list.indexOf("hi"));
    try expect(0 == try list.indexOf("world"));
    list.removeFirst();
    try expect(eql(u8, list.head.?.value, "hi"));
    try expect(1 == list.len);
    list.removeFirst();
    if (list.indexOf("hi")) |_| {
        try expect(false);
    } else |err| switch (err) {
        LinkedList.ListError.NotFound => try expect(true),
    }
    try expect(0 == list.len);
}
