const std = @import("std");
const ulid = @import("ulid.zig");
const Entry = @import("common.zig").Entry;
const fs = std.fs;
const assert = std.debug.assert;

fn digit(lvl: u3) u8 {
    return @intCast(u8, lvl) + 48;
}

fn level(char: u8) u3 {
    return @intCast(u3, (char - 48) & 0b111);
}

pub fn ensureDir(name: []const u8) !fs.Dir {
    return fs.cwd().openDir(name, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            try fs.cwd().makeDir(name);
            return try fs.cwd().openDir(name, .{ .iterate = true });
        } else {
            return err;
        }
    };
}

pub const ParseError = error{
    InvalidFilename,
};

pub const WriteError = error{
    NoEntries,
};

pub const MergeError = error{
    MismatchedLevels,
};

const FilenameLen = 28;

pub const DiskFile = struct {
    const Self = @This();

    context: fs.Dir,
    id: ulid.Ulid,
    level: u3,
    filename: [FilenameLen]u8,

    // init (for read)
    // write (for initial create)
    // find
    // merge (a, b)

    pub fn parseFilename(context: fs.Dir, filename: []const u8) !DiskFile {
        if (filename.len != FilenameLen) {
            return error.InvalidFilename;
        }
        var df = .{
            .context = context,
            .id = try ulid.Ulid.parseBase32(filename[0..26]),
            .level = level(filename[27]),
            // TODO why doesn't this work?
            // .filename = [_]u8{ 0 } ** FilenameLen,
            .filename = [FilenameLen]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        };
        std.mem.copy(u8, df.filename[0..], filename);
        return df;
    }

    pub fn init(context: fs.Dir, id: ulid.Ulid, level_: u3) DiskFile {
        var df = DiskFile{
            .context = context,
            .id = id,
            .level = level_,
            .filename = [FilenameLen]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '_', digit(level_) },
        };
        id.fillBase32(df.filename[0..26]);
        return df;
    }

    pub fn write(context: fs.Dir, entries: []Entry) !DiskFile {
        if (entries.len < 1) {
            return error.NoEntries;
        }
        var df = DiskFile{
            .context = context,
            .id = entries[0].key,
            .level = 0,
            .filename = [FilenameLen]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '_', '0' },
        };
        entries[0].key.fillBase32(df.filename[0..26]);
        const file = try context.createFile(df.filename[0..], .{ .truncate = true });
        defer file.close();
        for (entries) |entry| {
            const buf = @bitCast([@sizeOf(Entry)]u8, entry);
            std.debug.print("writing {?} {any}\n", .{ entry.key, entry.value });
            const write_len = try file.writer().write(buf[0..]);
            assert(write_len == buf.len);
        }
        return df;
    }

    pub fn find(self: Self, key: ulid.Ulid) !?u128 {
        const file = try self.context.openFile(self.filename[0..], .{});
        defer file.close();
        var buf: [@sizeOf(Entry)]u8 = undefined;
        while ((try file.readAll(buf[0..])) > 0) {
            const entry = @bitCast(Entry, buf);
            std.debug.print("find {?} {d}\n", .{ entry.key, entry.value });
            if (key.equals(entry.key)) {
                return entry.value;
            }
        }
        return null;
    }

    pub const Iterator = struct {
        context: Self,
        file: fs.File,
        buf: [@sizeOf(Entry)]u8,
        closed: bool = false,

        pub fn init(context: Self) !Iterator {
            return Iterator{
                .context = context,
                .file = try context.context.openFile(context.filename[0..], .{}),
                .buf = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
                .closed = false,
            };
        }

        pub fn next(self: *Iterator) !?Entry {
            if (self.closed) {
                return null;
            }

            const read_len = try self.file.readAll(self.buf[0..]);
            if (read_len == @sizeOf(Entry)) {
                return @bitCast(Entry, self.buf);
            } else {
                self.closed = true;
                self.file.close();
                return null;
            }
        }
    };

    pub fn iterator(self: Self) !Iterator {
        return Iterator{
            .context = self,
            .file = try self.context.openFile(self.filename[0..], .{}),
            .buf = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .closed = false,
        };
    }

    pub fn merge(self: Self, b: DiskFile) !DiskFile {
        if (self.level != b.level) {
            return error.MismatchedLevels;
        }
        var df = DiskFile{
            .context = self.context,
            .id = self.id,
            .level = self.level + 1,
            .filename = [FilenameLen]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '_', digit(self.level + 1) },
        };
        if (ulid.order(self.id, b.id) == .lt) {
            df.id = self.id;
        } else {
            df.id = b.id;
        }
        df.id.fillBase32(df.filename[0..26]);

        var count: usize = 0;
        var ita = try self.iterator();
        var itb = try b.iterator();

        var file = try self.context.createFile(df.filename[0..], .{ .truncate = true });
        defer file.close();

        var nexta = try ita.next();
        var nextb = try itb.next();
        while (nexta != null and nextb != null) {
            switch (ulid.order(nexta.?.key, nextb.?.key)) {
                .lt => {
                    const bytes = @bitCast([@sizeOf(Entry)]u8, nexta.?);
                    const write_len = try file.writer().write(bytes[0..]);
                    count += 1;
                    assert(write_len == bytes.len);
                    nexta = try ita.next();
                },
                .gt => {
                    const bytes = @bitCast([@sizeOf(Entry)]u8, nextb.?);
                    const write_len = try file.writer().write(bytes[0..]);
                    count += 1;
                    assert(write_len == bytes.len);
                    nextb = try itb.next();
                },
                .eq => {
                    // TODO handle duplicate keys.
                    const bytes = @bitCast([@sizeOf(Entry)]u8, nexta.?);
                    const write_len = try file.writer().write(bytes[0..]);
                    count += 1;
                    assert(write_len == bytes.len);
                    nexta = try ita.next();
                },
            }
        }

        if (nexta) |nexta_| {
            const bytes = @bitCast([@sizeOf(Entry)]u8, nexta_);
            const write_len = try file.writer().write(bytes[0..]);
            count += 1;
            assert(write_len == bytes.len);
            while (try ita.next()) |entry| {
                const bytes_ = @bitCast([@sizeOf(Entry)]u8, entry);
                const write_len_ = try file.writer().write(bytes_[0..]);
                count += 1;
                assert(write_len_ == bytes_.len);
            }
        }

        if (nextb) |nextb_| {
            const bytes = @bitCast([@sizeOf(Entry)]u8, nextb_);
            const write_len = try file.writer().write(bytes[0..]);
            count += 1;
            assert(write_len == bytes.len);
            while (try itb.next()) |entry| {
                const bytes_ = @bitCast([@sizeOf(Entry)]u8, entry);
                const write_len_ = try file.writer().write(bytes_[0..]);
                count += 1;
                assert(write_len_ == bytes_.len);
            }
        }

        std.debug.print("merged filename={s} count={d}\n", .{ df.filename, count });
        return df;
    }

    pub fn deleteFile(self: Self) !void {
        self.context.deleteFile(self.filename[0..]) catch |err| {
            if (err == error.FileNotFound) {
                std.log.warn("tried to delete non-existent file", .{});
            } else {
                return err;
            }
        };
    }
};

test "parseFilename" {
    const filename = "01G3WB8CZJNHD67Q7N2APFN4XE_0";
    const id = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XE");
    const df = try DiskFile.parseFilename(try ensureDir("tmp.db"), filename);
    try std.testing.expect(std.mem.eql(u8, filename, df.filename[0..]));

    try std.testing.expect(std.mem.eql(u8, id.bytes[0..], df.id.bytes[0..]));
    try std.testing.expectEqual(@as(u3, 0), df.level);
}

test "init" {
    const filename = "01G3WB8CZJNHD67Q7N2APFN4XE_0";
    const id = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XE");
    var df = DiskFile.init(try ensureDir("tmp.db"), id, 0);
    try std.testing.expect(std.mem.eql(u8, filename, df.filename[0..]));

    try std.testing.expect(std.mem.eql(u8, id.bytes[0..], df.id.bytes[0..]));
    try std.testing.expectEqual(@as(u3, 0), df.level);
}

test "write/find" {
    var entries = [_]Entry{
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XE"), .value = 128 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XF"), .value = 256 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XG"), .value = 512 },
    };
    const df = try DiskFile.write(try ensureDir("tmp.db"), entries[0..]);
    const value0 = try df.find(entries[0].key);
    try std.testing.expectEqual(entries[0].value, value0.?);
    const value1 = try df.find(entries[1].key);
    try std.testing.expectEqual(entries[1].value, value1.?);
    try df.deleteFile();
}

test "merge" {
    var entries0 = [_]Entry{
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XH"), .value = 128 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XJ"), .value = 256 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XK"), .value = 512 },
    };
    var entries1 = [_]Entry{
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XM"), .value = 1024 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XN"), .value = 2048 },
        .{ .key = try ulid.Ulid.parseBase32("01G3WB8CZJNHD67Q7N2APFN4XP"), .value = 4096 },
    };

    const df0 = try DiskFile.write(try ensureDir("tmp.db"), entries0[0..]);
    const df1 = try DiskFile.write(try ensureDir("tmp.db"), entries1[0..]);
    const df2 = try df0.merge(df1);
    try std.testing.expect(df2.id.equals(df0.id));

    const value01 = try df2.find(entries0[1].key);
    const value11 = try df2.find(entries1[1].key);
    try std.testing.expectEqual(entries0[1].value, value01.?);
    try std.testing.expectEqual(entries1[1].value, value11.?);

    try df0.deleteFile();
    try df1.deleteFile();
    try df2.deleteFile();
}
