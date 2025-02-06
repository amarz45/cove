const std = @import("std");
const io = @import("../io.zig");
const Battery = @This();

capacity:       u8,
stop_threshold: u8,
status:         Status,
energy_now:     f32,
energy_full:    f32,
power_now:      f32,

const Status = enum(u8) {
    charging     = 'C',
    discharging  = 'D',
    not_charging = 'N',
    _,
};

pub const time_len = "999 h 59 m 59 s".len;

pub fn init() !Battery {
    @setFloatMode(.optimized);

    const cwd = std.fs.cwd();
    var dir = try cwd.openDir("/sys/class/power_supply/BAT0", .{});
    defer dir.close();

    var energy_now_buf: [16]u8 = undefined;
    var energy_full_buf: [16]u8 = undefined;
    var power_now_buf: [16]u8 = undefined;
    var stop_threshold_buf: ["100".len]u8 = undefined;
    var status_buf: [1]u8 = undefined;

    const energy_now_slice = try io.readLineFile(
        &energy_now_buf, dir, "energy_now"
    );
    const energy_full_slice = try io.readLineFile(
        &energy_full_buf, dir, "energy_full"
    );
    const power_now_slice = try io.readLineFile(
        &power_now_buf, dir, "power_now"
    );
    const stop_threshold_slice = try io.readLineFile(
        &stop_threshold_buf, dir, "charge_stop_threshold"
    );
    const status: Status = @enumFromInt(
        try io.readFirstChar(&status_buf, dir, "status")
    );

    const energy_now = try std.fmt.parseFloat(f32, energy_now_slice);
    const energy_full = try std.fmt.parseFloat(f32, energy_full_slice);
    const power_now = try std.fmt.parseFloat(f32, power_now_slice);
    const stop_threshold = try std.fmt.parseUnsigned(u8, stop_threshold_slice, 10);

    const capacity: u8 = if (energy_full == 0)
        0
    else
        @intFromFloat(@round(energy_now/energy_full * 100));

    return .{
        .energy_now     = energy_now,
        .energy_full    = energy_full,
        .power_now      = power_now,
        .capacity       = capacity,
        .stop_threshold = stop_threshold,
        .status         = status,
    };
}
 
// The formulas for calculating the battery remaining time are as follows:
//     - time to empty (discharging) = energy_now / power_now
//     - time to full (charging) = (energy_full - energy_now) / power_now
pub fn getTimeRemaining(battery_ptr: *const Battery, writer: anytype) !void {
    @setFloatMode(.optimized);

    const capacity = battery_ptr.capacity;
    const stop_threshold = battery_ptr.stop_threshold;
    const energy_now = battery_ptr.energy_now;
    const energy_full = battery_ptr.energy_full;
    const power_now = battery_ptr.power_now;
    const status = battery_ptr.status;

    if (capacity == stop_threshold) {
        _ = try writer.write("~");
        return;
    } if (power_now == 0) {
        _ = try writer.write("\u{221e}"); // infinity
        return;
    }

    const hours_total = if (status == .charging)
        (energy_full - energy_now) / power_now
    else
        energy_now / power_now;

    //= Separate the hours, minutes, and seconds into their own components
    //= of the time.
    const hours_rounded = @trunc(hours_total);
    const hours: u8     = @intFromFloat(hours_rounded);

    // Convert the fractional component of the hours to minutes.
    const minutes_total   = (hours_total - hours_rounded) * 60;
    const minutes_rounded = @trunc(minutes_total);
    const minutes: u8     = @intFromFloat(minutes_rounded);

    // Convert the fractional component of the minutes to seconds.
    const seconds_total = (minutes_total - minutes_rounded) * 60;
    const seconds: u8   = @intFromFloat(seconds_total);

    if (hours != 0) {
        try writer.print("{d} h {d:.2} m {d:.2} s", .{hours, minutes, seconds});
    } else if (minutes != 0) {
        try writer.print("{d} m {d:.2} s", .{minutes, seconds});
    } else {
        try writer.print("{d} s", .{seconds});
    }
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
