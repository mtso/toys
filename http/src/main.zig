const std = @import("std");

const net = std.net;
const fs = std.fs;
const os = std.os;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const mem = std.mem;

pub const io_mode = .evented;

pub fn main() anyerror!void {
    if (false) {
        try readFile("static/index.html");
        // try readFile("/usr/local/dev/src/github.com/mtso/hello-zig/http/static/index.html");
        return;
    }

    // var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    // var allocator = general_purpose_allocator.allocator();

    var server = net.StreamServer.init(.{});
    defer server.deinit();

    try server.listen(net.Address.parseIp("127.0.0.1", 8080) catch unreachable);
    std.log.warn("listening at {}\n", .{server.listen_address});

    while (true) {
        const conn = try server.accept();
        try handle(conn);

        // const client = try allocator.create(Client);
        // client.* = Client{
        //     .conn = try server.accept(),
        //     .handle_frame = async client.handle(),
        // };
    }
}

fn readFile(name: []const u8) !void {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();
    try file.seekTo(0);

    var buffer: [4096]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);

    std.log.info("data: {s}", .{buffer[0..bytes_read]});
}

fn readFileIntoStream(name: []const u8, writer: net.Stream.Writer) !void {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    const reader = file.reader();

    var buffer: [4096]u8 = undefined;
    while (reader.read(&buffer)) |len| {
        std.log.info("read len {d} {s}", .{ len, buffer[0..len]});

        if (len <= 0) {
            return;
        }
        _ = try writer.write(buffer[0..len]);
    } else |err| {
        std.log.warn("Error writing to stream: {s}", .{ err });
    }
}

fn readFileIntoConnection(name: []const u8, conn: net.StreamServer.Connection) !void {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    const dest = conn.stream.handle; //conn.stream.writer().buffer;
    const src = file.handle;

    const zero_iovec = &[0]os.iovec_const{};
    // Ref: https://github.com/ziglang/zig/blob/988afd51cd34649887f493b6ac9e05fcaa1f768d/lib/std/fs/file.zig#L1312-L1324
    // fn sendfile(out_fd: i32, in_fd: i32, in_offset: u64, in_len: u64, headers: []const iovec_const, trailers: []const iovec_const, flags: u32) SendFileError!u64
    _ = try os.sendfile(dest, src, 0, 89, zero_iovec, zero_iovec, 0);
}

fn handle(conn: net.StreamServer.Connection) !void {
    std.log.info("Received connection", .{});
    const header = "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: 4096\n\n";
    _ = conn.stream.write(header) catch |e| std.log.warn("unable to send: {}\n", .{e});

    // try readFileIntoStream("./static/index.html", conn.stream.writer());
    try readFileIntoConnection("./static/index.html", conn);

    // const message = "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: 27\n\nwelcome to teh chat server\n";
    // _ = conn.stream.write(message) catch |e| std.log.warn("unable to send: {}\n", .{e});
    // while (true) {
    //     var buf: [1024]u8 = undefined;
    //     read(conn.stream.reader());
    //     const amt = try conn.stream.read(&buf);
    //     const msg = buf[0..amt];
    //     std.log.info("{s}", .{msg});
    //     if (amt < 1024) {
    //         break;
    //     }
    // }
    conn.stream.close();
}

// const Client = struct {
//     conn: net.StreamServer.Connection,
//     handle_frame: @Frame(handle),

//     fn handle(self: *Client) !void {
//         std.log.info("Received connection", .{});
//         const message = "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: 27\n\nwelcome to teh chat server\n";
//         _ = self.conn.stream.write(message) catch |e| std.log.warn("unable to send: {}\n", .{e});
//         while (true) {
//             var buf: [1024]u8 = undefined;
//             const amt = try self.conn.stream.read(&buf);
//             const msg = buf[0..amt];
//             std.log.info("{s}", .{msg});
//             if (amt < 1024) {
//                 break;
//             }
//         }
//         self.conn.stream.close();
//     }
// };
