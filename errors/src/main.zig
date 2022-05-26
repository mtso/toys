const std = @import("std");

const CustomError = error{
    BadThing,
    NotSoBadThing,
};

fn potentiallyBadThing(arg: u128) CustomError!void {
    if (arg == 1) {
        return error.BadThing;
    }
}

pub fn main() anyerror!void {
    potentiallyBadThing(1) catch |err| {
        switch (err) {
            error.BadThing => std.debug.print("Bad thing: {any}\n", .{ err }),
            error.NotSoBadThing => std.debug.print("NotSoBadThing: {any}\n", .{ err }),
            // _ => std.debug.print("Other: {any}\n", .{ err }),
        }
        // std.debug.print("Bad thing: {any}\n", .{ err });
    };
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
