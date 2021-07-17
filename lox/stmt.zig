// **This file was generated by generate_ast.zig**

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Expr = @import("expr.zig").Expr;
const Token = @import("expr.zig").Token;

pub const Stmt = struct {
    const Self = @This();
    acceptFn: fn (self: *const Self, visitor: *Visitor) anyerror!void,
    pub fn accept(self: *const Self, visitor: *Visitor) anyerror!void {
        return self.acceptFn(self, visitor);
    }
};

pub const Visitor = struct {
    const Self = @This();
    visitExpressionStmtFn: fn (self: *Self, stmt: ExpressionStmt) anyerror!void,
    visitPrintStmtFn: fn (self: *Self, stmt: PrintStmt) anyerror!void,
    visitVarStmtFn: fn (self: *Self, stmt: VarStmt) anyerror!void,

    pub fn visitExpressionStmt(self: *Self, stmt: ExpressionStmt) anyerror!void {
        return self.visitExpressionStmtFn(self, stmt);
    }
    pub fn visitPrintStmt(self: *Self, stmt: PrintStmt) anyerror!void {
        return self.visitPrintStmtFn(self, stmt);
    }
    pub fn visitVarStmt(self: *Self, stmt: VarStmt) anyerror!void {
        return self.visitVarStmtFn(self, stmt);
    }
};

pub const ExpressionStmt = struct {
    const Self = @This();
    stmt: Stmt = Stmt{ .acceptFn = accept },

    expression: *Expr,

    pub fn init(allocator: *Allocator, expression: *Expr) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .expression = expression };
        return self;
    }
    pub fn accept(stmt: *const Stmt, visitor: *Visitor) anyerror!void {
        const self = @fieldParentPtr(Self, "stmt", stmt);
        return visitor.visitExpressionStmt(self.*);
    }
};

pub const PrintStmt = struct {
    const Self = @This();
    stmt: Stmt = Stmt{ .acceptFn = accept },

    expression: *Expr,

    pub fn init(allocator: *Allocator, expression: *Expr) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .expression = expression };
        return self;
    }
    pub fn accept(stmt: *const Stmt, visitor: *Visitor) anyerror!void {
        const self = @fieldParentPtr(Self, "stmt", stmt);
        return visitor.visitPrintStmt(self.*);
    }
};

pub const VarStmt = struct {
    const Self = @This();
    stmt: Stmt = Stmt{ .acceptFn = accept },

    name: Token,
    initializer: ?*Expr,

    pub fn init(allocator: *Allocator, name: Token, initializer: ?*Expr) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .name = name, .initializer = initializer };
        return self;
    }
    pub fn accept(stmt: *const Stmt, visitor: *Visitor) anyerror!void {
        const self = @fieldParentPtr(Self, "stmt", stmt);
        return visitor.visitVarStmt(self.*);
    }
};
