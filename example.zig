const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const lapper = @import("src/lapper.zig");
const Iv = lapper.Interval(void); // alias for intervals with no used value field

/// Parse bed file into hash of intervals
fn read_bed(allocator: *Allocator, bed_file_path: []const u8) !StringHashMap(ArrayList(Iv)) {
    const abs_bed_path = try std.fs.path.resolve(allocator, &[_][]const u8{bed_file_path});
    defer allocator.free(abs_bed_path);
    const bed_fh = try std.fs.openFileAbsolute(abs_bed_path, .{});
    defer bed_fh.close();
    const stream = std.io.bufferedInStream(bed_fh.inStream()).inStream();
    var buffer: [512]u8 = undefined;
    var bed_raw = StringHashMap(ArrayList(Iv)).init(allocator);
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
    return bed_raw;
}

/// This is an example of calculating bedcov as described in the
/// https://github.com/lh3/biofast repo
pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        warn("Usage: becov-zig <loaded.bed> <streamed.bed>\n", .{});
        std.process.exit(1);
    }

    // Create a hash
    var bed_raw = try read_bed(allocator, args[1]);

    // convert to lappers

    // stream next file

    var total: usize = 0;
    var it = bed_raw.iterator();
    while (it.next()) |kv| {
        total += kv.value.items.len;
    }
    warn("{} lines\n", .{total});
    // TODO: leadking all the lists I think
    bed_raw.deinit();
}
