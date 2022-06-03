const std = @import("std");
const mem = std.mem;
const os = std.os;
const ArrayList = std.ArrayList;

// io
// ==
// accept
// send
// recv

// if connection received, store it to manage it
// if connection data available, read
// if outgoing messages available, send
// continue.

const EventLoop = struct {
    const Operation = union(enum) {
        accept: struct {
            socket: os.socket_t,
        },
    };

    queue: ArrayList(Operation),

    pub fn init(allocator: mem.Allocator) EventLoop {
        return .{
            .queue = ArrayList(Operation).init(allocator),
        };
    }

    pub fn deinit(self: *EventLoop) void {
        self.queue.deinit();
    }

    pub fn tick(self: *EventLoop) !void {
        _ = self;
        // if messages are available, recv
        // if outgoing messages exist, send
    }
};

const Server = struct {
    // event_loop: EventLoop,
    accept_fd: std.os.socket_t,

    pub fn tick(self: *Server) void {
        self.maybe_accept();
    }

    pub fn maybe_accept(self: *Server) void {
        const connection_socket = os.accept(
            self.accept_fd,
            null,
            null,
            os.SOCK.NONBLOCK
        ) catch |err| {
            std.debug.print("accept error! {any}\n", .{ err });
            return;
        };

        std.debug.print("got connection {any}\n", .{ connection_socket });
    }
};

fn open_socket() !std.os.socket_t {
    const listen_host = "0.0.0.0";
    const listen_port = 4000;
    const addr = try std.net.Address.parseIp4(listen_host, listen_port);
    const socket = try os.socket(addr.any.family, os.SOCK.STREAM, os.IPPROTO.TCP);
    errdefer os.closeSocket(socket);
    try os.bind(socket, &addr.any, addr.getOsSockLen());
    try os.listen(socket, 32);
    return socket;
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var event_loop = EventLoop.init(allocator);
    defer event_loop.deinit();

    // {
    //     const listen_host = "0.0.0.0";
    //     const listen_port = 4000;
    //     const addr = try std.net.Address.parseIp4(listen_host, listen_port);
    //     const socket = os.socket(addr.any.family, os.SOCK.STREAM, os.IPPROTO.TCP);
    //     std.debug.print("{any}\n", .{addr});
    //     std.debug.print("{any}\n", .{socket});
    // }

    var server = Server{ .accept_fd = try open_socket() };
    while (true) {
        server.tick();
    }

    // while (true) {
    //     try event_loop.tick();
    // }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
