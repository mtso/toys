const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();


pub fn Foo(comptime T: type, comptime E: type) type {
    return struct {
        const Self = @This();
        fooFn: fn (self: *Self, t: T, r: E) E!T,
        pub fn foo(self: *Self, t: T, r: E) E!T {
            return self.fooFn(self, t, r);
        }
    };
}

const Err = error{foo_error, ok};
const EFoo = Foo(u64, Err);

const EFooPrinter = struct {
    const Self = @This();
    foo: EFoo = EFoo{
        .fooFn = fooF,
    },
    pub fn fooF(foo: *EFoo, t: u64, e: Err) Err!u64 {
        return switch (e) {
            Err.foo_error => e,
            Err.ok => t,
        };
    }
};

test "efooprinter" {
    var pr = EFooPrinter{};
    var f = &pr.foo;

    const result = try f.foo(64, Err.ok);
    try std.testing.expect(result == 64);

    if (f.foo(64, Err.foo_error)) |result2| {
        try std.testing.expect(false);
    } else |err| {
        try std.testing.expect(err == Err.foo_error);
    }
}

// pub fn Foo(comptime T: type) type {
//     return struct {
//         fooFn: fn (self: *Foo(T), bar: *Bar(T)) T,
//         pub fn foo(self: *Foo, bar: *Bar(T)) T {
//             return self.fooFn(self, bar);
//         }
//     };
// }

// pub fn Bar(comptime T: type, comptime R: type) type {
//     return struct {
//         barFn: fn (self: *Bar(T), foo: *Foo(T)) T,
//         pub fn bar(self: *Bar(T), foo: *Foo(T)) T {
//             return self.barFn(self, foo);
//         }
//     };
// }

// pub fn RealFoo = struct {
//     const Self = @This();
//     foo: Foo(u64) = Foo(u64){
//         .fooFn = 
//     },

//     pub fn foo(foo: *Foo(u64), bar: *Bar(u64)) {

//     }
// }

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // var tokens = ArrayList(Token).init(gpa);
    // defer tokens.deinit();

    // var lits = ArrayList(LiteralExpr).init(gpa);
    // defer lits.deinit();

    // var exprs = ArrayList(*Expr).init(gpa);
    // defer exprs.deinit();

    // {
    //     var token0 = Token.init(.string, "hi", Value{ .string = "hi" }, 1);
    //     try tokens.append(token0);
    //     try tokens.append(Token.init(.string, "world", Value{ .string = "world" }, 2));
    //     try tokens.append(Token.init(.number, "2.0", Value{ .number = 2.0 }, 3));
    // }

    // var rs = ResolveVisitor{};
    // var visitor = &rs.visitor;

    // for (tokens.items) |token, i| {
    //     var literalExpr = try LiteralExpr.init(gpa, token.literal.?);
    //     var group0 = try GroupingExpr.init(gpa, &literalExpr.expr);
    //     try exprs.append(&group0.expr);
    //     try exprs.append(&literalExpr.expr);
    // }

    // iterExprs(exprs, visitor);
    // iterExprs(exprs, visitor);
}
