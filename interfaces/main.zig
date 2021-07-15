const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();

pub fn Supplier(comptime T: type) type {
    return struct {
        const Self = @This();
        getFn: fn (self: *Self) ?T,
        pub fn get(self: *Self) ?T {
            return self.getFn(self);
        }
    };
}

pub fn StringSupplier(comptime T: type) type {
    return struct {
        supplier: Supplier(T) = Supplier(T){
            .getFn = get,
        },
        val: T,

        const Self = @This();

        pub fn get(supplier: *Supplier(T)) ?T {
            const self = @fieldParentPtr(Self, "supplier", supplier);
            return self.val;
        }

        pub fn init(val: T) Self {
            return .{ .val = val };
        }
    };
}
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var ss = StringSupplier([]const u8).init("hi");
    var supplier = &ss.supplier;
    std.debug.print("greet: {s}\n", .{supplier.get()});
}
