const std = @import("std");
const DB = @import("cask.zig").DB;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var db = try DB.open("foo.db", allocator);
    defer db.close();

    if (true) {
        try db.set("hi", "boo");
    }

    if (true) {
        const value = db.get("hi");
        std.debug.assert(std.mem.eql(u8, value, "boo"));
        std.debug.print("hi: {s}\n", .{ value });
    }

    if (true) {
        try db.set("hi", "");
    }
}

