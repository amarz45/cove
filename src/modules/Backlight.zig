const std = @import("std");
const io = @import("io.zig");

percent: f32,

pub const base_dir_name = "/sys/class/backlight";
const Self = @This();

pub fn init(dir_name: []const u8) !Self {
    @setFloatMode(.optimized);

    var base_dir = try std.fs.cwd()
        .openDir(base_dir_name, .{ .iterate = true });
    defer base_dir.close();

    var dir = try base_dir.openDir(dir_name, .{});
    defer dir.close();

    var brightness_buf: [16]u8 = undefined;
    var max_brightness_buf: [16]u8 = undefined;

    const brightness_slice = try io
        .readLineFile(&brightness_buf, dir, "brightness");
    const max_brightness_slice = try io
        .readLineFile(&max_brightness_buf, dir, "max_brightness");

    const brightness = try std.fmt.parseFloat(f32, brightness_slice);
    const max_brightness = try std.fmt.parseFloat(f32, max_brightness_slice);

    const percent: f32 = if (max_brightness == 0)
        0
    else
        brightness / max_brightness * 100.0;

    return .{ .percent = percent };
}

const expect = std.testing.expect;

test "backlight" {
    const cwd = std.fs.cwd();
    var base_dir = try cwd.openDir(base_dir_name, .{ .iterate = true });
    defer base_dir.close();

    var iter = base_dir.iterate();
    const entry = try iter.next();

    const dir_name = entry.?.name;
    const backlight: Self = try .init(dir_name);

    try expect(backlight.percent >= 0);
    try expect(backlight.percent <= 100);
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
