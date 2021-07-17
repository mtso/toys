const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;
const stdout = std.io.getStdOut().writer();

const Expr = @import("expr.zig").Expr;
const ExprVisitor = @import("expr.zig").Visitor;
const AssignExpr = @import("expr.zig").AssignExpr;
const BinaryExpr = @import("expr.zig").BinaryExpr;
const GroupingExpr = @import("expr.zig").GroupingExpr;
const LiteralExpr = @import("expr.zig").LiteralExpr;
const UnaryExpr = @import("expr.zig").UnaryExpr;
const VariableExpr = @import("expr.zig").VariableExpr;

const Stmt = @import("stmt.zig").Stmt;
const StmtVisitor = @import("stmt.zig").Visitor;
const ExpressionStmt = @import("stmt.zig").ExpressionStmt;
const PrintStmt = @import("stmt.zig").PrintStmt;
const VarStmt = @import("stmt.zig").VarStmt;

const Environment = @import("environment.zig").Environment;

// ===========
// Interpreter
// ===========

// missing_literal is for Literal Tokens
pub const LoxError = error{ invalid_syntax, alloc_err, missing_literal, runtime_error };

pub const Interpreter = struct {
    const Self = @This();
    exprVisitor: ExprVisitor = ExprVisitor{
        .visitAssignExprFn = visitAssignExpr,
        .visitBinaryExprFn = visitBinaryExpr,
        .visitGroupingExprFn = visitGroupingExpr,
        .visitLiteralExprFn = visitLiteralExpr,
        .visitUnaryExprFn = visitUnaryExpr,
        .visitVariableExprFn = visitVariableExpr,
    },
    stmtVisitor: StmtVisitor = StmtVisitor{
        .visitPrintStmtFn = visitPrintStmt,
        .visitExpressionStmtFn = visitExpressionStmt,
        .visitVarStmtFn = visitVarStmt,
    },
    allocator: *Allocator,
    environment: Environment,
    strings: ArrayList([]const u8),
    error_token: ?Token = null,
    error_message: ?[]const u8 = null,

    pub fn init(allocator: *Allocator) Self {
        return .{ .allocator = allocator, .strings = ArrayList([]const u8).init(allocator), .environment = Environment.init(allocator) };
    }
    pub fn deinit(self: *Self) void {
        for (self.strings.items) |s| {
            self.allocator.free(s);
        }
        self.strings.deinit();
        self.environment.deinit();
    }
    pub fn interpret(self: *Self, statements: ArrayList(*Stmt)) !void {
        for (statements.items) |statement| {
            try self.execute(statement);
        }
    }
    fn execute(self: *Self, stmt: *Stmt) !void {
        try stmt.accept(&self.stmtVisitor);
    }
    fn evaluate(self: *Self, expr: *Expr) ?Value {
        return expr.accept(&self.exprVisitor);
    }
    pub fn visitExpressionStmt(visitor: *StmtVisitor, stmt: ExpressionStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        _ = self.evaluate(stmt.expression) orelse return LoxError.runtime_error;
    }
    pub fn visitPrintStmt(visitor: *StmtVisitor, stmt: PrintStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        const value = self.evaluate(stmt.expression) orelse return LoxError.runtime_error;
        stdout.print("{?}\n", .{value}) catch |err| return LoxError.runtime_error;
    }
    pub fn visitVarStmt(visitor: *StmtVisitor, stmt: VarStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        if (stmt.initializer) |ini| {
            if (self.evaluate(ini)) |value| {
                return try self.environment.define(stmt.name.lexeme, value);
            }
        }
        try self.environment.define(stmt.name.lexeme, Value{ .Nil = null });
    }
    pub fn visitAssignExpr(visitor: *ExprVisitor, expr: AssignExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        var value = self.evaluate(expr.value) orelse return null;
        self.environment.assign(expr.name, value) catch |err| {
            // put this maybe into env
            // fixme
            // self.handleErr(expr.name, "Invalid assignment\n");
            return null;
        };
        return value;
    }
    pub fn visitBinaryExpr(visitor: *ExprVisitor, expr: BinaryExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        const left = self.evaluate(expr.left) orelse return null;
        const right = self.evaluate(expr.right) orelse return null;

        switch (expr.operator.token_type) {
            .EQUAL_EQUAL => return self.toBoolValue(self.isEqual(left, right)),
            .BANG_EQUAL => return self.toBoolValue(!self.isEqual(left, right)),
            .MINUS, .SLASH, .STAR, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL => {
                if (!self.checkNumberOperands(expr.operator, left, right)) return null;
                const leftN = self.number(left) orelse return null;
                const rightN = self.number(right) orelse return null;

                switch (expr.operator.token_type) {
                    .GREATER => return self.toBoolValue(leftN > rightN),
                    .GREATER_EQUAL => return self.toBoolValue(leftN >= rightN),
                    .LESS => return self.toBoolValue(leftN < rightN),
                    .LESS_EQUAL => return self.toBoolValue(leftN <= rightN),
                    .MINUS => return Value{ .Number = leftN - rightN },
                    .SLASH => return Value{ .Number = leftN / rightN },
                    .STAR => return Value{ .Number = leftN * rightN },
                    else => return null,
                }
            },
            .PLUS => if (self.number(left)) |leftN| {
                const rightN = self.number(right) orelse return self.save_error(expr.operator, "Operands must be two numbers or two strings.");
                return Value{ .Number = leftN + rightN };
            } else if (self.string(left)) |leftS| {
                const rightS = self.string(right) orelse return self.save_error(expr.operator, "Operands must be two numbers or two strings.");
                return Value{ .String = self.create_joined_string(leftS, rightS) orelse return null };
            },
            else => return null,
        }
        return null;
    }
    pub fn visitGroupingExpr(visitor: *ExprVisitor, expr: GroupingExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        return self.evaluate(expr.expression);
    }
    pub fn visitLiteralExpr(visitor: *ExprVisitor, expr: LiteralExpr) ?Value {
        return expr.value;
    }
    pub fn visitUnaryExpr(visitor: *ExprVisitor, expr: UnaryExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        const right = self.evaluate(expr.right) orelse return null;
        if (!self.checkNumberOperand(expr.operator, right)) return null;

        _ = switch (expr.operator.token_type) {
            // .BANG => return Value{.Bool = !self.isTruthy(right)},
            .BANG => return self.toBoolValue(!self.isTruthy(right)),
            .MINUS => return Value{ .Number = -(self.number(right) orelse return null) },
            // .MINUS => return Literal{ .NUMBER = -(self.number(right) orelse return null) },
            else => null,
        };

        return null;
    }
    pub fn visitVariableExpr(visitor: *ExprVisitor, expr: VariableExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        return self.environment.get(expr.name) catch |err| null;
    }
    pub fn checkNumberOperand(self: *Self, operator: Token, operand: Value) bool {
        _ = self.number(operand) orelse {
            _ = self.save_error(operator, "Operand must be a number.");
            return false;
        };
        return true;
    }
    pub fn checkNumberOperands(self: *Self, operator: Token, left: Value, right: Value) bool {
        _ = self.number(left) orelse {
            _ = self.save_error(operator, "Operands must be numbers.");
            return false;
        };
        _ = self.number(right) orelse {
            _ = self.save_error(operator, "Operands must be numbers.");
            return false;
        };
        return true;
    }
    fn isEqual(self: *Self, left: Value, right: Value) bool {
        if (self.number(left)) |leftN| {
            const rightN = self.number(right) orelse return false;
            return leftN == rightN;
        } else if (self.string(left)) |leftS| {
            const rightS = self.string(right) orelse return false;
            return std.mem.eql(u8, leftS, rightS);
        } else if (self.boolean(left)) |leftB| {
            const rightB = self.boolean(right) orelse return false;
            return leftB == rightB;
        } else if (Value.Nil == left and Value.Nil == right) {
            return true;
        }
        return false;
    }
    fn toBoolValue(self: *Self, value: bool) Value {
        return Value{ .Bool = value };
    }
    fn boolean(self: *Self, value: Value) ?bool {
        switch (value) {
            .Bool => |v| return v,
            else => return null,
        }
    }
    fn number(self: *Self, value: Value) ?f64 {
        switch (value) {
            .Number => |n| return n,
            else => return null,
        }
    }
    fn string(self: *Self, value: Value) ?[]const u8 {
        const bytes = switch (value) {
            .String => |bytes| bytes,
            else => return null,
        };

        var buf = self.allocator.alloc(u8, bytes.len) catch |err| {
            std.debug.print("Failed to alloc string, returning null. {e}", .{err});
            return null;
        };
        const replacements = std.mem.replace(u8, bytes, "\\n", "\n", buf);
        if (replacements > 0) {
            self.strings.append(buf) catch |err| {
                std.debug.print("Failed to store string, returning null. {e}", .{err});
                return null;
            };
            return buf[0 .. bytes.len - replacements];
        } else {
            self.allocator.free(buf);
            return bytes;
        }
    }
    fn isTruthy(self: *Self, value: Value) bool {
        return switch (value) {
            .Bool => |b| b,
            .String, .Number => true,
            else => false,
        };
    }
    fn create_joined_string(self: *Self, left: []const u8, right: []const u8) ?[]u8 {
        var joined = self.allocator.alloc(u8, left.len + right.len) catch |err| {
            std.debug.print("Failed to alloc string, returning null. {e}", .{err});
            return null;
        };
        _ = std.fmt.bufPrint(joined, "{s}{s}", .{ left, right }) catch |err| {
            std.debug.print("Failed to format string, returning null. {e}", .{err});
            return null;
        };
        _ = self.strings.append(joined) catch |err| {
            std.debug.print("Failed to store string, returning null. {e}", .{err});
            return null;
        };
        return joined;
    }
    fn save_error(self: *Self, token: Token, message: []const u8) ?Value {
        self.error_token = token;
        self.error_message = message;
        return null;
    }
};

test "interpreter" {
    const test_allocator = std.testing.allocator;
    var tokens = ArrayList(Token).init(test_allocator);
    try tokens.append(Token.init(.LEFT_PAREN, "(", .LEFT_PAREN, 1));
    try tokens.append(Token.init(.NUMBER, "2.0", Literal{ .NUMBER = 2.0 }, 1));
    try tokens.append(Token.init(.GREATER, ">", .GREATER, 1));
    try tokens.append(Token.init(.NUMBER, "3.0", Literal{ .NUMBER = 3.0 }, 1));
    try tokens.append(Token.init(.EQUAL_EQUAL, "==", .EQUAL_EQUAL, 1));
    try tokens.append(Token.init(.NUMBER, "4.0", Literal{ .NUMBER = 4.0 }, 1));
    try tokens.append(Token.init(.RIGHT_PAREN, ")", .RIGHT_PAREN, 1));
    try tokens.append(Token.init(.SEMICOLON, ";", .SEMICOLON, 1));
    defer tokens.deinit();
    var parser = Parser.init(test_allocator, tokens);
    defer parser.deinit();

    // Should succeed.
    const exp = (try parser.parse()) orelse return;
    // var interpreter = Interpreter.init(test_allocator);
    // defer interpreter.deinit();
    // try interpreter.interpret(exp);
}

// ======
// Parser
// ======

test "Parser recursive-descent missing semicolon after statement" {
    var test_allocator = std.testing.allocator;
    var tokens = ArrayList(Token).init(test_allocator);
    defer tokens.deinit();
    try tokens.append(Token.init(.LEFT_PAREN, "(", .LEFT_PAREN, 1));
    try tokens.append(Token.init(.NUMBER, "2.0", Literal{ .NUMBER = 2.0 }, 1));
    try tokens.append(Token.init(.GREATER, ">", .GREATER, 1));
    try tokens.append(Token.init(.NUMBER, "3.0", Literal{ .NUMBER = 3.0 }, 1));
    try tokens.append(Token.init(.EQUAL_EQUAL, "==", .EQUAL_EQUAL, 1));
    try tokens.append(Token.init(.NUMBER, "4.0", Literal{ .NUMBER = 4.0 }, 1));
    try tokens.append(Token.init(.RIGHT_PAREN, ")", .RIGHT_PAREN, 1));
    try tokens.append(Token.init(.SEMICOLON, ";", .SEMICOLON, 1));
    try tokens.append(Token.init(.LEFT_PAREN, "(", .LEFT_PAREN, 1));
    try tokens.append(Token.init(.NUMBER, "2.0", Literal{ .NUMBER = 2.0 }, 1));
    try tokens.append(Token.init(.GREATER, ">", .GREATER, 1));
    try tokens.append(Token.init(.NUMBER, "3.0", Literal{ .NUMBER = 3.0 }, 1));
    try tokens.append(Token.init(.EQUAL_EQUAL, "==", .EQUAL_EQUAL, 1));
    try tokens.append(Token.init(.NUMBER, "4.0", Literal{ .NUMBER = 4.0 }, 1));
    try tokens.append(Token.init(.RIGHT_PAREN, ")", .RIGHT_PAREN, 1));
    try tokens.append(Token.init(.EOF, "0", .EOF, 1));
    var parser = Parser.init(test_allocator, tokens);
    defer parser.deinit();
    const statements = try parser.parse();
    try std.testing.expect(true == hadError);
}

test "Parser recursive-descent" {
    var test_allocator = std.testing.allocator;
    var tokens = ArrayList(Token).init(test_allocator);
    try tokens.append(Token.init(.LEFT_PAREN, "(", .LEFT_PAREN, 1));
    try tokens.append(Token.init(.NUMBER, "2.0", Literal{ .NUMBER = 2.0 }, 1));
    try tokens.append(Token.init(.GREATER, ">", .GREATER, 1));
    try tokens.append(Token.init(.NUMBER, "3.0", Literal{ .NUMBER = 3.0 }, 1));
    try tokens.append(Token.init(.EQUAL_EQUAL, "==", .EQUAL_EQUAL, 1));
    try tokens.append(Token.init(.NUMBER, "4.0", Literal{ .NUMBER = 4.0 }, 1));
    try tokens.append(Token.init(.RIGHT_PAREN, ")", .RIGHT_PAREN, 1));
    try tokens.append(Token.init(.SEMICOLON, ";", .SEMICOLON, 1));
    try tokens.append(Token.init(.EOF, "0", .EOF, 1));
    defer tokens.deinit();
    var parser = Parser.init(test_allocator, tokens);
    defer parser.deinit();
    // Should succeed.
    const statements = (try parser.parse()).?;
    var interpreter = Interpreter.init(test_allocator);
    defer interpreter.deinit();
    try interpreter.interpret(statements);
}

pub const Parser = struct {
    const Self = @This();
    const Err = LoxError;

    allocator: *Allocator,
    tokens: ArrayList(Token),
    current: usize = 0,
    statements: ArrayList(*Stmt),

    error_token: ?Token = null,
    error_message: ?[]const u8 = null,

    pub fn init(allocator: *Allocator, tokens: ArrayList(Token)) Parser {
        return .{ .allocator = allocator, .tokens = tokens, .statements = ArrayList(*Stmt).init(allocator) };
    }

    pub fn deinit(self: *Parser) void {
        const deiniter = &DeinitVisitor.init(self.allocator);
        for (self.statements.items) |stmt| {
            stmt.accept(&deiniter.stmtVisitor) catch |err| {
                std.debug.print("deinit error: {any}\n", .{err});
            };
        }
        self.statements.deinit();
    }

    pub fn parse(self: *Parser) !?ArrayList(*Stmt) {
        while (!self.isAtEnd()) {
            const dec = self.declaration() catch |err| {
                continue;
            };
            if (dec) |stmt| {
                self.statements.append(stmt) catch {
                    return Self.Err.alloc_err;
                };
            }
        }
        return self.statements;
    }

    fn expression(self: *Parser) !*Expr {
        return try self.assignment();
    }

    fn declaration(self: *Parser) !?*Stmt {
        if (self.match(.VAR)) {
            return self.varDeclaration() catch |err| {
                try self.synchronize();
                return null;
            };
        }
        return self.statement() catch |err| {
            try self.synchronize();
            return null;
        };
    }

    fn statement(self: *Parser) !*Stmt {
        if (self.match(.PRINT)) return self.printStatement();
        return self.expressionStatement();
    }

    fn printStatement(self: *Parser) !*Stmt {
        const expr = try self.expression();
        _ = self.consume(.SEMICOLON, "Expect ';' after value.") catch |err| {
            return self.rewindErr(expr, err);
        };
        return &(try PrintStmt.init(self.allocator, expr)).stmt;
    }

    fn varDeclaration(self: *Parser) !*Stmt {
        var name = try self.consume(.IDENTIFIER, "Expect variable name.");
        var initializer: ?*Expr = null;
        if (self.match(.EQUAL)) {
            initializer = try self.expression();
        }
        _ = self.consume(.SEMICOLON, "Expect ';' after variable declaration.") catch |err| {
            if (initializer) |i| {
                return self.rewindErr(i, err);
            } else {
                return err;
            }
        };
        const stmt = try VarStmt.init(self.allocator, name, initializer);
        return &stmt.stmt;
    }

    fn expressionStatement(self: *Parser) !*Stmt {
        const expr = try self.expression();
        _ = self.consume(.SEMICOLON, "Expect ';' after value.") catch |err| {
            std.debug.print("inexprStmt ", .{});
            return self.rewindErr(expr, err);
        };
        return &(try ExpressionStmt.init(self.allocator, expr)).stmt;
    }

    fn assignment(self: *Parser) LoxError!*Expr {
        var exp: *Expr = try self.equality();
        // std.debug.print("inassign0 {?}\n", .{exp});
        if (self.match(.EQUAL)) {
            var equals = try self.previous();
            std.debug.print("inassign {?}\n", .{equals});
            var value = self.assignment() catch |err| {
                return self.rewindErr(exp, err);
            };
            if (std.mem.eql(u8, exp.name, "VariableExpr")) {
                var name = try self.previous2();
                //  exp.getToken();
                // if (null == name) {
                //     std.debug.print("{?}\n", .{exp});
                // }
                // var name = exp.getToken().?;
                //  Token.init(.IDENTIFIER, "a", Literal{.IDENTIFIER = "a"}, 5)
                const expP = AssignExpr.init(self.allocator, name, value) catch |err| {
                    std.debug.print("whatisthis {any}\n", .{exp});
                    return self.rewindErr(exp, LoxError.alloc_err);
                };
                return &expP.expr;
            }
            self.handleError(equals, "Invalid assignment target.");
            return LoxError.runtime_error;
        }
        return exp;
    }

    fn equality(self: *Parser) !*Expr {
        var exp: *Expr = try self.comparison();
        while (self.matchAny(([_]TokenType{ .BANG_EQUAL, .EQUAL_EQUAL })[0..])) {
            var operator = try self.previous();
            var right = self.comparison() catch |err| {
                return self.rewindErr(exp, err);
            };
            var expP = BinaryExpr.init(self.allocator, exp, operator, right) catch {
                return Self.Err.alloc_err;
            };
            exp = &expP.expr;
        }
        return exp;
    }

    fn comparison(self: *Parser) !*Expr {
        var exp: *Expr = try self.term();
        while (self.matchAny(([_]TokenType{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })[0..])) {
            var operator = try self.previous();
            var right = self.term() catch |err| {
                return self.rewindErr(exp, err);
            };
            var expP = BinaryExpr.init(self.allocator, exp, operator, right) catch {
                return Self.Err.alloc_err;
            };
            exp = &expP.expr;
        }
        return exp;
    }

    fn term(self: *Parser) !*Expr {
        var exp: *Expr = try self.factor();
        while (self.matchAny(([_]TokenType{ .MINUS, .PLUS })[0..])) {
            var operator = try self.previous();
            var right = self.factor() catch |err| {
                return self.rewindErr(exp, err);
            };
            var expP = BinaryExpr.init(self.allocator, exp, operator, right) catch {
                return Self.Err.alloc_err;
            };
            exp = &expP.expr;
        }
        return exp;
    }

    fn factor(self: *Parser) !*Expr {
        var exp: *Expr = try self.unary();
        while (self.matchAny(([_]TokenType{ .SLASH, .STAR })[0..])) {
            var operator = try self.previous();
            var right = self.unary() catch |err| {
                return self.rewindErr(exp, err);
            };
            var expP = BinaryExpr.init(self.allocator, exp, operator, right) catch {
                return Self.Err.alloc_err;
            };
            exp = &expP.expr;
        }
        return exp;
    }

    fn unary(self: *Parser) Err!*Expr {
        while (self.matchAny(([_]TokenType{ .BANG, .MINUS })[0..])) {
            const operator = try self.previous();
            const right = try self.unary();
            const exp = UnaryExpr.init(self.allocator, operator, right) catch {
                return Self.Err.alloc_err;
            };
            return &exp.expr;
        }
        return try self.primary();
    }

    // TODO: Convert Literal to Value here or have another converter in the Interpreter???
    fn primary(self: *Parser) Err!*Expr {
        if (self.match(.FALSE)) {
            const exp = LiteralExpr.init(self.allocator, Value{ .Bool = false }) catch {
                return Self.Err.alloc_err;
            };
            return &exp.expr;
        }
        if (self.match(.TRUE)) {
            const exp = LiteralExpr.init(self.allocator, Value{ .Bool = true }) catch {
                return Self.Err.alloc_err;
            };
            return &exp.expr;
        }
        if (self.match(.NIL)) {
            const exp = LiteralExpr.init(self.allocator, Value{ .Nil = null }) catch {
                return Self.Err.alloc_err;
            };
            return &exp.expr;
        }

        if (self.match(.NUMBER)) {
            const prev = try self.previous();
            if (prev.literal) |literal| {
                const exp = LiteralExpr.init(self.allocator, Value.from(literal)) catch {
                    return Self.Err.alloc_err;
                };
                return &exp.expr;
            } else {
                return Self.Err.missing_literal;
            }
        }
        if (self.match(.STRING)) {
            const prev = try self.previous();
            if (prev.literal) |literal| {
                const exp = LiteralExpr.init(self.allocator, Value.from(literal)) catch {
                    return Self.Err.alloc_err;
                };
                return &exp.expr;
            } else {
                return Self.Err.missing_literal;
            }
        }

        if (self.match(.IDENTIFIER)) {
            var name = try self.previous();
            std.debug.print("foundId {?} l={d}\n", .{ name, name.line });
            const exp = VariableExpr.init(self.allocator, name) catch |err| {
                return Self.Err.alloc_err;
            };
            return &exp.expr;
        }

        if (self.match(.LEFT_PAREN)) {
            const exp = try self.expression();
            _ = self.consume(.RIGHT_PAREN, "Expect ')' after expression.") catch |err| {
                return self.rewindErr(exp, err);
            };
            const expP = GroupingExpr.init(self.allocator, exp) catch {
                return Self.Err.alloc_err;
            };
            return &expP.expr;
        }

        self.handleError(try self.peek(), "Expect expression.");
        return Self.Err.invalid_syntax;
    }

    // Deinitializes an Expr before returning the bubbled error.
    // Consider using actual result struct to contain: (err, value, exprs)
    // Other naïve approach is to store all Expr/Stmt in a list and iterate through
    // all to deinit rather than use visitor.
    fn rewindErr(self: *Parser, expr: *Expr, err: Self.Err) Self.Err {
        var deiniter = DeinitVisitor.init(self.allocator);
        _ = expr.accept(&deiniter.exprVisitor);
        return err;
    }

    fn handleError(self: *Parser, token: Token, message: []const u8) void {
        self.error_token = token;
        self.error_message = message;
        if (token.token_type == .EOF) {
            report(token.line, " at end", message);
        } else {
            var full_message: [100]u8 = undefined;
            const fmt_slice = full_message[0 .. 6 + token.lexeme.len];
            _ = std.fmt.bufPrint(fmt_slice, " at '{s}'", .{token.lexeme}) catch {
                return;
            };
            report(token.line, fmt_slice, message);
        }
    }

    fn synchronize(self: *Parser) !void {
        _ = try self.advance();
        while (!self.isAtEnd()) {
            if ((try self.previous()).token_type == .SEMICOLON) return;

            _ = switch ((try self.peek()).token_type) {
                .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN => return,
                else => try self.advance(),
            };
        }
    }

    fn matchAny(self: *Parser, types: []const TokenType) bool {
        for (types) |typ| {
            if (self.check(typ)) {
                _ = self.advance() catch {
                    return false;
                };
                return true;
            }
        }
        return false;
    }

    fn match(self: *Parser, typ: TokenType) bool {
        if (self.check(typ)) {
            _ = self.advance() catch {
                return false;
            };
            return true;
        }
        return false;
    }

    fn check(self: *Parser, tt: TokenType) bool {
        if (self.isAtEnd()) return false;
        if (self.peek()) |t| {
            return t.token_type == tt;
        } else |_| {
            return false;
        }
    }

    fn advance(self: *Parser) !Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }
        return try self.previous();
    }

    fn consume(self: *Parser, ttype: TokenType, message: []const u8) !Token {
        if (self.check(ttype)) return try self.advance();
        self.handleError(try self.peek(), message);
        return Self.Err.invalid_syntax;
    }

    fn previous(self: *Parser) Err!Token {
        if (self.current <= 0 or self.tokens.items.len < 1) return Self.Err.invalid_syntax;
        return self.tokens.items[self.current - 1];
    }

    fn previous2(self: *Parser) Err!Token {
        if (self.current <= 1 or self.tokens.items.len < 2) return Self.Err.invalid_syntax;
        return self.tokens.items[self.current - 2];
    }

    fn isAtEnd(self: *Parser) bool {
        if (self.peek()) |token| {
            return token.token_type == .EOF;
        } else |_| {
            return true;
        }
    }

    fn peek(self: *Parser) Err!Token {
        if (self.current < self.tokens.items.len) {
            return self.tokens.items[self.current];
        } else {
            return Self.Err.invalid_syntax;
        }
    }
};

/// Deinitializes an ast.
pub const DeinitVisitor = struct {
    const Self = @This();
    exprVisitor: ExprVisitor = ExprVisitor{
        .visitAssignExprFn = visitAssignExpr,
        .visitBinaryExprFn = visitBinaryExpr,
        .visitGroupingExprFn = visitGroupingExpr,
        .visitLiteralExprFn = visitLiteralExpr,
        .visitUnaryExprFn = visitUnaryExpr,
        .visitVariableExprFn = visitVariableExpr,
    },
    stmtVisitor: StmtVisitor = StmtVisitor{
        .visitExpressionStmtFn = visitExpressionStmt,
        .visitPrintStmtFn = visitPrintStmt,
        .visitVarStmtFn = visitVarStmt,
    },
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) Self {
        return .{ .allocator = allocator };
    }
    pub fn deinitExpr(self: *Self, expr: *Expr) void {
        _ = expr.accept(&self.exprVisitor);
    }
    pub fn visitExpressionStmt(visitor: *StmtVisitor, stmt: ExpressionStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        _ = stmt.expression.accept(&self.exprVisitor);
        self.allocator.destroy(&stmt);
    }
    pub fn visitPrintStmt(visitor: *StmtVisitor, stmt: PrintStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        _ = stmt.expression.accept(&self.exprVisitor);
        self.allocator.destroy(&stmt);
    }
    pub fn visitVarStmt(visitor: *StmtVisitor, stmt: VarStmt) !void {
        const self = @fieldParentPtr(Self, "stmtVisitor", visitor);
        if (stmt.initializer) |ini| {
            _ = ini.accept(&self.exprVisitor);
        }
        self.allocator.destroy(&stmt);
    }
    pub fn visitAssignExpr(visitor: *ExprVisitor, expr: AssignExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        _ = expr.value.accept(visitor);
        _ = self.allocator.destroy(&expr);
        return null;
    }
    pub fn visitBinaryExpr(visitor: *ExprVisitor, expr: BinaryExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        _ = expr.left.accept(visitor);
        _ = expr.right.accept(visitor);
        _ = self.allocator.destroy(&expr);
        return null;
    }
    pub fn visitGroupingExpr(visitor: *ExprVisitor, expr: GroupingExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        _ = expr.expression.accept(visitor);
        _ = self.allocator.destroy(&expr);
        return null;
    }
    pub fn visitLiteralExpr(visitor: *ExprVisitor, expr: LiteralExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        self.allocator.destroy(&expr);
        return null;
    }
    pub fn visitUnaryExpr(visitor: *ExprVisitor, expr: UnaryExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        _ = expr.right.accept(visitor);
        _ = self.allocator.destroy(&expr);
        return null;
    }
    pub fn visitVariableExpr(visitor: *ExprVisitor, expr: VariableExpr) ?Value {
        const self = @fieldParentPtr(Self, "exprVisitor", visitor);
        _ = self.allocator.destroy(&expr);
        return null;
    }
};

pub const AstPrinter = struct {
    const Self = @This();
    visitor: ExprVisitor = ExprVisitor{
        .visitAssignExprFn = visitAssignExpr,
        .visitBinaryExprFn = visitBinaryExpr,
        .visitGroupingExprFn = visitGroupingExpr,
        .visitLiteralExprFn = visitLiteralExpr,
        .visitUnaryExprFn = visitUnaryExpr,
        .visitVariableExprFn = visitVariableExpr,
    },

    pub fn print(self: *Self, expr: *Expr) void {
        _ = expr.accept(&self.visitor);
        std.debug.print("\n", .{});
    }
    pub fn visitAssignExpr(visitor: *ExprVisitor, expr: AssignExpr) ?Value {
        std.debug.print("(<assign> {s} ", .{expr.name.lexeme});
        _ = expr.value.accept(visitor);
        std.debug.print(")", .{});
        return null;
    }
    pub fn visitBinaryExpr(visitor: *ExprVisitor, expr: BinaryExpr) ?Value {
        std.debug.print("({s} ", .{expr.operator.lexeme});
        _ = expr.left.accept(visitor);
        std.debug.print(" ", .{});
        _ = expr.right.accept(visitor);
        std.debug.print(")", .{});
        return null;
    }
    pub fn visitGroupingExpr(visitor: *ExprVisitor, expr: GroupingExpr) ?Value {
        std.debug.print("(<group> ", .{});
        _ = expr.expression.accept(visitor);
        std.debug.print(")", .{});
        return null;
    }
    pub fn visitLiteralExpr(visitor: *ExprVisitor, expr: LiteralExpr) ?Value {
        _ = switch (expr.value) {
            .String => |s| std.debug.print("{s}", .{s}),
            .Number => |n| std.debug.print("{e}", .{n}),
            .Identifier => |s| std.debug.print("`{s}`", .{s}),
            else => std.debug.print("nil", .{}),
        };
        return expr.value;
    }
    pub fn visitUnaryExpr(visitor: *ExprVisitor, expr: UnaryExpr) ?Value {
        std.debug.print("({s} ", .{expr.operator.lexeme});
        _ = expr.right.accept(visitor);
        std.debug.print(")", .{});
        return null;
    }
    pub fn visitVariableExpr(visitor: *ExprVisitor, expr: VariableExpr) ?Value {
        const self = @fieldParentPtr(Self, "visitor", visitor);
        std.debug.print("(<variable> {s})", .{expr.name.lexeme});
        return null;
    }
};

test "eq" {
    const test_allocator = std.testing.allocator;
    var interpreter = Interpreter.init(test_allocator);
    defer interpreter.deinit();
    const val1 = Value{ .String = "what" };
    const val2 = Value{ .String = "what" };
    try std.testing.expect(interpreter.isEqual(val1, val2));
}

test "num" {
    const test_allocator = std.testing.allocator;
    var tokens = ArrayList(Token).init(test_allocator);
    try tokens.append(Token.init(.MINUS, "-", .MINUS, 1));
    try tokens.append(Token.init(.NUMBER, "3.0", Literal{ .NUMBER = 3.0 }, 1));
    try tokens.append(Token.init(.SEMICOLON, ";", .SEMICOLON, 1));
    try tokens.append(Token.init(.EOF, "0", .EOF, 1));
    defer tokens.deinit();
    var parser = Parser.init(test_allocator, tokens);
    defer parser.deinit();
    const exp = (try parser.parse()).?;
    var interpreter = Interpreter.init(test_allocator);
    try interpreter.interpret(exp);
}

test "deinit" {
    const test_allocator = std.testing.allocator;
    var tokens = ArrayList(Token).init(test_allocator);
    defer tokens.deinit();
    try tokens.append(Token.init(.STRING, "hello ", Literal{ .STRING = "hello " }, 1));
    try tokens.append(Token.init(.PLUS, "+", .PLUS, 1));
    try tokens.append(Token.init(.STRING, "world", Literal{ .STRING = "world" }, 1));
    try tokens.append(Token.init(.SEMICOLON, ";", .SEMICOLON, 1));
    try tokens.append(Token.init(.EOF, "0", .EOF, 1));
    var parser = Parser.init(test_allocator, tokens);
    defer parser.deinit();
    const exp = (try parser.parse()).?;
    var interpreter = Interpreter.init(test_allocator);
    defer interpreter.deinit();
    try interpreter.interpret(exp);
}

pub const ValueType = enum {
    Identifier,
    String,
    Number,
    Bool,
    Nil,
};

pub const Value = union(ValueType) {
    Identifier: []const u8,
    String: []const u8,
    Number: f64,
    Bool: bool,
    Nil: ?void,

    pub fn from(literal: Literal) Value {
        return switch (literal) {
            .IDENTIFIER => |s| Value{ .Identifier = s },
            .STRING => |s| Value{ .String = s },
            .NUMBER => |n| Value{ .Number = n },
            .TRUE, .FALSE => |b| Value{ .Bool = b },
            else => Value{ .Nil = null },
        };
    }

    pub fn format(value: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .String => |s| try writer.print("{s}", .{s}),
            .Number => |e| {
                var buf: [32]u8 = undefined;
                const slice = buf[0..];
                const num = try std.fmt.bufPrint(slice, "{e}", .{e});
                const parts = &std.mem.split(num, "e+");
                const first = parts.next() orelse return try writer.print("{e}", .{e});
                const digit = &std.mem.split(first, ".");
                const potentialInt = digit.next() orelse return try writer.print("{e}", .{e});
                const fraction = digit.next() orelse return try writer.print("{e}", .{e});
                if (allMatch(fraction, '0')) {
                    if (parts.next()) |second| {
                        if (allMatch(second, '0')) {
                            return try writer.print("{s}", .{potentialInt});
                        }
                    }
                }
                try writer.print("{e}", .{e});
            },
            .Bool => |b| try writer.print("{any}", .{b}),
            .Nil => try writer.print("nil", .{}),
            .Identifier => |s| try writer.print("id({s})", .{s}),
        }
    }

    pub fn allMatch(buf: []const u8, flag: u8) bool {
        for (buf) |c| {
            if (c != flag) {
                return false;
            }
        }
        return true;
    }
};

const TokenType = enum {
// Single-character tokens.
    LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE, COMMA, DOT, MINUS, PLUS, SEMICOLON, SLASH, STAR,
    // One or two character tokens.
    BANG, BANG_EQUAL, EQUAL, EQUAL_EQUAL, GREATER, GREATER_EQUAL, LESS, LESS_EQUAL,
    // Literals.
    IDENTIFIER, STRING, NUMBER,
    // Keywords.
    AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR, PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE, EOF
};

pub const Literal = union(TokenType) {
// literals
    IDENTIFIER: []const u8, STRING: []const u8, NUMBER: f64, FALSE: bool, TRUE: bool, NIL: ?void,
    // non-literals
    LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE, COMMA, DOT, MINUS, PLUS, SEMICOLON, SLASH, STAR, BANG, BANG_EQUAL, EQUAL, EQUAL_EQUAL, GREATER, GREATER_EQUAL, LESS, LESS_EQUAL, AND, CLASS, ELSE, FUN, FOR, IF, OR, PRINT, RETURN, SUPER, THIS, VAR, WHILE, EOF
};

pub const Token = struct {
    token_type: TokenType,
    lexeme: []const u8,
    literal: ?Literal,
    line: u32,

    pub fn init(token_type: TokenType, lexeme: []const u8, literal: ?Literal, line: u32) Token {
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

const Scanner = struct {
    const Keywords = ComptimeStringMap(TokenType, &[_]struct {
        @"0": []const u8,
        @"1": TokenType,
    }{
        .{ .@"0" = "and", .@"1" = .AND },
        .{ .@"0" = "class", .@"1" = .CLASS },
        .{ .@"0" = "else", .@"1" = .ELSE },
        .{ .@"0" = "false", .@"1" = .FALSE },
        .{ .@"0" = "for", .@"1" = .FOR },
        .{ .@"0" = "fun", .@"1" = .FUN },
        .{ .@"0" = "if", .@"1" = .IF },
        .{ .@"0" = "nil", .@"1" = .NIL },
        .{ .@"0" = "or", .@"1" = .OR },
        .{ .@"0" = "print", .@"1" = .PRINT },
        .{ .@"0" = "return", .@"1" = .RETURN },
        .{ .@"0" = "super", .@"1" = .SUPER },
        .{ .@"0" = "this", .@"1" = .THIS },
        .{ .@"0" = "true", .@"1" = .TRUE },
        .{ .@"0" = "var", .@"1" = .VAR },
        .{ .@"0" = "while", .@"1" = .WHILE },
    });

    source: []u8,
    tokens: ArrayList(Token),
    start: u32 = 0,
    current: u32 = 0,
    line: u32 = 1,

    pub fn init(source: []u8, tokens: ArrayList(Token)) Scanner {
        return .{ .source = source, .tokens = tokens };
    }

    pub fn scanTokens(self: *Scanner) !ArrayList(Token) {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(Token.init(.EOF, "", .EOF, self.line));
        return self.tokens;
    }

    fn scanToken(self: *Scanner) !void {
        var c = self.advance();
        _ = switch (c) {
            '(' => try self.addToken(.LEFT_PAREN),
            ')' => try self.addToken(.RIGHT_PAREN),
            '{' => try self.addToken(.LEFT_BRACE),
            '}' => try self.addToken(.RIGHT_BRACE),
            ',' => try self.addToken(.COMMA),
            '.' => try self.addToken(.DOT),
            '-' => try self.addToken(.MINUS),
            '+' => try self.addToken(.PLUS),
            ';' => try self.addToken(.SEMICOLON),
            '*' => try self.addToken(.STAR),
            '!' => if (self.match('=')) {
                try self.addToken(.BANG_EQUAL);
            } else {
                try self.addToken(.BANG);
            },
            '=' => if (self.match('=')) {
                try self.addToken(.EQUAL_EQUAL);
            } else {
                try self.addToken(.EQUAL);
            },
            '>' => if (self.match('=')) {
                try self.addToken(.GREATER_EQUAL);
            } else {
                try self.addToken(.GREATER);
            },
            '<' => if (self.match('=')) {
                try self.addToken(.LESS_EQUAL);
            } else {
                try self.addToken(.LESS);
            },
            '/' => if (self.match('/')) {
                while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
            } else {
                try self.addToken(.SLASH);
            },
            ' ', '\r', '\t' => void,
            '\n' => self.line += 1,
            '"' => try self.string(),
            '0'...'9' => try self.number(),
            'a'...'z', 'A'...'Z', '_' => try self.identifier(),
            else => reportErr(self.line, "Unexpected character."),
        };
    }

    fn identifier(self: *Scanner) !void {
        while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();

        const text = self.source[self.start..self.current];
        if (Keywords.get(text)) |typ| {
            try self.addToken(typ);
        } else {
            try self.addTokenLiteral(.IDENTIFIER, .{ .IDENTIFIER = text });
        }
    }

    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (isDigit(self.peek())) _ = self.advance();
        }

        const num = try std.fmt.parseFloat(f64, self.source[self.start..self.current]);
        try self.addTokenLiteral(.NUMBER, .{ .NUMBER = num });
    }

    fn isDigit(char: u8) bool {
        return char >= '0' and char <= '9';
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
    }

    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            // if (self.peek() == '\\' and self.peekNext() == 'n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            reportErr(self.line, "Unterminated string.");
            return;
        }

        _ = self.advance();

        var value = self.source[self.start + 1 .. self.current - 1];
        try self.addTokenLiteral(.STRING, .{ .STRING = value });
    }

    fn advance(self: *Scanner) u8 {
        var c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (expected != self.source[self.current]) return false;

        self.current += 1;
        return true;
    }

    fn peek(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn addToken(self: *Scanner, typ: TokenType) !void {
        var text = self.source[self.start..self.current];
        try self.tokens.append(Token.init(typ, text, null, self.line));
    }

    fn addTokenLiteral(self: *Scanner, typ: TokenType, literal: Literal) !void {
        var text = self.source[self.start..self.current];
        try self.tokens.append(Token.init(typ, text, literal, self.line));
    }

    fn isAtEnd(self: Scanner) bool {
        return self.current >= self.source.len;
    }
};

var hadError = false;
fn report(line: u32, where: []const u8, message: []const u8) void {
    std.debug.print("[line {d}] Error{s}: {s}\n", .{ line, where, message });
    hadError = true;
}

fn reportErr(line: u32, message: []const u8) void {
    report(line, "", message);
}

fn run(allocator: *Allocator, source: []u8) !bool {
    var list = ArrayList(Token).init(allocator);
    defer list.deinit();

    var scanner = Scanner.init(source, list);
    const tokens = try scanner.scanTokens();
    if (false) {
        for (tokens.items) |token| {
            std.debug.print("{?}\n", .{token});
        }
    }

    var parser = Parser.init(allocator, tokens);
    defer parser.deinit();

    const result = try parser.parse();
    if (hadError) return false;
    if (null == result) return false;

    if (false) {
        var printer = AstPrinter{};
        printer.print(result.?);
    }

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    try interpreter.interpret(result.?);
    return true;
}

fn runFile(allocator: *Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    defer file.close();

    const contents = try file.reader().readAllAlloc(allocator, 4096 * 16);
    const success = try run(allocator, contents);

    if (hadError) std.os.exit(65); // parse errror
    if (!success) std.os.exit(70); // runtime error
}

fn promptStmt(buf: []u8) !?[]u8 {
    const readUntil = std.io.getStdIn().reader().readUntilDelimiterOrEof;
    try stdout.print("> ", .{});
    return try readUntil(buf, '\n');
}

fn runPrompt(allocator: *Allocator) !void {
    var buf: [4096]u8 = undefined;
    while (try promptStmt(&buf)) |line| {
        _ = run(allocator, line) catch |err| {
            _ = switch (err) {
                Parser.Err.invalid_syntax => null,
                else => return err,
            };
        };
        hadError = false;
    }
}

test "AstPrinter" {
    var test_allocator = std.testing.allocator;
    var exp =
        try BinaryExpr.init(test_allocator, &(try UnaryExpr.init(test_allocator, Token.init(.MINUS, "-", null, 1), &(try LiteralExpr.init(test_allocator, Value{ .Number = 123 })).expr)).expr, Token.init(.STAR, "*", null, 1), &(try GroupingExpr.init(test_allocator, &(try LiteralExpr.init(test_allocator, Value{ .Number = 45.67 })).expr)).expr);

    var astp = AstPrinter{};
    defer DeinitVisitor.init(test_allocator).deinitExpr(&exp.expr);
    _ = astp.print(&exp.expr);
}

pub fn main() !u8 {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len > 2) {
        try stdout.print("Usage: zlox [script]\n", .{});
        return 64;
    } else if (2 == args.len) {
        try runFile(gpa, args[1]);
    } else {
        try runPrompt(gpa);
    }
    return 0;
}
