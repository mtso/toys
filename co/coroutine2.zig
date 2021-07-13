const time = @import("std").time;

const std = @import("std");
const net = std.net;
const stdout = std.io.getStdOut().writer();

pub const io_mode = .evented;

fn life(n: usize) !void {
    time.sleep(0);
    try stdout.print("asdf {d}\n", .{n});
}

pub fn main() !void {
    // const addr = try net.Address.parseIp("127.0.0.1", 1984);

    // try send_message(addr);
    // var sendFrame = async send_message(addr);
    // try await sendFrame;
    var i: usize = 0;
    var cos = [3]@Frame(life){async life(0), async life(1), async life(2)};
    // try stdout.print("greetings, {d}!\n", .{life(0)});
    while (i < 3): (i += 1) {
        _ = await cos[i];
    }
}
