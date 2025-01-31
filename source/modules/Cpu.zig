const std = @import("std");
const Cpu = @This();

system_up: f32,
cpu_idle:  f32,
percent:   f32,

const expect = std.testing.expect;

pub fn updateUptime(cpu_ptr: *Cpu) !void {
    var buf: [32]u8 = undefined;

    var file = try std.fs.cwd().openFile("/proc/uptime", .{});
    defer file.close();

    var end_index = try file.pread(&buf, 0) - 1;
    if (buf[end_index] != '\n') end_index += 1;
    const sep_index = std.mem.indexOfScalar(u8, &buf, ' ') orelse
        @panic("/proc/uptime: space not found.");

    // system uptime in seconds
    const system_up = try std.fmt
        .parseFloat(f32, buf[0..sep_index]);
    // total core idletime in seconds
    const cpu_idle = try std.fmt
        .parseFloat(f32, buf[(sep_index + 1)..end_index]);

    cpu_ptr.system_up = system_up;
    cpu_ptr.cpu_idle = cpu_idle;
}

pub fn update(cpu_ptr: *Cpu, threads: f32) !void {
    @setFloatMode(.optimized);

    // Get the old uptime and idletime values.
    const uptime_1 = cpu_ptr.system_up;
    const idletime_1 = cpu_ptr.cpu_idle;
    
    // Get the new uptime and idletime values.
    try cpu_ptr.updateUptime();
    const uptime_2 = cpu_ptr.system_up;
    const idletime_2 = cpu_ptr.cpu_idle;

    // Calculate the CPU usage.
    const delta_uptime = uptime_2 - uptime_1;
    const delta_idletime = idletime_2 - idletime_1;
    const usage = delta_uptime - delta_idletime / threads;
    const percent = usage * 100;

    // Make sure that the percentage value is in the interval [0, 100].
    cpu_ptr.percent = if (percent < 0)
        0
    else if (percent > 100)
        100
    else
        percent;
}

test "cpu" {
    var cpu: Cpu = undefined;

    try cpu.updateUptime();
    try expect(cpu.system_up >= 0);
    try expect(cpu.cpu_idle >= 0);

    try cpu.update(1);
    try expect(cpu.system_up >= 0);
    try expect(cpu.cpu_idle >= 0);
    try expect(cpu.percent >= 0);
    try expect(cpu.percent <= 100);
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
