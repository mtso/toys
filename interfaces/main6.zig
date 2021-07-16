const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();

// Demonstrates two types being returned with the same parameterized type.

pub fn Quux(comptime T: type) type {
    return struct{
        const Foo = struct{
            const Self = @This();
            fooFn: fn (self: *Self) T,
            pub fn foo(self: *Self) T {
                return self.fooFn(self);
            }
        };
        const Bar = struct{
            const Self = @This();
            barFn: fn (self: *Self) T,
            pub fn bar(self: *Self) T {
                return self.barFn(self);
            }
        };
    };
}

const QFoo = Quux(u64).Foo;
const QBar = Quux(u64).Bar;

const UFoo = struct {
    const Self = @This();
    foo: QFoo = QFoo{
        .fooFn = fooF,
    },
    value: u64,
    pub fn fooF(foo: *QFoo) u64 {
        const self = @fieldParentPtr(Self, "foo", foo);
        return self.value;
    }
};

test "Quux Foo/Bar" {
    var ufoo = UFoo{.value = 64};
    const foo = &ufoo.foo;
    try std.testing.expect(foo.foo() == 64);
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
}
