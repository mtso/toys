const net = @import("std").net;
const os = @import("std").os;
const time = @import("std").time;

pub const io_mode = .evented;

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", 1984);
    const socket = try net.tcpConnectToAddress(addr);
    defer socket.close();
    // var msg = "Hello World!\n";
    var cos = [3]@Frame(send_message2){
      async send_message2(socket, "hi 0!\n"),
      async send_message2(socket, "hi 1!\n"),
      async send_message2(socket, "hi 2!\n"),
    };
    // for (cos) |c| {
    //   _ = await c;
    // }
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        _ = await cos[i];
    }
    // _ = async send_message2(socket, "Hello World!\n");
    // _ = async send_message2(socket, "hi world\n");
}

fn send_message(addr: net.Address, msg: []const u8) !void {
    var socket = try net.tcpConnectToAddress(addr);
    defer socket.close();

    // try async time.sleep(10000);
    // os.nanosleep(2000);

    _ = try socket.write(msg);
}


fn send_message2(socket: net.Stream, msg: []const u8) !void {
    time.sleep(0);

    _ = async socket.write(msg);
}

// const std = @import("std");
// const net = std.net;
// // const stdout = std.io.getStdOut().writer();

// // pub const io_mode = .evented;

// // fn life(n: usize) !{
// //     // const msg = std.fmt.format("n {d}\n", .{n});
// //     return async stdout.print("asdf {d}\n", .{n});
// //     // return n;
// // }

// fn send_message(addr: net.Address) !void {
//     var socket = net.tcpConnectToAddress(addr);
//     defer socket.close();

//     // this too
//     _ = try socket.write("Hello World!\n");
// }

// pub fn main() !void {
//     const addr = try net.Address.parseIp("127.0.0.1", 1984);

//     try send_message(addr);
//     // var sendFrame = async send_message(addr);
//     // try await sendFrame;
//     // var i: usize = 0;
//     // var cos = [3]@Frame(life){async life(0), async life(1), async life(2)};
//     // try stdout.print("greetings, {d}!\n", .{life(0)});
//     // while (i < 3): (i += 1) {
//     //     _ = await cos[i];
//     // }
// }
