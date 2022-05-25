const std = @import("std");
const ulid = @import("ulid.zig");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

// For now, rely on HashMap for memtable.
// Tradeoff means that entries need to be sorted before flushing to disk.
const Memtable = std.AutoHashMap(ulid.Ulid, u128);

fn binarySearchBefore(items: []ulid.Ulid, key: ulid.Ulid) ?ulid.Ulid {
    if (items.len <= 0) {
        return null;
    }
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        const mid = left + (right - left + 1) / 2;
        switch (ulid.order(key, items[mid])) {
            .eq => return items[mid],
            .gt => left = mid,
            .lt => right = mid - 1,
        }
    }

    return items[left];
}

test "binarySearchBefore" {
    var monotonicFactory = ulid.DefaultMonotonicFactory.init();
    var items: [10]ulid.Ulid = [_]ulid.Ulid{
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
        try monotonicFactory.next(),
    };

    const found = binarySearchBefore(items[0..], items[4]);
    try std.testing.expect(items[4].equals(found.?));

    const noMore = items[items.len - 1];
    for (items[5..]) |*item| {
        item.* = try monotonicFactory.next();
    }
    const before = binarySearchBefore(items[0..], noMore);
    try std.testing.expect(items[4].equals(before.?));

    const max = binarySearchBefore(items[0..], items[items.len - 1]);
    try std.testing.expect(items[items.len - 1].equals(max.?));
}

// Fixed-length entry for simplicity.
const Entry = packed struct {
    key: ulid.Ulid,
    value: u128,
};

fn entryOrder(a: Entry, b: Entry) math.Order {
    return ulid.order(a.key, b.key);
}

fn entryAsc(context: void, a: Entry, b: Entry) bool {
    _ = context;
    return entryOrder(a, b) == math.Order.lt;
}

fn entryDesc(context: void, a: Entry, b: Entry) bool {
    _ = context;
    return entryOrder(a, b) == math.Order.gt;
}

fn ulidAsc(context: void, a: ulid.Ulid, b: ulid.Ulid) bool {
    _ = context;
    return ulid.order(a, b) == math.Order.lt;
}

const LsmtOptions = struct {
    maxSize: u32 = 8,
};

const Lsmt = struct {
    const Self = @This();

    dir: fs.Dir,
    allocator: mem.Allocator,
    entries: Memtable,
    maxSize: u32,
    files: ArrayList(ulid.Ulid),

    pub fn init(dir: fs.Dir, allocator: mem.Allocator, options: LsmtOptions) !Self {
        var self = Self{
            .dir = dir,
            .allocator = allocator,
            .entries = Memtable.init(allocator),
            .maxSize = options.maxSize,
            .files = ArrayList(ulid.Ulid).init(allocator),
        };
        try self.reconstitute();
        return self;
    }

    fn reconstitute(self: *Self) !void {
        const dir = try self.dir.openDir(".", .{ .iterate = true });
        var it = dir.iterate();
        while (try it.next()) |entry| {
            const id = try ulid.Ulid.parseBase32(entry.name);
            try self.files.append(id);
        }
        std.sort.sort(ulid.Ulid, self.files.items[0..], {}, ulidAsc);
        std.debug.print("Reconstituted files count={d}\n", .{self.files.items.len});
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
        self.files.deinit();
    }

    pub fn put(self: *Self, key: ulid.Ulid, value: u128) !void {
        try self.entries.put(key, value);

        if (self.entries.count() >= self.maxSize) {
            try self.flushEntries();
        }
    }

    // First check Memtable.
    // Then check files on disk.
    pub fn get(self: *Self, key: ulid.Ulid) !?u128 {
        if (self.entries.get(key)) |value| {
            return value;
        } else if (binarySearchBefore(self.files.items[0..], key)) |found| {
            var filename: [26]u8 = undefined;
            found.fillBase32(filename[0..]);
            const file = try self.dir.openFile(filename[0..], .{});
            return try self.getFrom(file, key);
        } else return null;
    }

    pub fn flushEntries(self: *Self) !void {
        const count = self.entries.count();
        if (count <= 0) return;

        var items = try self.allocator.alloc(Entry, count);
        var index: u32 = 0;
        while (self.entries.keyIterator().next()) |key| {
            if (self.entries.fetchRemove(key.*)) |entry| {
                items[index] = Entry{ .key = entry.key, .value = entry.value };
                index += 1;
            }
        }

        std.sort.sort(Entry, items[0..], {}, entryAsc);

        var filename: [26]u8 = undefined;
        items[0].key.fillBase32(filename[0..]);
        const file = try self.dir.createFile(filename[0..], .{ .truncate = true, .read = true });

        for (items) |item| {
            const buf = @bitCast([@sizeOf(Entry)]u8, item);
            const written = try file.writer().write(buf[0..]);
            assert(written == buf.len);
        }

        try self.files.append(items[0].key);
    }

    pub fn getFrom(self: *Self, file: fs.File, key: ulid.Ulid) !?u128 {
        _ = self;
        var buf: [@sizeOf(Entry)]u8 = undefined;
        while ((try file.readAll(buf[0..])) > 0) {
            const entry = @bitCast(Entry, buf);
            if (key.equals(entry.key)) {
                return entry.value;
            }
        }
        return null;
    }
};

test "init" {
    const dir = try ensureDir("tmp.db");
    var ulidFactory = ulid.DefaultMonotonicFactory.init();
    var lsmt = try Lsmt.init(dir, std.testing.allocator, .{ .maxSize = 20 });
    defer lsmt.deinit();

    var ids = try std.testing.allocator.alloc(ulid.Ulid, 10);
    defer std.testing.allocator.free(ids);
    for (ids) |*id| {
        id.* = try ulidFactory.next();
    }

    for (ids) |id| {
        try lsmt.put(id, @intCast(u128, id.timestamp() * 2));
    }
    for (ids) |id| {
        try lsmt.put(id, @intCast(u128, id.timestamp()));
    }

    for (ids) |id| {
        const val = try lsmt.get(id);
        try std.testing.expectEqual(@as(u128, id.timestamp()), val.?);
    }
}

fn ensureDir(name: []const u8) !fs.Dir {
    return fs.cwd().openDir(name, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            try fs.cwd().makeDir(name);
            return try fs.cwd().openDir(name, .{ .iterate = true });
        } else {
            return err;
        }
    };
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const dir = try ensureDir("main.db");
    var lsmt = try Lsmt.init(dir, allocator, .{});
    defer lsmt.deinit();

    var ulidFactory = ulid.DefaultMonotonicFactory.init();

    var ids = try std.testing.allocator.alloc(ulid.Ulid, 8 * 1000);
    defer std.testing.allocator.free(ids);
    for (ids) |*id| {
        id.* = try ulidFactory.next();
    }

    for (ids) |id| {
        try lsmt.put(id, @intCast(u128, id.timestamp()));
    }

    if (false) {
        var it = lsmt.entries.iterator();
        while (it.next()) |entry| {
            std.debug.print("key={?} value={d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    if (true) {
        const value = lsmt.get(ids[0]);
        std.debug.print("expect value from flushed file: key={?} {any}\n", .{ ids[0], value });
    }

    if (false) {
        for (lsmt.files.items) |file| {
            std.debug.print("file={?}\n", .{file});
        }
    }

    if (true) {
        const id = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XE");
        const value = try lsmt.get(id);
        std.debug.print("found value from previous file: key={?} {any}\n", .{ id, value });
    }
}
