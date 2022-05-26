const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;

const common = @import("common.zig");
const diskfile = @import("diskfile.zig");
const ulid = @import("ulid.zig");
const Entry = common.Entry;
const Tree = @import("tree.zig").Tree;
const ensureDir = diskfile.ensureDir;
const DiskFile = diskfile.DiskFile;

const Memtable = Tree(Entry, common.entryOrder);

const LsmtOptions = struct {
    maxSize: u32 = 8,
};

const Lsmt = struct {
    const Self = @This();

    allocator: mem.Allocator,
    memtable: Memtable,
    maxSize: u32,
    dir: fs.Dir,
    files: ArrayList(DiskFile),

    pub fn init(dirname: []const u8, allocator: mem.Allocator, options: LsmtOptions) !Self {
        var self = Self{
            .dir = try ensureDir(dirname),
            .allocator = allocator,
            .memtable = Memtable.init(allocator),
            .maxSize = options.maxSize,
            .files = ArrayList(DiskFile).init(allocator),
        };
        try self.reconstitute();
        return self;
    }

    fn reconstitute(self: *Self) !void {
        const dir = try self.dir.openDir(".", .{ .iterate = true });
        var it = dir.iterate();
        while (try it.next()) |entry| {
            const df = try DiskFile.parseFilename(self.dir, entry.name);
            try self.files.append(df);
        }
        std.sort.sort(DiskFile, self.files.items[0..], {}, Lsmt.diskfileAsc);
        std.debug.print("Reconstituted files count={d}\n", .{self.files.items.len});
    }

    fn diskfileAsc(context: void, a: DiskFile, b: DiskFile) bool {
        return common.ulidAsc(context, a.id, b.id);
    }

    pub fn deinit(self: *Self) void {
        self.memtable.deinit();
        self.files.deinit();
    }

    pub fn put(self: *Self, key: ulid.Ulid, value: u128) !void {
        try self.memtable.insert(Entry{ .key = key, .value = value });

        if (self.memtable.len >= self.maxSize) {
            try self.flushMemtable();
        }
    }

    pub fn flushMemtable(self: *Self) !void {
        if (self.memtable.len <= 0) return;
        var items = try self.allocator.alloc(Entry, self.memtable.len);
        try self.memtable.filler().fill(items[0..]);
        const df = try DiskFile.write(self.dir, items[0..]);
        _ = df;
        try self.files.append(df);
        self.memtable.removeAll();
        assert(self.memtable.len == 0);
    }

    // First check Memtable.
    // Then check files on disk.
    pub fn get(self: *Self, key: ulid.Ulid) !?u128 {
        if (self.memtable.get(Entry{ .key = key, .value = undefined })) |entry| {
            return entry.value;
        } else if (binarySearchLte(self.files.items[0..], key)) |found| {
            return try found.find(key);
        } else return null;
    }

    fn binarySearchLte(items: []DiskFile, key: ulid.Ulid) ?DiskFile {
        if (items.len <= 0) {
            return null;
        }
        // Is the key less than or equal to any available item??
        if (ulid.order(items[0].id, key) == .gt) {
            return null;
        }

        var left: usize = 0;
        var right: usize = items.len;

        while (left < right) {
            const mid = left + (right - left + 1) / 2;
            switch (ulid.order(key, items[mid].id)) {
                .eq => return items[mid],
                .gt => left = mid,
                .lt => right = mid - 1,
            }
        }

        return items[left];
    }
};

test "init" {
    var ulidFactory = ulid.DefaultMonotonicFactory.init();
    var lsmt = try Lsmt.init("tmp.db", std.testing.allocator, .{ .maxSize = 20 });
    defer lsmt.deinit();

    var ids = try std.testing.allocator.alloc(ulid.Ulid, 10);
    defer std.testing.allocator.free(ids);
    for (ids) |*id| {
        id.* = try ulidFactory.next();
    }

    // FIXME Need to allow replace operation in binary tree!
    if (false) {
        for (ids) |id| {
            try lsmt.put(id, @intCast(u128, id.timestamp() * 2));
        }
    }
    for (ids) |id| {
        try lsmt.put(id, @intCast(u128, id.timestamp()));
    }

    for (ids) |id| {
        const val = try lsmt.get(id);
        try std.testing.expectEqual(@as(u128, id.timestamp()), val.?);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var lsmt = try Lsmt.init("main.db", allocator, .{});
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

    if (true) {
        for (lsmt.files.items) |file| {
            std.debug.print("file={s}\n", .{file.filename});
        }
    }

    if (true) {
        const value = lsmt.get(ids[0]);
        std.debug.print("expect value from flushed file: key={?} {any}\n", .{ ids[0], value });
    }

    if (true) {
        const id = try ulid.Ulid.parseBase32("01G3ZDWC643WPZ4JNNWZ126B4Y");
        const value = try lsmt.get(id);
        std.debug.print("found value from previous file: key={?} {any}\n", .{ id, value });
    }
}
