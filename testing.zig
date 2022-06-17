const std = @import("std");

test "inf" {
    const fail = struct {
        fn fail() !void {
            return error.TestFail;
        }
    }.fail;
    const start = std.time.milliTimestamp();
    while (true) {
        const elapsedMs = std.time.milliTimestamp() - start;
        if (elapsedMs >= 1000) {
            try fail();
        }
    }
}
