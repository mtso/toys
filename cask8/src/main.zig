const std = @import("std");
const DB = @import("cask.zig").DB;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var db = try DB.open("foo.db", allocator);
    defer db.close();

    if (true) {
        try db.set("hi", "boo");
        try db.set("foos", "bars");
    }

    if (true) {
        const value = try db.get2("hi", allocator);
        std.debug.assert(std.mem.eql(u8, value, "boo"));
        std.debug.print("hi: {s}\n", .{ value });
        const value2 = try db.get2("foos", allocator);
        std.debug.print("foos: {s}\n", .{ value2 });

        allocator.free(value);
        allocator.free(value2);
    }

    if (true) {
        try db.set("hi", "");
    }
}

