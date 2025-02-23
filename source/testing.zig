const std = @import("std");

pub inline fn expect_eql(actual: anytype, expected: @TypeOf(actual)) ! void {
    return std.testing.expectEqual(expected, actual);
}

pub inline fn expect_eql_str(actual: []const u8, expected: []const u8) ! void {
    return std.testing.expectEqualStrings(expected, actual);
}
