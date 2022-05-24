const std = @import("std");
const rb = @import("rb.zig");
const ulid = @import("ulid2.zig");
const assert = std.debug.assert;
const fs = std.fs;
const Crc32 = std.hash.Crc32;

const Entry = packed struct {
    key: ulid.Ulid,
    value: u128,
};

const Chunk = packed struct {
    keysize: usize,
    valuesize: usize,
    entry: Entry,
};

const SignedChunk = packed struct {
    checksum: u32,
    reserved: [12]u8 = [12]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    chunk: Chunk,
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
    var it = tree.iterator();
    while (it.next()) |node| {
        const entry = EntryNode.from(node).entry;
        const chunk = Chunk{
            .keysize = @sizeOf(ulid.Ulid),
            .valuesize = @sizeOf(u128),
            .entry = entry,
        };
        const chunkbuf = @bitCast([@sizeOf(Chunk)]u8, chunk);
        const signed = SignedChunk{
            .checksum = Crc32.hash(chunkbuf[0..]),
            .chunk = chunk,
        };
        const signedbuf = @bitCast([@sizeOf(SignedChunk)]u8, signed);
        const write_len = try file.writer().write(signedbuf[0..]);
        assert(write_len == signedbuf.len);
    }
}

pub fn read(file: fs.File, tree: *rb.Tree, nodes: []EntryNode) !usize {
    _ = tree;
    _ = nodes;

    // std.debug.print("usizelen={d}\n", .{ @sizeOf(usize) });

    var count: usize = 0;
    while (true) {
        var buf: [@sizeOf(SignedChunk)]u8 = undefined;
        const len = try file.reader().readAll(buf[0..]);
        if (len <= 0) {
            return count;
        }

        const signed = @bitCast(SignedChunk, buf);
        const crc = Crc32.hash(buf[16..]);
        // FIXME: why does this checksum not match?
        // assert(signed.checksum == crc);
        count += 1;

        std.debug.print("read {?} {d} crc={d} calculated_crc={d}\n", .{ signed.chunk.entry.key, signed.chunk.entry.value, signed.checksum, crc });
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
