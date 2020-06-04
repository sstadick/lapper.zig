const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;
const allocator = std.heap.c_allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const lapper = @import("src/lapper.zig");

/// This is an example of calculating bedcov as described in the
/// https://github.com/lh3/biofast repo
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        warn("Usage: becov-zig <loaded.bed> <streamed.bed>\n", .{});
        std.process.exit(1);
    }
    const inputBed = try std.fs.path.resolve(allocator, &[_][]const u8{args[1]});
    const streamBed = try std.fs.path.resolve(allocator, &[_][]const u8{args[2]});

    // alias for intervals with no used value field
    const Iv = lapper.Interval(void);

    // Create a hash
    var bed_raw = StringHashMap(ArrayList(Iv)).init(allocator);

    // Read the bed file and build up the lists of interval
    const bed_fh = try std.fs.openFileAbsolute(inputBed, .{});
    defer bed_fh.close();
    const stream = std.io.bufferedInStream(bed_fh.inStream()).inStream();
    var buffer: [512]u8 = undefined;
    // TODO: Just take the first three fields instead of line based parsing?
    while (stream.readUntilDelimiterOrEof(&buffer, '\n') catch |err| switch (err) {
        error.StreamTooLong => blk: {
            // Skip to the delimiter in the strea, to fix parsing
            try stream.skipUntilDelimiterOrEof('\n');
            // Try to use the truncated line since we likely only need the first few fields
            // NB: for a readl bed file parser, this would not do.
            break :blk &buffer;
        },
        else => |e| return e,
    }) |line| {
        // TODO: Add real errors if these are missing
        var split_it = std.mem.split(line, "\t");
        const chr = split_it.next().?;
        const start = split_it.next().?;
        const stop = split_it.next().?;
        // parse the ints, clone the str, add to the hash, create an interval
        const iv = Iv.init(try std.fmt.parseInt(u32, start, 10), try std.fmt.parseInt(u32, stop, 10), {});
        var result = try bed_raw.getOrPut(try std.mem.dupe(allocator, u8, chr));
        if (!result.found_existing) {
            result.kv.value = ArrayList(Iv).init(allocator);
            try result.kv.value.append(iv);
        } else {
            try result.kv.value.append(iv);
        }
    }

    var total: usize =0;
    var it = bed_raw.iterator();
    while (it.next()) |kv| {
        total += kv.value.items.len;
    }
    warn("{} lines\n", .{total});
    bed_raw.deinit();
}
