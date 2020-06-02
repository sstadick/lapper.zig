const std = @import("std");
const math = std.math;

fn Lapper(comptime T: type) type {
    return struct {
        const Self = @This();
        intervals: []Interval(T),
        cursor: usize,
        max_len: u32,

        // TODO: whay does intervals have to be `var`
        pub fn init(intervals: []Interval(T)) Self {
            // sort the intervals
            std.sort.sort(Interval(T), intervals, Interval(T).lessThanStartStop);
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
                .cursor = 0,
            };
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
            var intersection: u32 = undefined;
            const overflow = @subWithOverflow(u32, math.min(self.stop, other.stop), math.max(self.start, other.start), &intersection);
            return if (overflow) 0 else intersection;
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
// Lapper tests
test "Lapper finds correct max_len" {
    var ivs = [_]Interval(i32){ Interval(i32).init(0, 5, 0), Interval(i32).init(1, 6, 0), Interval(i32).init(2, 12, 2) };
    const lapper = Lapper(i32).init(ivs[0..]);
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
