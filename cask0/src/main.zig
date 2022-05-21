const std = @import("std");

// Ref: https://github.com/coilhq/tigerbeetle/blob/4bfb9ec35d72ce807de9a42f71bf00a7043a2c26/demos/bitcast/README.md
// Ref: https://github.com/coilhq/tigerbeetle/blob/4bfb9ec35d72ce807de9a42f71bf00a7043a2c26/demos/bitcast/decode.zig#L21
const Foo = packed struct {
    id: u64,
    num: u64,
};

fn write() !void {
    const dbname = "data.db";

    const file = try std.fs.cwd().createFile(dbname, .{
        .truncate = false,
    });

    try file.seekFromEnd(0);

    _ = try file.writeAll("hello\n");
}

fn read() !void {
    const dbname = "data.db";
    const file = try std.fs.cwd().createFile(dbname, .{
       .truncate = false,
       .read = true,
    });

    var buffer: [1000]u8 = undefined;
    try file.seekTo(0);
    const bytes_read = try file.readAll(&buffer);
    std.log.info("Data: {s}", .{ buffer[0..bytes_read] });
}

fn writeFoo(filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{
        .truncate = false,
    });

    try file.seekFromEnd(0);

    const foo = Foo{
        .id = 1,
        .num = 1,
    };

    const bytes = @bitCast([@sizeOf(Foo)]u8, foo);

    _ = try file.writeAll(bytes[0..]);
}

fn readFoo(filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{
        .truncate = false,
        .read = true,
    });
    try file.seekTo(0);
    var bytes: [@sizeOf(Foo)]u8 = undefined;

    const bytes_read = try file.read(bytes[0..]);
    std.debug.assert(bytes_read == bytes.len);

    const foo = @bitCast(Foo, bytes);
    std.debug.print("id={d} num={d}", .{
        foo.id,
        foo.num,
    });
}

pub fn main() anyerror!void {

    //try write();
    //try read();

    //try writeFoo("foo.db");
    try readFoo("foo.db");
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
