const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();

pub const Token = struct {
    token_type: TokenType,
    lexeme: []const u8,
    literal: ?Value,
    line: u32,

    pub fn init(token_type: TokenType, lexeme: []const u8, literal: ?Value, line: u32) Token {
        return .{
            .token_type = token_type,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn format(value: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} `{s}` {any}", .{ value.token_type, value.lexeme, value.literal });
    }
};

pub const TokenType = enum { string, number };

pub const Value = union(TokenType) { string: []const u8, number: f64 };

pub const Expr = struct {
    const Self = @This();
    acceptFn: fn (self: *const Self, visitor: *Visitor) ?Value,
    pub fn accept(self: *const Self, visitor: *Visitor) ?Value {
        return self.acceptFn(self, visitor);
    }
};

pub const LiteralExpr = struct {
    const Self = @This();
    expr: Expr = Expr{ .acceptFn = accept },
    value: Value,
    pub fn init(allocator: *Allocator, value: Value) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .value = value };
        return self;
    }
    pub fn accept(expr: *const Expr, visitor: *Visitor) ?Value {
        const self = @fieldParentPtr(Self, "expr", expr);
        return visitor.visitLiteralExpr(self.*);
    }
};

pub const GroupingExpr = struct {
    const Self = @This();
    expr: Expr = Expr{ .acceptFn = accept },
    expression: *Expr,
    pub fn init(allocator: *Allocator, expression: *Expr) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .expression = expression };
        return self;
    }
    pub fn accept(expr: *const Expr, visitor: *Visitor) ?Value {
        const self = @fieldParentPtr(Self, "expr", expr);
        return visitor.visitGroupingExpr(self.*);
    }
};

pub const Visitor = struct {
    const Self = @This();
    visitLiteralExprFn: fn (self: *Self, expr: LiteralExpr) ?Value,
    visitGroupingExprFn: fn (self: *Self, expr: GroupingExpr) ?Value,

    pub fn visitLiteralExpr(self: *Self, expr: LiteralExpr) ?Value {
        return self.visitLiteralExprFn(self, expr);
    }
    pub fn visitGroupingExpr(self: *Self, expr: GroupingExpr) ?Value {
        return self.visitGroupingExprFn(self, expr);
    }
};

pub const ResolveVisitor = struct {
    const Self = @This();
    visitor: Visitor = Visitor{
        .visitLiteralExprFn = visitLiteralExpr,
        .visitGroupingExprFn = visitGroupingExpr,
    },
    pub fn visitLiteralExpr(visitor: *Visitor, expr: LiteralExpr) ?Value {
        return expr.value;
    }
    pub fn visitGroupingExpr(visitor: *Visitor, expr: GroupingExpr) ?Value {
        const self = @fieldParentPtr(Self, "visitor", visitor);
        return expr.expression.accept(visitor);
    }
};

pub fn iterExprs(exprs: ArrayList(*Expr), visitor: *Visitor) void {
    for (exprs.items) |expr, i| {
        if (expr.accept(visitor)) |val| {
            std.debug.print("iter({d}): {any}\n", .{ i, val });
        }
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var tokens = ArrayList(Token).init(gpa);
    defer tokens.deinit();

    var lits = ArrayList(LiteralExpr).init(gpa);
    defer lits.deinit();

    var exprs = ArrayList(*Expr).init(gpa);
    defer exprs.deinit();

    {
        var token0 = Token.init(.string, "hi", Value{ .string = "hi" }, 1);
        try tokens.append(token0);
        try tokens.append(Token.init(.string, "world", Value{ .string = "world" }, 2));
        try tokens.append(Token.init(.number, "2.0", Value{ .number = 2.0 }, 3));
    }

    var rs = ResolveVisitor{};
    var visitor = &rs.visitor;

    for (tokens.items) |token, i| {
        var literalExpr = try LiteralExpr.init(gpa, token.literal.?);
        var group0 = try GroupingExpr.init(gpa, &literalExpr.expr);
        try exprs.append(&group0.expr);
        try exprs.append(&literalExpr.expr);
    }

    iterExprs(exprs, visitor);
    iterExprs(exprs, visitor);
}
