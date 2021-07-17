const std = @import("std");
const mem = std.mem;
const split = mem.split;
const trim = mem.trim;
const ArrayList = std.ArrayList;
const stdout = std.io.getStdOut().writer();

// Usage:
// Define the import filepaths (main.zig/expr.zig), then run:
// > zig run generate_ast.zig
// |- expr.zig
// |- stmt.zig

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;

    var exprs = ArrayList([]const u8).init(gpa);
    defer exprs.deinit();
    try exprs.append("BinaryExpr   | left: *Expr, operator: Token, right: *Expr");
    try exprs.append("GroupingExpr | expression: *Expr");
    try exprs.append("LiteralExpr  | value: Value");
    try exprs.append("UnaryExpr    | operator: Token, right: *Expr");

    var stmts = ArrayList([]const u8).init(gpa);
    defer stmts.deinit();
    try stmts.append("ExpressionStmt | expression: *Expr");
    try stmts.append("PrintStmt      | expression: *Expr");

    const exprFile = try std.fs.cwd().createFile("expr.zig", .{});
    defer exprFile.close();
    const stmtFile = try std.fs.cwd().createFile("stmt.zig", .{});
    defer stmtFile.close();

    try defineExpr(exprFile.writer(), "main.zig", "Expr", "expr", exprs, "?Value");
    try stdout.print("Generated expr.zig\n", .{});
    try defineStmt(stmtFile.writer(), "expr.zig", "Stmt", "stmt", stmts, "anyerror!void");
    try stdout.print("Generated stmt.zig\n", .{});
}

fn defineStmt(out: anytype, importName: []const u8, baseName: []const u8, littleBaseName: []const u8, types: ArrayList([]const u8), returnType: []const u8) !void {
    const header =
        \\// **This file was generated by generate_ast.zig**
        \\
        \\const std = @import("std");
        \\const Allocator = std.mem.Allocator;
        \\const ArrayList = std.ArrayList;
        \\const Expr = @import("{s}").Expr;
        \\
        \\
    ;
    try out.print(header, .{importName});

    try defineBase(out, baseName, returnType);
    try defineVisitor(out, littleBaseName, types, returnType);

    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");
        const fields = trim(u8, p.next().?, " ");
        try defineType(out, baseName, littleBaseName, className, fields, returnType);
    }
}

fn defineExpr(out: anytype, importName: []const u8, baseName: []const u8, littleBaseName: []const u8, types: ArrayList([]const u8), returnType: []const u8) !void {
    const header =
        \\// **This file was generated by generate_ast.zig**
        \\
        \\const std = @import("std");
        \\const Allocator = std.mem.Allocator;
        \\const ArrayList = std.ArrayList;
        \\const Token = @import("{s}").Token;
        \\const Value = @import("{s}").Value;
        \\
        \\
    ;
    try out.print(header, .{ importName, importName });

    try defineBase(out, baseName, returnType);
    try defineVisitor(out, littleBaseName, types, returnType);

    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");
        const fields = trim(u8, p.next().?, " ");
        try defineType(out, baseName, littleBaseName, className, fields, returnType);
    }
}

fn defineBase(out: anytype, baseName: []const u8, returnType: []const u8) !void {
    const source =
        \\pub const {s} = struct {c}
        \\    const Self = @This();
        \\    acceptFn: fn (self: *const Self, visitor: *Visitor) {s},
        \\    pub fn accept(self: *const Self, visitor: *Visitor) {s} {c}
        \\        return self.acceptFn(self, visitor);
        \\    {c}
        \\{c};
        \\
        \\
    ;
    try out.print(source, .{ baseName, '{', returnType, returnType, '{', '}', '}' });
}

fn defineType(out: anytype, baseName: []const u8, littleBaseName: []const u8, className: []const u8, fields: []const u8, returnType: []const u8) !void {
    try out.print("pub const {s} = struct {c}\n", .{ className, '{' });
    try out.print("    const Self = @This();\n", .{});
    try out.print("    {s}: {s} = {s}{c} .acceptFn = accept {c},\n\n", .{ littleBaseName, baseName, baseName, '{', '}' });

    // fields
    var f1 = split(fields, ", ");
    while (f1.next()) |field| {
        try out.print("    {s},\n", .{field});
    }

    // initializer
    try out.print("\n", .{});
    try out.print("    pub fn init(allocator: *Allocator, ", .{});
    var f2 = split(fields, ", ");
    if (f2.next()) |field| {
        try out.print("{s}", .{field});
    }
    while (f2.next()) |field| {
        try out.print(", {s}", .{field});
    }
    try out.print(") !*Self {c}\n", .{'{'});

    // initializer struct
    try prints(out, ([_][]const u8{
        "        const self = try allocator.create(Self);\n",
        "        self.* = .{",
    })[0..]);
    var f3 = split(fields, ", ");
    if (f3.next()) |field| {
        var p = split(field, ": ");
        const name = trim(u8, p.next().?, "\n");
        try out.print(" .{s} = {s}", .{ name, name });
    }
    while (f3.next()) |field| {
        var p = split(field, ": ");
        const name = trim(u8, p.next().?, "\n");
        try out.print(", .{s} = {s}", .{ name, name });
    }
    try prints(out, ([_][]const u8{
        " };\n",
        "        return self;\n",
        "    }\n",
    })[0..]);

    // accept fn
    const acceptFn =
        \\    pub fn accept({s}: *const {s}, visitor: *Visitor) {s} {c}
        \\        const self = @fieldParentPtr(Self, "{s}", {s});
        \\
    ;
    try out.print(acceptFn, .{ littleBaseName, baseName, returnType, '{', littleBaseName, littleBaseName });
    try out.print("        return visitor.visit{s}(self.*);\n", .{className});

    try prints(out, ([_][]const u8{
        "    }\n",
        "};\n",
        "\n",
    })[0..]);
}

// Example implementor
// pub const ResolveVisitor = struct {
//     const Self = @This();
//     visitor: Visitor = Visitor{
//         .visitLiteralExprFn = visitLiteralExpr,
//         .visitGroupingExprFn = visitGroupingExpr,
//     },
//     pub fn visitLiteralExpr(visitor: *Visitor, expr: LiteralExpr) ?Value {
//         return expr.value;
//     }
//     pub fn visitGroupingExpr(visitor: *Visitor, expr: GroupingExpr) ?Value {
//         const self = @fieldParentPtr(Self, "visitor", visitor);
//         return expr.expression.accept(visitor);
//     }
// };
fn defineVisitor(out: anytype, littleBaseName: []const u8, types: ArrayList([]const u8), returnType: []const u8) !void {
    try prints(out, ([_][]const u8{
        "pub const Visitor = struct {\n",
        "    const Self = @This();\n",
    })[0..]);

    // abstract methods
    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");

        try out.print("    visit{s}Fn: fn (self: *Self, {s}: {s}) {s},\n", .{ className, littleBaseName, className, returnType });
    }
    try out.print("\n", .{});

    // concrete methods
    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");

        try out.print("    pub fn visit{s}(self: *Self, {s}: {s}) {s} {c}\n", .{ className, littleBaseName, className, returnType, '{' });
        try out.print("        return self.visit{s}Fn(self, {s});\n", .{ className, littleBaseName });
        try prints(out, ([_][]const u8{
            "    }\n",
        })[0..]);
    }

    try prints(out, ([_][]const u8{
        "};\n\n",
    })[0..]);
}

// bracket escaping printing utility
fn prints(out: anytype, pieces: []const []const u8) !void {
    for (pieces) |piece| {
        try out.print("{s}", .{piece});
    }
}
