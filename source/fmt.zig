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

    const mem, const unit: *const [3]u8 = mem: {
        if (kibibytes < 1 << 10) {
            @branchHint(.cold);
            break :mem .{kibibytes, "KiB"};
        } else if (kibibytes < 1 << 20) {
            @branchHint(.unlikely);
            break :mem .{kibibytes / (1 << 10), "MiB"};
        } else if (kibibytes < 1 << 30) {
            @branchHint(.likely);
            break :mem .{kibibytes / (1 << 20), "GiB"};
        } else {
            @branchHint(.unlikely);
            break :mem .{kibibytes / (1 << 30), "TiB"};
        }
    };

    if (mem < 10) {
        try writer.print("{d:.2} {s}", .{mem, unit});
    } else if (mem < 100) {
        try writer.print("{d:.1} {s}", .{mem, unit});
    } else {
        try writer.print("{d:.0} {s}", .{mem, unit});
    }
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

pub fn time(writer: anytype, seconds_total: f32) ! void {
    @setFloatMode(.optimized);

    if (seconds_total < 60) {
        try writer.print("{d:.0} s", .{seconds_total});
    } else if (seconds_total < 60*60) {
        const minutes_total = seconds_total / 60;
        const data = minutes_seconds(minutes_total);

        try writer.print("{d} m {d:02} s", .{data.minutes, data.seconds});
    } else if (seconds_total < 60*60*24) {
        @branchHint(.likely);

        const hours_total = seconds_total / (60*60);
        const data = hours_minutes_seconds(hours_total);

        try writer.print(
            "{d} h {d:02} m {d:02} s",
            .{data.hours, data.minutes, data.seconds}
        );
    } else {
        const days_total = seconds_total / (60*60*24);
        const data = days_hours_minutes_seconds(days_total);

        try writer.print(
            "{d} d {d:02} h {d:02} m {d:02} s",
            .{data.days, data.hours, data.minutes, data.seconds}
        );
    }
}

// Separate an irrational number of days into integer days, hours, minutes, and
// seconds.
inline fn days_hours_minutes_seconds(days_total: f32) struct {
    days:    f32,
    hours:   f32,
    minutes: f32,
    seconds: f32,
} {
    const days = @trunc(days_total);
    const hours_total = (days_total - days) * 24;
    const data = hours_minutes_seconds(hours_total);
    return .{
        .days    = days,
        .hours   = data.hours,
        .minutes = data.minutes,
        .seconds = data.seconds,
    };
}

// Separate an irrational number of hours into integer hours, minutes, and
// seconds.
inline fn hours_minutes_seconds(hours_total: f32) struct {
    hours:   f32,
    minutes: f32,
    seconds: f32,
} {
    const hours = @trunc(hours_total);
    const minutes_total = (hours_total - hours) * 60;
    const data = minutes_seconds(minutes_total);
    return .{ .hours = hours, .minutes = data.minutes, .seconds = data.seconds };
}

// Separate an irrational number of minutes into integer minutes and seconds.
inline fn minutes_seconds(minutes_total: f32) struct {
    minutes: f32,
    seconds: f32,
} {
    const minutes = @trunc(minutes_total);
    const seconds = @round((minutes_total - minutes) * 60);
    return .{ .minutes = minutes, .seconds = seconds };
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
