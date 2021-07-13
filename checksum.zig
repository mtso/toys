const std = @import("std");

/// Generate 128bit checksum.
pub fn main() !void {
  var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  const allocator = &arena_allocator.allocator;

  var buf = std.ArrayList(u8).init(allocator);
  defer buf.deinit();

  // Insert random data.
  try buf.insert(0, 1);
  try buf.insert(1, 2);
  try buf.insert(2, 4);

  var target: [32]u8 = undefined;
  // std.crypto.hash.Blake3.hash(buf.toOwnedSlice()[0..], target[0..], .{});
  std.crypto.hash.Blake3.hash(buf.toOwnedSlice()[0..], target[0..], .{});

  const checksum_size = 16;
  const checksum = @bitCast(u128, target[0..checksum_size].*);

  std.debug.print("{}", .{ checksum });
}
