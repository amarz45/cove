const std = @import("std");
const testing = @import("testing.zig");

const expect_eql_str = testing.expect_eql_str;

pub const percent_len = "100 %".len;
pub const memory_len = "1024 KiB".len;
pub const time_len = "999 d 23 h 59 m 59 s".len;

pub inline fn percent(writer: anytype, _percent: anytype) ! void {
    try writer.print("{d:.0} %", .{_percent});
}

test percent {
    var array: std.BoundedArray(u8, percent_len) = .{};

    try percent(array.writer(), 0);
    try expect_eql_str(array.slice(), "0 %");

    array.clear();
    try percent(array.writer(), 0.0);
    try expect_eql_str(array.slice(), "0 %");

    array.clear();
    try percent(array.writer(), 10);
    try expect_eql_str(array.slice(), "10 %");

    array.clear();
    try percent(array.writer(), 10.0);
    try expect_eql_str(array.slice(), "10 %");

    array.clear();
    try percent(array.writer(), 100);
    try expect_eql_str(array.slice(), "100 %");

    array.clear();
    try percent(array.writer(), 100.0);
    try expect_eql_str(array.slice(), "100 %");
}

// Given a buffer and the memory amount in kibibytes, write to the buffer a
// string with the amount in a human-readable format with the appropriate unit.
pub fn memory(writer: anytype, kibibytes: f32) ! void {
    @setFloatMode(.optimized);

    const mem,
    const unit: *const [3]u8 = b: {
        if (kibibytes < 1 << 10) {
            @branchHint(.cold);
            break :b .{kibibytes, "KiB"};
        } else if (kibibytes < 1 << 20) {
            @branchHint(.unlikely);
            break :b .{kibibytes / (1 << 10), "MiB"};
        } else if (kibibytes < 1 << 30) {
            @branchHint(.likely);
            break :b .{kibibytes / (1 << 20), "GiB"};
        } else {
            @branchHint(.unlikely);
            break :b .{kibibytes / (1 << 30), "TiB"};
        }
    };

    return
    if (mem < 10)
        writer.print("{d:.2} {s}", .{mem, unit})
    else if (mem < 100)
        writer.print("{d:.1} {s}", .{mem, unit})
    else
        writer.print("{d:.0} {s}", .{mem, unit});
}

test memory {
    var array: std.BoundedArray(u8, memory_len) = .{};

    try memory(array.writer(), 0);
    try expect_eql_str(array.slice(), "0.00 KiB");

    array.clear();
    try memory(array.writer(), 9);
    try expect_eql_str(array.slice(), "9.00 KiB");

    array.clear();
    try memory(array.writer(), 10);
    try expect_eql_str(array.slice(), "10.0 KiB");

    array.clear();
    try memory(array.writer(), 99);
    try expect_eql_str(array.slice(), "99.0 KiB");

    array.clear();
    try memory(array.writer(), 100);
    try expect_eql_str(array.slice(), "100 KiB");

    array.clear(); 
    try memory(array.writer(), 1000);
    try expect_eql_str(array.slice(), "1000 KiB");

    array.clear(); 
    try memory(array.writer(), 1023);
    try expect_eql_str(array.slice(), "1023 KiB");

    array.clear();
    try memory(array.writer(), 1 << 10);
    try expect_eql_str(array.slice(), "1.00 MiB");

    array.clear();
    try memory(array.writer(), 1 << 20);
    try expect_eql_str(array.slice(), "1.00 GiB");

    array.clear();
    try memory(array.writer(), 1 << 30);
    try expect_eql_str(array.slice(), "1.00 TiB");
}

// -------------------------------------------------------------------------- //
// Cove
//
// Written in 2025 by Amar Al-Zubaidi <mail@amarz.net>
//
// To the extent possible under law, the author(s) have dedicated all
// copyright and related and neighboring rights to this software to the
// public domain worldwide. This software is distributed without any
// warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along
// with this software. If not, see
// <https://creativecommons.org/publicdomain/zero/1.0/>.
