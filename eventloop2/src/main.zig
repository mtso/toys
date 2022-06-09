const std = @import("std");
const mem = std.mem;
const os = std.os;
const Fifo = @import("fifo.zig").Fifo;

const INVALID_SOCKET = -1;

const Loop = struct {
    completions: Fifo(Completion),

    const Operation = union(enum) {
        accept: struct {
            socket: os.socket_t,
        },
        // timeout: struct {
        //     start: i64,
        //     delay: i64,
        // },
    };

    const Completion = struct {
        next: ?*Completion,
        op: Operation,
        callback: fn (*Loop, *Completion) void,
        context: ?*anyopaque,
    };

    pub fn shouldContinue(self: *Loop) bool {
        return self.completions.peek() != null;
    }

    pub fn tick(self: *Loop) void {
        const completion = if (self.completions.pop()) |c| c else return;
        completion.callback(self, completion);
    }

    pub const AcceptError = os.AcceptError || os.SetSockOptError;

    pub fn accept(
        self: *Loop,
        socket: os.socket_t,
        completion: *Completion,
        comptime Context: type,
        context: Context,
        comptime callback: fn (context: Context, completion: *Completion, result: AcceptError!os.socket_t) void,
    ) void {
        const op_data = @unionInit(Operation, @tagName(.accept), .{
            .socket = socket,
        });

        const operation_impl = struct {
            fn impl(loop: *Loop, _completion: *Completion) void {
                const op = _completion.op;

                const fd = os.accept(op.accept.socket, null, null, os.SOCK.NONBLOCK | os.SOCK.CLOEXEC) catch |err| switch (err) {
                    error.WouldBlock => {
                        _completion.next = null;
                        loop.completions.push(_completion);
                        return;
                    },
                    else => |e| e,
                };
                std.debug.print("accepted {any}!\n", .{fd});

                // errdefer os.close(fd);

                // os.setsockopt(
                //     fd,
                //     os.SOL.SOCKET,
                //     os.SO.NOSIGPIPE,
                //     &mem.toBytes(@as(c_int, 1)),
                // ) catch |err| return switch (err) {
                //     error.TimeoutTooBig => unreachable,
                //     error.PermissionDenied => error.NetworkSubsystemFailed,
                //     error.AlreadyConnected => error.NetworkSubsystemFailed,
                //     error.InvalidProtocolOption => error.ProtocolFailure,
                //     else => |e| e,
                // };

                callback(@intToPtr(Context, @ptrToInt(_completion.context)), _completion, fd);
            }
        }.impl;

        completion.* = .{
            .next = null,
            .op = op_data,
            .context = context,
            .callback = operation_impl,
        };

        self.completions.push(completion);
    }
};

const Server = struct {
    connections: []Connection,
    listen_socket: os.socket_t,
    loop: *Loop,
    accept_completion: Loop.Completion = undefined,
    accept_fd: os.socket_t = INVALID_SOCKET,
    accept_connection: ?*Connection = null,

    const Connection = struct {
        state: enum {
            free,
            accepting,
            connected,
            terminating,
        } = .free,
        fd: os.socket_t = INVALID_SOCKET,
    };

    fn init(loop: *Loop, listen_socket: os.socket_t, allocator: mem.Allocator) !Server {
        var connections = try allocator.alloc(Connection, 128);
        errdefer allocator.free(connections);
        mem.set(Connection, connections, .{});
        return Server{
            .connections = connections,
            .loop = loop,
            .listen_socket = listen_socket,
        };
    }

    fn tick(self: *Server) void {
        self.maybeAccept();
    }

    fn maybeAccept(self: *Server) void {
        if (self.accept_connection != null) return;

        self.accept_connection = for (self.connections) |c, i| {
            if (c.state != .free) continue;
            self.connections[i].state = .accepting;
            break &self.connections[i];
        } else return;

        self.loop.accept(
            self.listen_socket,
            &self.accept_completion,
            *Server,
            self,
            on_accept,
        );
    }

    fn on_accept(self: *Server, _: *Loop.Completion, result: Loop.AcceptError!os.socket_t) void {
        const fd = result catch |err| {
            std.log.err("accept error: {any}", .{err});
            return;
        };

        if (self.accept_connection) |conn| {
            conn.fd = fd;
            conn.state = .connected;
            self.accept_connection = null;
        } else unreachable;

        std.log.info("received connection: {d}", .{fd});
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
    const listen = try open_socket();
    std.log.info("Listening on 4000", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var event_loop = Loop{ .completions = Fifo(Loop.Completion){} };
    var server = try Server.init(&event_loop, listen, allocator);

    while (true) {
        server.tick();
        event_loop.tick();
        // std.time.sleep(1000000000);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
