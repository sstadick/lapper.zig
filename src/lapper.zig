const std = @import("std");
const math = std.math;
const warn = @import("std").debug.warn;
const Allocator = std.mem.Allocator;

// helper function that returns zero if subtraction overflows
inline fn checkedSub(comptime T: type, lhs: T, rhs: T) T {
    var result: T = undefined;
    const overflow = @subWithOverflow(T, lhs, rhs, &result);
    return if (overflow) 0 else result;
}

pub fn Lapper(comptime T: type) type {
    return struct {
        const Self = @This();
        intervals: []Interval(T),
        max_len: u32,
        allocator: *Allocator,
        /// Create a Lapper object
        /// The allocator is for deallocating the owned slice of intervals
        pub fn init(allocator: *Allocator, intervals: []Interval(T)) Self {
            // sort the intervals
            std.sort.sort(Interval(T), intervals, Interval(T).lessThan);
            var max: u32 = 0;
            for (intervals) |interval| {
                const iv_len = interval.stop - interval.start;
                if (iv_len > max) {
                    max = iv_len;
                }
            }
            return Self{
                .intervals = intervals,
                .max_len = max,
                .allocator = allocator,
            };
        }
        pub fn deinit(self: Self) void {
            self.allocator.free(self.intervals);
        }

        inline fn swap(iv_a: *Interval(T), iv_b: *Interval(T)) void {
            var temp: Interval(T) = iv_a.*;
            iv_a.* = iv_b.*;
            iv_b.* = temp;
        }

        inline fn bubblesort(ivs: []Interval(T)) void {
            var i: usize = 0;
            while (i < ivs.len) : (i += 1) {
                var j: usize = 0;
                while (j < ivs.len - i - 1) : (j += 1) {
                    if (ivs[j].start > ivs[j + 1].start) {
                        swap(&ivs[j], &ivs[j + 1]);
                    }
                }
            }
        }

        inline fn lowerBound(start: u32, intervals: []Interval(T)) usize {
            var size = intervals.len;
            var low: usize = 0;

            while (size > 0) {
                const half = size / 2; // TODO: check that this is int div
                const other_half = size - half;
                const probe = low + half;
                const other_low = low + other_half;
                const v = intervals[probe];
                size = half;
                low = if (v.start < start) other_low else low;
            }
            return low;
        }

        pub fn find(self: *const Self, start: u32, stop: u32) IterFind(T) {
            return IterFind(T){
                .intervals = self.intervals,
                .offset = Self.lowerBound(checkedSub(u32, start, self.max_len), self.intervals),
                .end = self.intervals.len,
                .start = start,
                .stop = stop,
            };
        }

        pub fn seek(self: *const Self, start: u32, stop: u32, cursor: *usize) IterFind(T) {
            if (cursor.* == 0 or (cursor.* < self.intervals.len and self.intervals[cursor.*].start > start)) {
                cursor.* = Self.lowerBound(checkedSub(u32, start, self.max_len), self.intervals);
            }
            while (cursor.* + 1 < self.intervals.len and self.intervals[cursor.* + 1].start < checkedSub(u32, start, self.max_len)) {
                cursor.* += 1;
            }
            // we don't want the iterator to move the cursor
            return IterFind(T){
                .intervals = self.intervals,
                .offset = cursor.*,
                .end = self.intervals.len,
                .start = start,
                .stop = stop,
            };
        }
    };
}

fn IterFind(comptime T: type) type {
    return struct {
        const Self = @This();
        intervals: []Interval(T),
        offset: usize,
        end: usize,
        start: u32,
        stop: u32,

        fn next(self: *Self) ?Interval(T) {
            while (self.offset < self.end) {
                const interval = self.intervals[self.offset];
                self.offset += 1;
                if (interval.overlap(self.start, self.stop)) {
                    return interval;
                } else if (interval.start >= self.stop) {
                    break;
                }
            }
            return null;
        }
    };
}

/// Represents an Interval that can hold a `val` of any type
pub fn Interval(comptime T: type) type {
    return struct {
        const Self = @This();
        start: u32,
        stop: u32,
        val: T,

        /// Creates an `Interval`
        /// ```
        /// const iv = Interval(bool).init(0, 10, true);
        /// ```
        pub fn init(start: u32, stop: u32, val: T) Self {
            return Self{ .start = start, .stop = stop, .val = val };
        }

        /// Compute the intersect between two intervals
        /// ```
        /// const iv = Interval(bool).init(0, 5, true);
        /// iv.intersect(Interval(bool).init(4, 6, true)) == 1
        /// ```
        pub inline fn intersect(self: Self, other: Self) u32 {
            return checkedSub(u32, math.min(self.stop, other.stop), math.max(self.start, other.start));
        }

        /// Compute whether self overlaps a range
        /// ```
        /// const iv = Interval(bool).init(0, 5. 0)
        /// iv.overlap(4, 6) == true
        /// ```
        pub inline fn overlap(self: Self, start: u32, stop: u32) bool {
            return self.start < stop and self.stop > start;
        }

        // Return true if left is less than right
        fn lessThan(left: Self, right: Self) bool {
            if (left.start < right.start) {
                return true;
            }
            if (left.start > right.start) {
                return false;
            }
            // they are equal start positions
            return left.stop < right.stop;
        }
    };
}
