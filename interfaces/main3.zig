const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();

pub const Supplier = struct {
    const Self = @This();
    getFn: fn (self: *Self) ?[]const u8,
    pub fn get(self: *Self) ?[]const u8 {
        return self.getFn(self);
    }
};

pub const StringSupplier = struct {
    supplier: Supplier = Supplier{
        .getFn = get,
    },
    val: []const u8,

    const Self = @This();

    pub fn get(supplier: *Supplier) ?[]const u8 {
        const self = @fieldParentPtr(Self, "supplier", supplier);
        return self.val;
    }

    pub fn init(val: []const u8) Self {
        return .{ .val = val };
    }
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var ss = StringSupplier.init("hi");
    var supplier = &ss.supplier;
    std.debug.print("greet: {s}\n", .{supplier.get()});
}
