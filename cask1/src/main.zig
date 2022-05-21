const std = @import("std");

const Header = packed struct {
    timestamp: i64,
    key_size: u64,
    value_size: u64,
};

fn write_key(file: std.fs.File) !void {
    const t = std.time.milliTimestamp();
    const h = Header{
        .timestamp = t,
        .key_size = 1,
        .value_size = 2,
    };

    const bytes = @bitCast([@sizeOf(Header)]u8, h);

    const bytes_written = try file.write(bytes[0..]);
    std.debug.assert(bytes_written == bytes.len);
}

fn read_key(file: std.fs.File) !void {
    var bytes: [@sizeOf(Header)]u8 = undefined;

    var bytes_read = try file.read(&bytes);
    std.debug.assert(bytes_read == bytes.len);

    const header = @bitCast(Header, bytes);
    std.debug.print("timestamp={d} key_size={d} value_size={d}", .{
        header.timestamp,
        header.key_size,
        header.value_size,
    });
}

pub fn main() anyerror!void {
    const file = try std.fs.cwd().createFile("foo.db", .{
        .truncate = false,
        .read = true,
    });

    if (false) try write_key(file);

    if (true) {
        try file.seekTo(0);
        try read_key(file);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
