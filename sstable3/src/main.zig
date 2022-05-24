const std = @import("std");
const rb = @import("rb.zig");
const ulid = @import("ulid.zig");
const assert = std.debug.assert;
const fs = std.fs;
const Crc32 = std.hash.Crc32;

const Entry = struct {
    key: ulid.Ulid,
    value: u128,
};

const EntryNode = struct {
    const Self = @This();

    node: rb.Node,
    entry: Entry,

    pub fn from(node: *rb.Node) *Self {
        return @fieldParentPtr(Self, "node", node);
    }

    pub fn order(l: *rb.Node, r: *rb.Node) std.math.Order {
        const left = EntryNode.from(l);
        const right = EntryNode.from(r);
        return ulid.order(left.entry.key, right.entry.key);
    }
};

// opt0
// | keylen (usize) | valuelen (usize) | key (ulid;16) | value (u128;16)
// | keylen (usize) | valuelen (usize) | key (ulid;16) | value (u128;16)

// opt1
// | crc32 | keylen | valuelen | key | value
// | crc32 | keylen | valuelen | key | value

// opt2
// keysize | keycount | index | index | index | index
// key | value | key | value

// opt1
// xxxx xxxx 0000 0000 0000 0000 0000 0000 <- crc32 (4 bytes); pad the rest 12 bytes with 0s
// 1000 0000 0000 0000 1000 0000 0000 0000 <- chunk 1; key size 16, value size 16
// 0180 f364 e750 fca1 fedc a57f 4c1a 37c6 <- key: 01G3SP9STGZJGZXQ55FX61MDY6
// 0000 0000 0000 0000 0000 0000 0000 0000 <- value: 0
// xxxx xxxx 0000 0000 0000 0000 0000 0000 <- crc32 pad the rest with 0s
// 1000 0000 0000 0000 1000 0000 0000 0000 <- chunk 2; key size 16, value size 16
// 0180 f364 e750 fca1 fedc a57f 4c1a 37c7 <- key: 01G3SP9STGZJGZXQ55FX61MDY7
// 0100 0000 0000 0000 0000 0000 0000 0000 <- value: 1
pub fn flush(file: fs.File, tree: *rb.Tree) !void {
    _ = file;

    var it = tree.iterator();
    while (it.next()) |node| {
        var entry = EntryNode.from(node).entry;

        const keysize: usize = @sizeOf([16]u8);
        const valuesize: usize = @sizeOf(u128);
        const chunksize = @sizeOf(usize) + @sizeOf(usize) + keysize + valuesize + @sizeOf(u32) + 12;
        var buf: [chunksize]u8 = undefined;
        std.debug.print("id={?} chunksize={d}\n", .{ entry.key, chunksize });

        var crc32 = Crc32.init();

        // keylen
        const keysizebuf = @bitCast([@sizeOf(usize)]u8, keysize);
        const start0 = @sizeOf(u32) + 12;
        crc32.update(keysizebuf[0..]);

        // valuelen
        const valuesizebuf = @bitCast([@sizeOf(usize)]u8, valuesize);
        const start1 = start0 + @sizeOf(usize);
        crc32.update(valuesizebuf[0..]);

        // key
        var keybuf: [16]u8 = undefined;
        const start2 = start1 + @sizeOf(usize);
        entry.key.fillBytes(keybuf[0..]);
        crc32.update(keybuf[0..]);

        // value
        const valuebuf = @bitCast([@sizeOf(u128)]u8, entry.value);
        const start3 = start2 + 16;
        crc32.update(valuebuf[0..]);

        const crc = crc32.final();
        std.debug.print("crc={d}\n", .{crc});

        const crcbuf = @bitCast([@sizeOf(u32)]u8, crc);
        std.mem.copy(u8, buf[0..@sizeOf(u32)], crcbuf[0..]);
        const zeroes: [12]u8 = [12]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        std.mem.copy(u8, buf[@sizeOf(u32)..start0], zeroes[0..]);
        std.mem.copy(u8, buf[start0 .. start0 + @sizeOf(usize)], keysizebuf[0..]);
        std.mem.copy(u8, buf[start1 .. start1 + @sizeOf(usize)], valuesizebuf[0..]);
        entry.key.fillBytes(buf[start2 .. start2 + 16]);
        std.mem.copy(u8, buf[start3 .. start3 + valuebuf.len], valuebuf[0..]);

        _ = try file.writer().write(&buf);
    }
}

pub fn read(file: fs.File, tree: *rb.Tree, nodes: []EntryNode) !usize {
    _ = tree;
    _ = nodes;

    // std.debug.print("usizelen={d}\n", .{ @sizeOf(usize) });

    var count: usize = 0;
    var offset: usize = 0;
    while (true) {
        try file.seekTo(offset);

        var crcbuf: [@sizeOf(u32)]u8 = undefined;
        var keysizebuf: [@sizeOf(usize)]u8 = undefined;
        var valuesizebuf: [@sizeOf(usize)]u8 = undefined;
        const crclen = try file.reader().readAll(crcbuf[0..]);
        if (crclen <= 0) {
            return count;
        }
        offset += crclen;
        try file.seekBy(12); // skip past padding
        offset += 12;
        const len0 = try file.reader().readAll(keysizebuf[0..]);
        if (len0 <= 0) {
            return count;
        }
        offset += len0;
        const len1 = try file.reader().readAll(valuesizebuf[0..]);
        if (len1 <= 0) {
            return count;
        }
        offset += len1;

        // Since we are using ULID keys, we can assume the key length!
        // If we are not using ULID keys, we may need to provide a way
        // for caller to specify key data types? (e.g. variable-length strings)
        var keybuf: [16]u8 = undefined;
        const len2 = try file.reader().readAll(keybuf[0..]);
        assert(len2 == keybuf.len);
        offset += len2;
        const key = ulid.Ulid.fromBytes(keybuf);

        // const valuesize = @bitCast(usize, valuesizebuf);
        var valuebuf: [@sizeOf(u128)]u8 = undefined;
        const len3 = try file.reader().readAll(valuebuf[0..]);
        assert(len3 == valuebuf.len);
        offset += len3;
        const value = @bitCast(u128, valuebuf);

        const read_crc = @bitCast(u32, crcbuf);
        var crc32 = Crc32.init();
        crc32.update(keysizebuf[0..]);
        crc32.update(valuesizebuf[0..]);
        crc32.update(keybuf[0..]);
        crc32.update(valuebuf[0..]);
        const calculated_crc = crc32.final();
        assert(read_crc == calculated_crc);
        count += 1;

        std.debug.print("read {?} {d} valuelen={d} crc={d}\n", .{ key, value, len3, read_crc });
    }
}

pub fn main() anyerror!void {
    var tree: rb.Tree = undefined;
    tree.init(EntryNode.order);
    var nodes: [10]EntryNode = undefined;
    var monotonicFactory = ulid.DefaultMonotonicFactory.init();

    nodes[0].entry = Entry{ .key = try monotonicFactory.next(), .value = 0 };
    nodes[1].entry = Entry{ .key = try monotonicFactory.next(), .value = 1 };
    nodes[2].entry = Entry{ .key = try monotonicFactory.next(), .value = 2 };
    nodes[3].entry = Entry{ .key = try monotonicFactory.next(), .value = 3 };
    nodes[4].entry = Entry{ .key = try monotonicFactory.next(), .value = 4 };
    nodes[5].entry = Entry{ .key = try monotonicFactory.next(), .value = 5 };
    nodes[6].entry = Entry{ .key = try monotonicFactory.next(), .value = 6 };
    nodes[7].entry = Entry{ .key = try monotonicFactory.next(), .value = 7 };
    nodes[8].entry = Entry{ .key = try monotonicFactory.next(), .value = 8 };
    nodes[9].entry = Entry{ .key = try monotonicFactory.next(), .value = 9 };

    _ = tree.insert(&nodes[2].node);
    _ = tree.insert(&nodes[4].node);
    _ = tree.insert(&nodes[0].node);
    _ = tree.insert(&nodes[1].node);
    _ = tree.insert(&nodes[5].node);
    _ = tree.insert(&nodes[6].node);
    _ = tree.insert(&nodes[7].node);
    _ = tree.insert(&nodes[8].node);
    _ = tree.insert(&nodes[9].node);
    _ = tree.insert(&nodes[3].node);

    // debug
    if (false) {
        var it = tree.iterator();
        while (it.next()) |node| {
            var entry = EntryNode.from(node).entry;
            std.debug.print("{?} -> {d}\n", .{ entry.key, entry.value });
        }
    }

    const file = try std.fs.cwd().createFile("test.sst", .{
        .truncate = true,
        .read = true,
    });

    if (true) try flush(file, &tree);

    if (true) {
        try file.seekTo(0);

        var readtree: rb.Tree = undefined;
        readtree.init(EntryNode.order);
        var nodes0: [10]EntryNode = undefined;
        const count = try read(file, &readtree, &nodes0);
        std.debug.print("read {d}\n", .{count});
    }
}
