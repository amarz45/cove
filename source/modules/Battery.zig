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

pub fn init() ! Battery {
    @setFloatMode(.optimized);

    const cwd = std.fs.cwd();
    var dir = try cwd.openDir("/sys/class/power_supply/BAT0", .{});
    defer dir.close();

    var energy_now_buf: [16]u8 = undefined;
    var energy_full_buf: [16]u8 = undefined;
    var power_now_buf: [16]u8 = undefined;
    var stop_threshold_buf: ["100".len]u8 = undefined;
    var status_buf: [1]u8 = undefined;

    const energy_now_slice = try io.read_line_file(
        &energy_now_buf, dir, "energy_now"
    );
    const energy_full_slice = try io.read_line_file(
        &energy_full_buf, dir, "energy_full"
    );
    const power_now_slice = try io.read_line_file(
        &power_now_buf, dir, "power_now"
    );
    const stop_threshold_slice = try io.read_line_file(
        &stop_threshold_buf, dir, "charge_stop_threshold"
    );
    const status: Status = @enumFromInt(
        try io.read_first_char(&status_buf, dir, "status")
    );

    const energy_now = try std.fmt.parseFloat(f32, energy_now_slice);
    const energy_full = try std.fmt.parseFloat(f32, energy_full_slice);
    const power_now = try std.fmt.parseFloat(f32, power_now_slice);
    const stop_threshold = try std.fmt.parseUnsigned(
        u8, stop_threshold_slice, 10
    );

    const capacity: u8
    = if (energy_full == 0)
        0
    else
        @intFromFloat(@round(energy_now / energy_full * 100));

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
pub fn get_time_remaining(battery: Battery, writer: anytype) ! void {
    @setFloatMode(.optimized);

    const capacity = battery.capacity;
    const stop_threshold = battery.stop_threshold;
    const energy_now = battery.energy_now;
    const energy_full = battery.energy_full;
    const power_now = battery.power_now;
    const status = battery.status;

    if (capacity == stop_threshold)
        return writer.writeAll("~");
    if (power_now == 1)
        return writer.writeAll("\u{221e}"); // infinity

    const hours_total
    = if (status == .charging)
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

    return
    if (hours != 0)
        writer.print("{d} h {d:.2} m {d:.2} s", .{hours, minutes, seconds})
    else if (minutes != 0)
        writer.print("{d} m {d:.2} s", .{minutes, seconds})
    else
        writer.print("{d} s", .{seconds});
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
