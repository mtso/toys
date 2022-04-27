const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ComptimeStringMap = std.ComptimeStringMap;
const Writer = std.io.Writer;

const stdout = std.io.getStdOut().writer();

pub const Token = struct {
    typ: TokenType,
    lexeme: []const u8,
    raw: Value,
    pub fn init(typ: TokenType, lexeme: []const u8, raw: Value) Token {
        return .{ .typ = typ, .lexeme = lexeme, .raw = raw };
    }
};

pub const TokenType = enum {
    PLUS,
    STR,
    NUM,
};

pub const Value = union(TokenType) {
    NUM: f64,
    STR: []const u8,
    PLUS,
};

pub const Scanner = struct {
    source: []const u8,
    tokens: ArrayList(Token),
    current: u32 = 0,
    start: u32 = 0,
    line: u32 = 1,
    error_line: ?u32 = null,
    error_message: ?[]const u8 = null,

    pub fn init(source: []const u8, tokens: ArrayList(Token)) Scanner {
        return .{ .tokens = tokens, .source = source };
    }
    pub fn scan(self: *Scanner) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }
    }
    fn scanToken(self: *Scanner) !void {
        const c = self.advance();

        _ = switch (c) {
            '+' => try self.addTokenValue(.PLUS, .PLUS),
            '\n' => self.line += 1,
            '0'...'9' => try self.number(),
            '"' => try self.string(),
            else => self.err(self.line, "Unexpected character."),
        };
    }
    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (isDigit(self.peek())) _ = self.advance();
        }

        const num = try std.fmt.parseFloat(f64, self.source[self.start..self.current]);
        try self.addTokenValue(.NUM, .{ .NUM = num });
    }
    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            self.err(self.line, "Unterminated string.");
            return;
        }

        _ = self.advance();

        var value = self.source[self.start + 1 .. self.current - 1];
                try stdout.print("valPtr={*}\n", .{&value});
        try self.addTokenValue(.STR, .{ .STR = &value });
    }
    fn peek(self: Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
    fn peekNext(self: Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }
    fn advance(self: *Scanner) u8 {
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    // fn addToken(self: *Scanner, typ: TokenType) !void {
    //     var text = self.source[self.start..self.current];
    //     try self.tokens.append(Token.init(typ, text, null));
    // }
    fn addTokenValue(self: *Scanner, typ: TokenType, value: Value) !void {
        try self.tokens.append(Token.init(typ, self.source[self.start..self.current], value));
    }
    fn isDigit(char: u8) bool {
        return char >= '0' and char <= '9';
    }
    fn isAtEnd(self: Scanner) bool {
        return self.current >= self.source.len;
    }
    fn err(self: *Scanner, line: u32, message: []const u8) void {
        self.error_line = line;
        self.error_message = message;
    }
};

pub const Expr = struct {
    const Self = @This();
    acceptFn: fn (self: Self) ?Value,
    pub fn accept(self: Self) ?Value {
        return self.acceptFn(self);
    }
};

// pub const UnaryExpr = struct {
//     const Self = @This();
//     expr: Expr = Expr{};

//     operator: Token,
//     right: *Expr
// };

pub const LiteralExpr = struct {
    const Self = @This();
    expr: Expr = Expr{
        .acceptFn = accept,
    },

    value: Value,
    // writer: Writer,
    fn accept(expr: Expr) ?Value {
        const self = @fieldParentPtr(Self, "expr", &expr);
        // self.writer.print("LiteralExpr={?}\n", value);
        std.debug.print("accept {?}\n", .{self.value});
        return self.value;
    }
};

// test "scanner" {
//     var tokens = ArrayList(Token).init(std.testing.allocator);
//     defer tokens.deinit();
//     const scanner = Scanner.init(source, tokens);

//     try scanner.scan();

//     const expr = Parser.init(tokens).parse();
//     Resolver.init().resolve(expr);
//     const interpreter = Interpreter.init(std.testing.allocator);
//     defer interpreter.deinit();
//     const result = interpreter.interprete(expr) catch |err| {
//     }
// }

pub fn toValue(token: Token) Value {
    return token.raw.?;
    // switch (token.typ) {
    //     .NUM => {
    //         std.debug.print("copying {e}\n", .{token.raw.?});
    //         return Value{.NUM = token.raw.?};
    //     },
    //     .STR => {
    //         return Value{.STR = token.raw.?};
    //     },
    //     .PLUS => return .PLUS,
    // }
}

pub const Parser = struct {
    const Self = @This();
    tokens: ArrayList(Token),
    exprs: *ArrayList(Expr),
    pub fn init(tokens: ArrayList(Token), exprs: *ArrayList(Expr)) Self {
        return .{ .tokens = tokens, .exprs = exprs };
    }
    pub fn copy(self: *Parser) !void {
        for (self.tokens.items) |token| {
            const lit = LiteralExpr{.value = token.raw};//  toValue(token)};
            std.debug.print("copy expr {?}\n", .{lit.expr.accept()});
            try self.exprs.append(lit.expr);
            // switch (token.typ) {
            //     .NUM => {
            //         std.debug.print("copying {e}\n", .{token.raw.?});
            //         try self.exprs.append(LiteralExpr{.value = token.raw.?});
            //     },
            //     .STR => {
            //         try self.exprs.append(LiteralExpr{.value = token.raw.?});
            //     },
            //     .PLUS => try self.exprs.append(LiteralExpr{.value = .PLUS}),
            // }
        }
        // for (self.exprs.items) |item| {
        //     std.debug.print("copying {?}\n", .{item});
        // }
    }
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const file = try std.fs.cwd().openFile(args[1], .{ .read = true });
    defer file.close();
    const contents = try file.reader().readAllAlloc(gpa, 4096 * 16);

    const tokens = ArrayList(Token).init(gpa);
    defer tokens.deinit();

    const scanner = &Scanner.init(contents, tokens);
    try scanner.scan();
    for (scanner.tokens.items) |t| {
        try stdout.print("{?}\n", .{t});
    }
    var exprs = ArrayList(Expr).init(gpa);
    defer exprs.deinit();

    const parser = &Parser.init(scanner.tokens, &exprs);
    try parser.copy();
    for (parser.exprs.items) |t| {
            // std.debug.print("{*}\n", .{t});
        try stdout.print("{?}\n", .{t});

        var val = t.accept();
        if (null == val) continue;
        switch (val.?) {
            .STR => |s| {
                try stdout.print("val={*}\n", .{s});
                try stdout.print("val={s}\n", .{s.*});
            },
            else => try stdout.print("val={?}\n", .{val}),
        }
    }
}
