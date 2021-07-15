const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;

const stdout = std.io.getStdOut().writer();

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
    IDENTIFIER: []u8, STRING: []u8, NUMBER: f64, LEFT_PAREN: void, RIGHT_PAREN: void, LEFT_BRACE: void, RIGHT_BRACE: void, COMMA: void, DOT: void, MINUS: void, PLUS: void, SEMICOLON: void, SLASH: void, STAR: void, BANG: void, BANG_EQUAL: void, EQUAL: void, EQUAL_EQUAL: void, GREATER: void, GREATER_EQUAL: void, LESS: void, LESS_EQUAL: void, AND: void, CLASS: void, ELSE: void, FALSE: void, FUN: void, FOR: void, IF: void, NIL: void, OR: void, PRINT: void, RETURN: void, SUPER: void, THIS: void, TRUE: void, VAR: void, WHILE: void, EOF: void
};

pub const Token = struct {
    token_type: TokenType,
    lexeme: []u8,
    literal: ?Literal,
    line: u32,

    pub fn init(token_type: TokenType, lexeme: []u8, literal: ?Literal, line: u32) Token {
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
fn report(line: u32, where: []const u8, comptime message: []const u8) void {
    std.debug.print("[line {d}] Error{s}: {s}\n", .{ line, where, message });
    hadError = true;
}

fn reportErr(line: u32, comptime message: []const u8) void {
    report(line, "", message);
}

fn run(allocator: *Allocator, source: []u8) !void {
    var list = ArrayList(Token).init(allocator);
    defer list.deinit();

    var scanner = Scanner.init(source, list);
    var tokens = try scanner.scanTokens();
    for (tokens.items) |token| {
        std.debug.print("{?}\n", .{token});
    }
}

fn runFile(allocator: *Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    defer file.close();

    const contents = try file.reader().readAllAlloc(allocator, 4096 * 16);
    try run(allocator, contents);

    if (hadError) {
        std.os.exit(65);
    }
}

fn promptStmt(buf: []u8) !?[]u8 {
    const readUntil = std.io.getStdIn().reader().readUntilDelimiterOrEof;
    try stdout.print("> ", .{});
    return try readUntil(buf, '\n');
}

fn runPrompt(allocator: *Allocator) !void {
    var buf: [4096]u8 = undefined;
    while (try promptStmt(&buf)) |line| {
        try run(allocator, line);
        hadError = false;
    }
}

pub fn main() !u8 {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // var vv = ValueVisitor(){};
    // var visitor = &sv.visitor;
    // var lit = Literal.init(.EOF);
    // std.debug.print("StringVisitor {s}", .{visitor.visitLiteralExpr(lit)});

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
