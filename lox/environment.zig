const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Value = @import("main.zig").Value;
const Token = @import("main.zig").Token;
const LoxError = @import("main.zig").LoxError;

pub const Environment = struct {
    const Self = @This();
    allocator: *Allocator,
    values: StringHashMap(Value),

    pub fn init(allocator: *Allocator) Self {
        return .{ .values = StringHashMap(Value).init(allocator), .allocator = allocator };
    }
    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn define(self: *Self, name: []const u8, value: Value) !void {
        try self.values.put(name, value);
    }

    pub fn get(self: *Self, name: Token) !?Value {
        if (self.values.contains(name.lexeme)) {
            return self.values.get(name.lexeme);
        }

        // TODO
        // self.runtimeError(name, "Undefined variable.");
        return LoxError.runtime_error;
    }

    pub fn assign(self: *Self, name: Token, value: Value) !void {
        if (self.values.contains(name.lexeme)) {
            try self.values.put(name.lexeme, value);
            return;
        }

        // TODO
        // self.runtimeError(name, "Undefined variable.");
        return LoxError.runtime_error;
    }
};
