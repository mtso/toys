const std = @import("std");
const ulid = @import("ulid.zig");
const math = std.math;

// Fixed-length entry for simplicity.
pub const Entry = packed struct {
    key: ulid.Ulid,
    value: u128,
};

pub fn entryOrder(a: anytype, b: anytype) math.Order {
    return ulid.order(a.key, b.key);
}

pub fn entryAsc(context: void, a: Entry, b: Entry) bool {
    _ = context;
    return entryOrder(a, b) == math.Order.lt;
}

pub fn entryDesc(context: void, a: Entry, b: Entry) bool {
    _ = context;
    return entryOrder(a, b) == math.Order.gt;
}

pub fn ulidAsc(context: void, a: ulid.Ulid, b: ulid.Ulid) bool {
    _ = context;
    return ulid.order(a, b) == math.Order.lt;
}
