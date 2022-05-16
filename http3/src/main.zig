const std = @import("std");

const net = std.net;
const fs = std.fs;
const os = std.os;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const mem = std.mem;

pub const io_mode = .evented;

pub fn main() anyerror!void {
    var server = net.StreamServer.init(.{});
    defer server.deinit();

    try server.listen(net.Address.parseIp("127.0.0.1", 8080) catch unreachable);
    std.log.warn("listening at {}\n", .{server.listen_address});

    while (true) {
        const conn = try server.accept();
        try handle(conn);
    }
}

const ResourceError = error{
    NotFound,
    UnexpectedError,
};

const Resource = struct {
    const Self = @This();

    name: []const u8,
    info: std.fs.File.Stat,

    pub fn init(name: []const u8) ResourceError!Self {
        const file = std.fs.cwd().openFile(name, .{}) catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                return ResourceError.NotFound;
            } else {
                std.log.err("Unhandled error: {s}", .{err});
                return ResourceError.UnexpectedError;
            }
        };
        defer file.close();

        const info = file.stat() catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                return ResourceError.NotFound;
            } else {
                std.log.err("Unhandled error: {s}", .{err});
                return ResourceError.UnexpectedError;
            }
        };

        return Self{
            .name = name,
            .info = info,
        };
    }

    pub fn readIntoConnection(self: Self, conn: net.StreamServer.Connection) !void {
        const file = try std.fs.cwd().openFile(self.name, .{});
        defer file.close();

        const info = try file.stat();

        const dest = conn.stream.handle;
        const src = file.handle;

        const zero_iovec = &[0]os.iovec_const{};
        // Ref: https://github.com/ziglang/zig/blob/988afd51cd34649887f493b6ac9e05fcaa1f768d/lib/std/fs/file.zig#L1312-L1324
        // fn sendfile(out_fd: i32, in_fd: i32, in_offset: u64, in_len: u64, headers: []const iovec_const, trailers: []const iovec_const, flags: u32) SendFileError!u64
        _ = try os.sendfile(dest, src, 0, info.size, zero_iovec, zero_iovec, 0);
    }
};

fn handleNotFound(conn: net.StreamServer.Connection) !void {
    _ = try conn.stream.writer().print("HTTP/1.1 404 Not Found\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 9\n\nNot Found", .{});
}

fn handleServerError(conn: net.StreamServer.Connection) !void {
    _ = try conn.stream.writer().print("HTTP/1.1 500 Internal Server Error\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 21\n\nInternal Server Error", .{});
}

// if path is longer than buffer, return not-found error
// if path is not found, return not-found
fn handle(conn: net.StreamServer.Connection) !void {
    //std.log.info("Received connection", .{});

    if (false) {
        try handleNotFound(conn);
        return;
    }

    var buf: [4096]u8 = undefined;
    const method = try conn.stream.reader().readUntilDelimiterOrEof(&buf, ' ');
    //std.log.info("method: {s}", .{method});
    if (method) |m| {
        _ = try std.io.getStdOut().writer().write(m);
    }
    //std.io.getStdOut().writer().write(method.?);
    const path = try conn.stream.reader().readUntilDelimiterOrEof(&buf, ' ');
    if (path) |p| {
        _ = try std.io.getStdOut().writer().print(" {s}", .{p});
    }
    _ = try std.io.getStdOut().writer().write("\n");
    //std.log.info(" path: {s}", .{path});

    const len = path.?.len;
    //std.log.info("pathlen: {d}", .{len});

    const filename = path.?[1..len];
    
    //const filename = "static/index.html";
    const res = Resource.init(filename) catch |err| {
        if (err == ResourceError.NotFound) {
            try handleNotFound(conn);
        } else {
            try handleServerError(conn);
        }
        return;
    };

    const header = "HTTP/1.1 200 OK\nContent-Type: text/html\n";
    const delim = "\n\n";

    _ = conn.stream.write(header) catch |e| std.log.err("unable to send: {}\n", .{e});
    _ = try conn.stream.writer().print("Content-Length: {d}", .{res.info.size});
    _ = conn.stream.write(delim) catch |e| std.log.err("unable to send: {}\n", .{e});

    try res.readIntoConnection(conn);

    conn.stream.close();
}

