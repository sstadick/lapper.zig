const std = @import("std");
const warn = std.debug.warn;
const testing = std.testing;
const ArrayList = std.ArrayList;

const lpr = @import("./lapper.zig");
const Interval = lpr.Interval;
const Lapper = lpr.Lapper;

fn setupSingle() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(10, 35, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

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

fn setupOverlapping() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(0, 15, 0),
        Iv.init(10, 25, 0),
        Iv.init(20, 35, 0),
        Iv.init(30, 45, 0),
        Iv.init(40, 55, 0),
        Iv.init(50, 65, 0),
        Iv.init(60, 75, 0),
        Iv.init(70, 85, 0),
        Iv.init(80, 95, 0),
        Iv.init(90, 105, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

fn setupLarge() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(0, 8, 0),
        Iv.init(1, 10, 0),
        Iv.init(2, 5, 0),
        Iv.init(3, 8, 0),
        Iv.init(4, 7, 0),
        Iv.init(5, 8, 0),
        Iv.init(8, 8, 0),
        Iv.init(9, 11, 0),
        Iv.init(10, 13, 0),
        Iv.init(100, 200, 0),
        Iv.init(110, 120, 0),
        Iv.init(110, 124, 0),
        Iv.init(111, 160, 0),
        Iv.init(150, 200, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

fn setupBadLapper() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(70, 120, 0), // max_len = 50
        Iv.init(12, 15, 0), // inner overlap
        Iv.init(14, 16, 0), // overlap end
        Iv.init(40, 45, 0),
        Iv.init(10, 15, 0), // exact overlap
        Iv.init(10, 12, 0),
        Iv.init(50, 55, 0),
        Iv.init(60, 65, 0),
        Iv.init(68, 71, 0), // overlap start
        Iv.init(70, 75, 0),
        Iv.init(150, 300, 0), // Test that sort order worked
        Iv.init(150, 200, 0),
        Iv.init(150, 290, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

fn setupComplexLapper() Lapper(i32) {
    const Iv = Interval(i32);
    const allocator = testing.allocator;
    var list = ArrayList(Iv).init(testing.allocator);
    var data = [_]Iv{
        Iv.init(25264912, 25264986, 0),
        Iv.init(27273024, 27273065, 0),
        Iv.init(27440273, 27440318, 0),
        Iv.init(27488033, 27488125, 0),
        Iv.init(27938410, 27938470, 0),
        Iv.init(27959118, 27959171, 0),
        Iv.init(28866309, 33141404, 0),
    };
    list.appendSlice(&data) catch unreachable;
    return Lapper(i32).init(allocator, list.toOwnedSlice());
}

fn test_all_single(lapper: Lapper(i32), start: u32, stop: u32, expected: ?Interval(i32)) void {
    var cursor: usize = 0;
    defer lapper.deinit();
    if (expected == null) {
        testing.expect(lapper.find(start, stop).next() == null);
        testing.expect(lapper.seek(start, stop, &cursor).next() == null);
    } else {
        const find_found = lapper.find(start, stop).next();
        warn("Find found: {}\n", .{find_found});
        const seek_found = lapper.seek(start, stop, &cursor).next();
        warn("Seek Found: {}\n", .{seek_found});
        testing.expect(find_found.?.start == expected.?.start and find_found.?.stop == expected.?.stop);
        testing.expect(seek_found.?.start == expected.?.start and seek_found.?.stop == expected.?.stop);
    }
}

fn test_all_multiple(lapper: Lapper(i32), start: u32, stop: u32, expected: []Interval(i32)) void {
    var cursor: usize = 0;
    defer lapper.deinit();
    defer testing.allocator.free(expected);

    var index: usize = 0;
    var find_it = lapper.find(start, stop);
    while (find_it.next()) |found| : (index += 1) {
        const exp = expected[index];
        warn("Find Found {}\nExpected {}\n", .{ found, exp });
        testing.expect(found.start == exp.start and found.stop == exp.stop);
    }
    index = 0;
    var seek_it = lapper.seek(start, stop, &cursor);
    while (seek_it.next()) |found| : (index += 1) {
        const exp = expected[index];
        warn("Seek Found {}\nExpected {}\n", .{ found, exp });
        testing.expect(found.start == exp.start and found.stop == exp.stop);
    }
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
test "lapper should return all intervals that it overlaps" {
    const lapper = setupOverlapping();
    const start: u32 = 8;
    const stop: u32 = 20;
    var expected_list = ArrayList(Interval(i32)).init(testing.allocator);
    var expected = [_]Interval(i32){ Interval(i32).init(0, 15, 0), Interval(i32).init(10, 25, 0) };
    expected_list.appendSlice(&expected) catch unreachable;
    test_all_multiple(lapper, start, stop, expected_list.toOwnedSlice());
}
test "lapper should find overlaps in large intervals" {
    const lapper = setupLarge();
    const start: u32 = 8;
    const stop: u32 = 11;
    var expected_list = ArrayList(Interval(i32)).init(testing.allocator);
    var expected = [_]Interval(i32){ Interval(i32).init(1, 10, 0), Interval(i32).init(9, 11, 0), Interval(i32).init(10, 13, 0) };
    expected_list.appendSlice(&expected) catch unreachable;
    test_all_multiple(lapper, start, stop, expected_list.toOwnedSlice());
}
test "lapper should find overlaps in large intervals (cont)" {
    const lapper = setupLarge();
    const start: u32 = 145;
    const stop: u32 = 151;
    var expected_list = ArrayList(Interval(i32)).init(testing.allocator);
    var expected = [_]Interval(i32){ Interval(i32).init(100, 200, 0), Interval(i32).init(111, 160, 0), Interval(i32).init(150, 200, 0) };
    expected_list.appendSlice(&expected) catch unreachable;
    test_all_multiple(lapper, start, stop, expected_list.toOwnedSlice());
}

// bug tests from real life
test "Lapper should not induce index out of bound by pushing curosr past end of lapper" {
    const lapper = setupNonOverlapping();
    const single = setupSingle();
    defer lapper.deinit();
    defer single.deinit();
    var cursor: usize = 0;
    for (lapper.intervals) |interval| {
        var it = single.seek(interval.start, interval.stop, &cursor);
        while (it.next()) |found| {
            testing.expect(found.start < 30);
        }
    }
}

test "Lapper should return first match if lower_bound puts us before first match" {
    const lapper = setupBadLapper();
    const start: u32 = 50;
    const stop: u32 = 55;
    const expected: ?Interval(i32) = Interval(i32).init(50, 55, 0);
    test_all_single(lapper, start, stop, expected);
}

// This tests to make sure the sort sorted correclty:
// Iv.init(150, 300, 0),
// Iv.init(150, 200, 0),
// Iv.init(150, 290, 0),
// If these were not sorted correctly, the second interval will cause find to break early
test "Lapper should find both intervals when one comes second in input, but has a smaller stop" {
    const lapper = setupBadLapper();
    const start: u32 = 280;
    const stop: u32 = 320;
    var expected_list = ArrayList(Interval(i32)).init(testing.allocator);
    var expected = [_]Interval(i32){
        Interval(i32).init(150, 290, 0),
        Interval(i32).init(150, 300, 0),
    };
    expected_list.appendSlice(&expected) catch unreachable;
    test_all_multiple(lapper, start, stop, expected_list.toOwnedSlice());
}

test "lapper finds correct max_len" {
    var ivs = [_]Interval(i32){ Interval(i32).init(0, 5, 0), Interval(i32).init(1, 6, 0), Interval(i32).init(2, 12, 2) };
    var list = ArrayList(Interval(i32)).init(testing.allocator);
    list.appendSlice(&ivs) catch unreachable;
    const lapper = Lapper(i32).init(testing.allocator, list.toOwnedSlice());
    defer lapper.deinit();
    testing.expect(lapper.max_len == 10);
}

test "Lapper should handle intervals that span many little intervals" {
    const lapper = setupComplexLapper();
    const start: u32 = 28974798;
    const stop: u32 = 33141355;
    var expected_list = ArrayList(Interval(i32)).init(testing.allocator);
    var expected = [_]Interval(i32){Interval(i32).init(28866309, 33141404, 0)};
    expected_list.appendSlice(&expected) catch unreachable;
    test_all_multiple(lapper, start, stop, expected_list.toOwnedSlice());
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
