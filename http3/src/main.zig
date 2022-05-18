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

    try server.listen(net.Address.parseIp("0.0.0.0", 8080) catch unreachable);
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
                return error.NotFound;
            } else {
                std.log.err("Unhandled error: {s}", .{err});
                return error.UnexpectedError;
            }
        };
        defer file.close();

        const info = file.stat() catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                return error.NotFound;
            } else {
                std.log.err("Unhandled error: {s}", .{err});
                return error.UnexpectedError;
            }
        };

        return Self{
            .name = name,
            .info = info,
        };
    }

    pub fn readIntoConnection(self: Self, conn: net.StreamServer.Connection) ResourceError!void {
        const file = std.fs.cwd().openFile(self.name, .{}) catch |err| {
            std.log.err("Failed to cwd().openFile: {s}", .{err});
            return error.UnexpectedError;
        };
        defer file.close();

        const info = file.stat() catch |err| {
            std.log.err("Failed to file.stat: {s}", .{err});
            return error.UnexpectedError;
        };

        const dest = conn.stream.handle;
        const src = file.handle;

        const zero_iovec = &[0]os.iovec_const{};
        // Ref: https://github.com/ziglang/zig/blob/988afd51cd34649887f493b6ac9e05fcaa1f768d/lib/std/fs/file.zig#L1312-L1324
        // fn sendfile(out_fd: i32, in_fd: i32, in_offset: u64, in_len: u64, headers: []const iovec_const, trailers: []const iovec_const, flags: u32) SendFileError!u64
        _ = os.sendfile(dest, src, 0, info.size, zero_iovec, zero_iovec, 0) catch |err| {
            std.log.err("Failed to os.sendfile: {s}", .{err});
            return error.UnexpectedError;
        };
    }
};

fn respondBadRequest(conn: net.StreamServer.Connection) void {
    _ = conn.stream.writer().print("HTTP/1.1 400 Bad Request\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 11\n\nBad Request", .{}) catch |err| {
        std.log.err("Failed to respond: {s}", .{err});
    };
}

fn respondNotFound(conn: net.StreamServer.Connection) void {
    _ = conn.stream.writer().print("HTTP/1.1 404 Not Found\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 9\n\nNot Found", .{}) catch |err| {
        std.log.err("Failed to respond: {s}", .{err});
    };
}

fn respondMethodNotAllowed(conn: net.StreamServer.Connection) void {
    _ = conn.stream.writer().print("HTTP/1.1 405 Method Not Allowed\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 18\n\nMethod Not Allowed", .{}) catch |err| {
        std.log.err("Failed to respond: {s}", .{err});
    };
}

fn respondServerError(conn: net.StreamServer.Connection) void {
    const message = "HTTP/1.1 500 Internal Server Error\nContent-Type: text/plain; charset=UTF-8\nContent-Length: 21\n\nInternal Server Error";
    _ = conn.stream.writer().print(message, .{}) catch |err| {
        std.log.err("Failed to respond: {s}", .{err});
    };
}

// if path is longer than buffer, return not-found error
// if path is not found, return not-found
fn handle(conn: net.StreamServer.Connection) !void {
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const stdout = std.io.getStdOut();

    //const request = Request.create(conn, &buf);
    //const method = context.slurpMethod(context);

    //const method = slurpMethod(conn, &buf) catch |err| {
    //    return request.handleError(err);
    //};

    const method = try conn.stream.reader().readUntilDelimiterOrEof(&buf, ' ');
    if (method) |m| {
        _ = try stdout.writer().write(m);
        if (!mem.eql(u8, "GET", m)) {
            return respondMethodNotAllowed(conn);
        }
    } else {
        respondBadRequest(conn);
        return;
    }

    if (method == null) {
        respondBadRequest(conn);
        return;
    }
 
    const pathP = conn.stream.reader().readUntilDelimiterOrEof(&buf, ' ') catch |err| {
        std.log.warn("Failed to parse path: {s}", .{err});
        respondBadRequest(conn);
        return;
    };

    if (pathP) |p| {
        _ = try stdout.writer().print(" {s}", .{p});
    } else {
        respondBadRequest(conn);
        return;
    }
    _ = try stdout.writer().write("\n");

    const path = pathP.?;
    const len = path.len;
    const filename = path[1..len];
    
    const res = Resource.init(filename) catch |err| {
        if (err == ResourceError.NotFound) {
            respondNotFound(conn);
        } else {
            respondServerError(conn);
        }
        return;
    };

    const header = "HTTP/1.1 200 OK\nContent-Type: text/plain\n";
    const delim = "\n\n";

    _ = conn.stream.write(header) catch |e| std.log.err("unable to send: {}\n", .{e});
    _ = try conn.stream.writer().print("Content-Length: {d}", .{res.info.size});
    _ = conn.stream.write(delim) catch |e| std.log.err("unable to send: {}\n", .{e});

    res.readIntoConnection(conn) catch {
        return respondServerError(conn);
    };
}

