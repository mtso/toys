const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

pub const Expr = struct {
    const Self = @This();
    acceptFn: fn (self: *const Self, visitor: *Visitor) ?Literal,
    pub fn accept(self: *const Self, visitor: *Visitor) ?Literal {
        return self.acceptFn(self, visitor);
    }
};

pub const Visitor = struct {
    const Self = @This();
    visitLiteralExprFn: fn (self: *Self, expr: LiteralExpr) ?Literal,

    pub fn visitLiteralExpr(self: *Self, expr: LiteralExpr) ?Literal {
        return self.visitLiteralExprFn(self, expr);
    }
};

pub const LiteralExpr = struct {
    const Self = @This();
    expr: Expr = Expr{ .acceptFn = accept },

    value: Literal,

    pub fn init(allocator: *Allocator, value: Literal) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .value = value };
        return self;
    }
    pub fn accept(expr: *const Expr, visitor: *Visitor) ?Literal {
        const self = @fieldParentPtr(Self, "expr", expr);
        return visitor.visitLiteralExpr(self.*);
    }
};

const stdout = std.io.getStdOut().writer();

const E = enum {
    one,
    two,
    three,
};

const U = union(E) {
    one: i32,
    two: f32,
    three,
};

const V = union(V) {
    one: i32,
    two: f32,
    three: u8,
};

test "coercion between unions and enums" {
    var v = V{ .two = 12.34 };
    // var u: U = v;


    var u = U{ .two = 12.34 };
    var e: E = u;
    try std.testing.expect(e == E.two);

    const three = E.three;
    var another_u: U = three;
    try std.testing.expect(another_u == E.three);
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
}
