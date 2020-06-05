const std = @import("std");
const assert = std.debug.assert;
const warn = std.debug.warn;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const lapper = @import("src/lapper.zig");
const Iv = lapper.Interval(void); // alias for intervals with no used value field

/// Parse bed file into hash of intervals
fn read_bed(allocator: *Allocator, bed_file_path: []const u8) !StringHashMap(*lapper.Lapper(void)) {
    const abs_bed_path = try std.fs.path.resolve(allocator, &[_][]const u8{bed_file_path});
    defer allocator.free(abs_bed_path);
    const bed_fh = try std.fs.openFileAbsolute(abs_bed_path, .{});
    defer bed_fh.close();
    const stream = std.io.bufferedInStream(bed_fh.inStream()).inStream();
    var buffer: [512]u8 = undefined;
    var bed_raw = StringHashMap(*ArrayList(Iv)).init(allocator);
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
        var iv = try allocator.create(Iv);
        iv.* = Iv.init(try std.fmt.parseInt(u32, start, 10), try std.fmt.parseInt(u32, stop, 10), {});
        var result = try bed_raw.getOrPut(chr);
        if (!result.found_existing) {
            result.kv.key = try std.mem.dupe(allocator, u8, chr); // Only allocate if the key didn't already exist
            var alist = try allocator.create(ArrayList(Iv));
            alist.* = ArrayList(Iv).init(allocator);
            result.kv.value = alist;
            try result.kv.value.append(iv.*);
        } else {
            try result.kv.value.append(iv.*);
        }
    }

    var bed = StringHashMap(*lapper.Lapper(void)).init(allocator);
    var it = bed_raw.iterator();
    while (it.next()) |kv| {
        var lp = try allocator.create(lapper.Lapper(void));
        lp.* = lapper.Lapper(void).init(allocator, kv.value.toOwnedSlice());
        const toss = try bed.put(kv.key, lp);
    }
    return bed;
}

/// This is an example of calculating bedcov as described in the
/// https://github.com/lh3/biofast repo
pub fn main() !void {
    const allocator = std.heap.c_allocator;
    // const allocator = std.testing.allocator;
    const stdout = std.io.getStdOut().outStream();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        warn("Usage: becov-zig <loaded.bed> <streamed.bed>\n", .{});
        std.process.exit(1);
    }

    // Create a hash
    var bed = try read_bed(allocator, args[1]);

    // stream next file
    const abs_bed_path = try std.fs.path.resolve(allocator, &[_][]const u8{args[2]});
    defer allocator.free(abs_bed_path);
    const bed_fh = try std.fs.openFileAbsolute(abs_bed_path, .{});
    defer bed_fh.close();
    const stream = std.io.bufferedInStream(bed_fh.inStream()).inStream();
    var buffer: [512]u8 = undefined;
    warn("Start Timer\n", .{});
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

        // find falues in `bed` hash
        if (bed.getValue(chr)) |chr_lapper| {
            const start = try std.fmt.parseInt(u32, split_it.next().?, 10);
            const stop = try std.fmt.parseInt(u32, split_it.next().?, 10);
            var coverage_start: u32 = 0;
            var coverage_stop: u32 = 0;
            var coverage: u32 = 0;
            var n: usize = 0;
            var it = chr_lapper.find(start, stop);
            while (it.next()) |iv| : (n += 1) {
                var start_iv = if (iv.start > coverage_start) iv.start else coverage_start;
                var stop_iv = if (iv.stop < coverage_stop) iv.stop else coverage_stop;
                if (start_iv > coverage_stop) {
                    coverage += coverage_stop - coverage_start;
                    coverage_start = start_iv;
                    coverage_stop = stop_iv;
                } else {
                    coverage_stop = if (coverage_stop < stop_iv) stop_iv else coverage_stop;
                }
            }
            coverage += coverage_stop - coverage_start;
            warn("{}\t{}\t{}\t{}\t{}\n", .{ chr, start, stop, n, coverage });
        } else {
            warn("{}\t{}\t{}\t0\t0\n", .{ chr, split_it.next().?, split_it.next().? });
        }
    }

    bed.deinit();
}
