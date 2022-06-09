const std = @import("std");
const os = std.os;

fn fs_supports_direct_io(dir_fd: std.os.fd_t) !bool {
    if (!@hasDecl(std.os.O, "DIRECT")) return false;

    const path = "fs_supports_direct_io";
    const dir = std.fs.Dir{ .fd = dir_fd };
    const fd = try os.openatZ(dir_fd, path, os.O.CLOEXEC | os.O.CREAT | os.O.TRUNC, 0o666);
    defer os.close(fd);
    defer dir.deleteFile(path) catch {};

    while (true) {
        const res = os.system.openat(dir_fd, path, os.O.CLOEXEC | os.O.RDONLY | os.O.DIRECT, 0);
        switch (os.linux.getErrno(res)) {
            .SUCCESS => {
                os.close(@intCast(os.fd_t, res));
                return true;
            },
            .INTR => continue,
            .INVAL => return false,
            else => |err| return os.unexpectedErrno(err),
        }
    }
}

fn parseDirectory(str: []u8) ?[]u8 {
    const flag = "--directory=";
    if (str.len < flag.len) return null;
    if (!std.mem.eql(u8, flag, str[0..flag.len])) return null;
    return str[flag.len..];
}

fn maybeDirectory(argv: [][*:0]u8) ?[]u8 {
    for (argv) |arg| {
        const argSlice = std.mem.sliceTo(arg, 0);
        return if (parseDirectory(argSlice)) |dir| dir else continue;
    }
    return null;
}

/// Usage:
///     zig build run -- --directory=/src
pub fn main() anyerror!void {
    const hasDirect = @hasDecl(std.os.O, "DIRECT");
    std.log.info("hasDecl 'std.os.O.DIRECT': {}", .{hasDirect});

    if (maybeDirectory(std.os.argv)) |dirname| {
        std.log.info("opening directory {s}", .{dirname});

        const dir = try std.fs.cwd().openDir(dirname, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.info("path not found", .{});
                return;
            },
            else => |e| e,
        };

        const supports = try fs_supports_direct_io(dir.fd);
        std.log.info("supports direct IO: {}", .{supports});
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
