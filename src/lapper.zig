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

fn Lapper(comptime T: type) type {
    return struct {
        const Self = @This();
        intervals: []Interval(T),
        max_len: u32,
        allocator: *Allocator,
        /// Create a Lapper object
        /// The allocator is for deallocating the owned slice of intervals
        pub fn init(allocator: *Allocator, intervals: []Interval(T)) Self {
            // sort the intervals
            std.sort.sort(Interval(T), intervals, Interval(T).lessThanStartStop);
            warn("Init lapper; {}\n", .{intervals});
            for (intervals) |iv| {
                warn("iv: {}\n", .{iv});
            }
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
                .allocator = allocator
            };
        }
        pub fn deinit(self: Self) void {
            self.allocator.free(self.intervals);
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

        pub fn find(self: Self, start: u32, stop: u32) IterFind(T) {
            warn("Searching for {}, {}\n", .{start, stop});
            warn("Offset found: {}\n", .{Self.lowerBound(checkedSub(u32, start, self.max_len), self.intervals)});
            warn("wtf lapper: {}\n", .{self});
            return IterFind(T){
                .inner = &self,
                .offset = &Self.lowerBound(checkedSub(u32, start, self.max_len), self.intervals),
                .end = self.intervals.len,
                .start = start,
                .stop = stop,
            };
        }
        
        pub fn seek(self: Self, start: u32, stop: u32, cursor: *usize) IterFind(T) {
            if (cursor.* == 0 or (cursor.* < self.intervals.len and self.intervals[cursor.*].start > start)) {
                cursor.* = Self.lowerBound(checkedSub(u32, start, self.max_len), self.intervals);
            }
            while (cursor.* + 1 < self.intervals.len and self.intervals[cursor.* + 1].start < checkedSub(u32, start, self.max_len)) {
                cursor.* += 1;
            }
            // we don't want the iterator to move the cursor
            var cursor_val: usize = cursor.*;
            return IterFind(T){
                .inner = &self,
                .offset = &cursor_val,
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
        inner: *const Lapper(T),
        offset: *usize,
        end: usize,
        start: u32,
        stop: u32,

        fn next(self: Self) ?Interval(T) {
            warn("wtf: {}\n", .{self});
            warn("offsert: {}\n", .{self.offset.*});
            for (self.inner.*.intervals) |iv| {
                warn("iv -> {}\n", .{iv});
            }
            while (self.offset.* < self.end) {
                const interval = self.inner.intervals[self.offset.*];
                warn("Checking Iv: {} for overlap with query {},{}\n", .{interval, self.start, self.stop});
                self.offset.* += 1;
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
fn Interval(comptime T: type) type {
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
        fn lessThanStartStop(left: Self, right: Self) bool {
            if (left.start < right.start) {
                return true;
            }
            if (left.start > right.start) {
                return false;
            }
            // the are equal start positions
            if (left.stop < right.stop) {
                return true;
            }
            if (left.stop > right.stop) {
                return false;
            }
            return true; // The are both equal, default to left being less than right
        }
    };
}

//-------------- TESTS --------------
const testing = std.testing;
const ArrayList  = std.ArrayList;

fn setupNonOverlapping() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(0, 10, 0),
        Iv.init(20, 30, 0),
        Iv.init(40, 50, 0),
        Iv.init(60, 70, 0),
        Iv.init(80, 90, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

fn test_all_single(lapper: Lapper(i32), start: u32, stop: u32, expected: ?Interval(i32)) void {
    var cursor: usize = 0;
    defer lapper.deinit();
    const founds = [_]?Interval(i32){lapper.find(start, stop).next(), lapper.seek(start, stop, &cursor).next()};
    for (founds) |found| {
        if (found) |value| {
            if (expected) |exp| {
                // found value and expected value
                warn("Expecting {}.\nFound {}\n", .{expected, found});
                testing.expect(value.start == exp.start and value.stop == exp.stop);
            } else {
                // expected null, found value
                warn("Expecting {}.\nFound {}\n", .{expected, found});
                testing.expect(false);
            }
        } else {
            if (expected) |exp| {
                // found null, expected value
                warn("Expecting {}.\nFound {}\n", .{expected, found});
                testing.expect(false);
            } else {
                // both null
                warn("Expecting {}.\nFound {}\n", .{expected, found});
                testing.expect(true);
            }
        }
    }
}

fn test_all_multiple(lapper: Lapper(i32), start: u32, stop: u32, expected: []Interval(i32)) void {
    var cursor: usize = 0;
    var list = ArrayList(Interval(i32)).init(*testing.allocator);
    defer lapper.deinit()
    defer testing.allocator.free(expected);
    defer list.deinit();
}

// Lapper tests
test "Lapper should return null for a query.stop that hits an interval.start" {
    const lapper = setupNonOverlapping();
    const start: u32 = 15;
    const stop: u32 = 20;
    const expected: ?Interval(i32) = null;
    test_all_single(lapper, start, stop, expected);
}
test "Lapper should return null for a query.start that hits an interval.stop" {
    const lapper = setupNonOverlapping();
    const start: u32 = 30;
    const stop: u32 = 35;
    const expected: ?Interval(i32) = null;
    test_all_single(lapper, start, stop, expected);
}
test "Lapper should return an interval for a that query overlaps the start of the interval" {
    const lapper = setupNonOverlapping();
    const start: u32 = 15;
    const stop: u32 = 25;
    const expected: ?Interval(i32) = Interval(i32).init(20, 30, 0);
    test_all_single(lapper, start, stop, expected);
}
test "Lapper should return an interval for a that query overlaps the stop of the interval" {
    const lapper = setupNonOverlapping();
    const start: u32 = 25;
    const stop: u32 = 35;
    const expected: ?Interval(i32) = Interval(i32).init(20, 30, 0);
    test_all_single(lapper, start, stop, expected);
}
test "Lapper should return an interval for a query is enveloped by the interval" {
    const lapper = setupNonOverlapping();
    const start: u32 = 22;
    const stop: u32 = 27;
    const expected: ?Interval(i32) = Interval(i32).init(20, 30, 0);
    test_all_single(lapper, start, stop, expected);
}
test "Lapper should return an interval for a query envelops the interval" {
    const lapper = setupNonOverlapping();
    const start: u32 = 20;
    const stop: u32 = 30;
    const expected: ?Interval(i32) = Interval(i32).init(20, 30, 0);
    test_all_single(lapper, start, stop, expected);
}

test "Lapper finds correct max_len" {
    var ivs = [_]Interval(i32){ Interval(i32).init(0, 5, 0), Interval(i32).init(1, 6, 0), Interval(i32).init(2, 12, 2) };
    var list = ArrayList(Interval(i32)).init(testing.allocator);
    list.appendSlice(&ivs) catch unreachable;
    const lapper = Lapper(i32).init(testing.allocator, list.toOwnedSlice());
    defer lapper.deinit();
    testing.expect(lapper.max_len == 10);
}

// Interval tests
test "Interval should intersect an identical interval" {
    const iv1 = Interval(bool).init(10, 15, true);
    const iv2 = Interval(bool).init(10, 15, true);
    testing.expect(iv1.intersect(iv2) == 5);
}
test "Interval should intersect an inner interval" {
    const iv1 = Interval(bool).init(10, 15, true);
    const iv2 = Interval(bool).init(12, 15, true);
    testing.expect(iv1.intersect(iv2) == 3);
}
test "Interval should intersect an interval overlapping endpoint" {
    const iv1 = Interval(bool).init(10, 15, true);
    const iv2 = Interval(bool).init(14, 15, true);
    testing.expect(iv1.intersect(iv2) == 1);
}
test "Interval should intersect an interval overlapping startpoint" {
    const iv1 = Interval(bool).init(68, 71, true);
    const iv2 = Interval(bool).init(70, 75, true);
    testing.expect(iv1.intersect(iv2) == 1);
}
test "Interval should not intersect an interval it doesn't overlap" {
    const iv1 = Interval(bool).init(50, 55, true);
    const iv2 = Interval(bool).init(60, 65, true);
    testing.expect(iv1.intersect(iv2) == 0);
}
test "Interval should not intersect an interval where iv1.stop == iv2.start" {
    const iv1 = Interval(bool).init(40, 50, true);
    const iv2 = Interval(bool).init(50, 55, true);
    testing.expect(iv1.intersect(iv2) == 0);
}
test "Interval should not intersect an interval where iv1.start== iv2.start" {
    const iv1 = Interval(bool).init(70, 120, true);
    const iv2 = Interval(bool).init(70, 75, true);
    testing.expect(iv1.intersect(iv2) == 5);
}
