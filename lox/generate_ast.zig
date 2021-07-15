const std = @import("std");
const mem = std.mem;
const split = mem.split;
const trim = mem.trim;
const ArrayList = std.ArrayList;
const stdout = std.io.getStdOut().writer();

// Usage: zig run generate_ast.zig > expr.zig

fn defineAst(importName: []const u8, baseName: []const u8, types: ArrayList([]const u8)) !void {
    const header =
        \\// **This file was generated by generate_ast.zig**
        \\
        \\const std = @import("std");
        \\const Allocator = std.mem.Allocator;
        \\const ArrayList = std.ArrayList;
        \\const Token = @import("main.zig").Token;
        \\const Literal = @import("main.zig").Literal;
        \\
        \\
    ;
    try stdout.print("{s}", .{header});

    try defineExpr();
    try defineVisitor(types);

    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");
        const fields = trim(u8, p.next().?, " ");
        try defineType(className, fields);
    }
}

fn defineExpr() !void {
    const source =
        \\pub const Expr = struct {
        \\    const Self = @This();
        \\    acceptFn: fn (self: *const Self, visitor: *Visitor) ?Literal,
        \\    pub fn accept(self: *const Self, visitor: *Visitor) ?Literal {
        \\        return self.acceptFn(self, visitor);
        \\    }
        \\};
        \\
        \\
    ;
    try stdout.print("{s}", .{source});
}

fn defineType(className: []const u8, fields: []const u8) !void {
    try stdout.print("pub const {s} = struct {c}\n", .{ className, '{' });
    try prints(([_][]const u8{
        "    const Self = @This();\n",
        "    expr: Expr = Expr{ .acceptFn = accept },\n\n",
    })[0..]);

    // fields
    var f1 = split(fields, ", ");
    while (f1.next()) |field| {
        try stdout.print("    {s},\n", .{field});
    }

    // initializer
    try stdout.print("\n", .{});
    try stdout.print("    pub fn init(allocator: *Allocator, ", .{});
    var f2 = split(fields, ", ");
    if (f2.next()) |field| {
        try stdout.print("{s}", .{field});
    }
    while (f2.next()) |field| {
        try stdout.print(", {s}", .{field});
    }
    try stdout.print(") !*Self {c}\n", .{'{'});

    // initializer struct
    try prints(([_][]const u8{
        "        const self = try allocator.create(Self);\n",
        "        self.* = .{",
    })[0..]);
    var f3 = split(fields, ", ");
    if (f3.next()) |field| {
        var p = split(field, ": ");
        const name = trim(u8, p.next().?, "\n");
        try stdout.print(" .{s} = {s}", .{ name, name });
    }
    while (f3.next()) |field| {
        var p = split(field, ": ");
        const name = trim(u8, p.next().?, "\n");
        try stdout.print(", .{s} = {s}", .{ name, name });
    }
    try prints(([_][]const u8{
        " };\n",
        "        return self;\n",
        "    }\n",
    })[0..]);

    // accept fn
    try prints(([_][]const u8{
        "    pub fn accept(expr: *const Expr, visitor: *Visitor) ?Literal {\n",
        "        const self = @fieldParentPtr(Self, \"expr\", expr);\n",
    })[0..]);
    try stdout.print("        return visitor.visit{s}(self.*);\n", .{className});
    try prints(([_][]const u8{"    }\n"})[0..]);

    try prints(([_][]const u8{
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
fn defineVisitor(types: ArrayList([]const u8)) !void {
    try prints(([_][]const u8{
        "pub const Visitor = struct {\n",
        "    const Self = @This();\n",
    })[0..]);

    // abstract methods
    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");

        try stdout.print("    visit{s}Fn: fn (self: *Self, expr: {s}) ?Literal,\n", .{ className, className });
    }
    try stdout.print("\n", .{});

    // concrete methods
    for (types.items) |typ| {
        var p = split(typ, "|");
        const className = trim(u8, p.next().?, " ");

        try stdout.print("    pub fn visit{s}(self: *Self, expr: {s}) ?Literal {c}\n", .{ className, className, '{' });
        try stdout.print("        return self.visit{s}Fn(self, expr);\n", .{className});
        try prints(([_][]const u8{
            "    }\n",
        })[0..]);
    }

    try prints(([_][]const u8{
        "};\n\n",
    })[0..]);
}

// bracket escaping printing utility
fn prints(pieces: []const []const u8) !void {
    for (pieces) |piece| {
        try stdout.print("{s}", .{piece});
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = &general_purpose_allocator.allocator;

    var types = ArrayList([]const u8).init(gpa);
    try types.append("BinaryExpr   | left: *Expr, operator: Token, right: *Expr");
    try types.append("GroupingExpr | expression: *Expr");
    try types.append("LiteralExpr  | value: Literal");
    try types.append("UnaryExpr    | operator: Token, right: *Expr");

    try defineAst("main.zig", "Expr", types);
}
