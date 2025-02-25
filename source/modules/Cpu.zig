const std = @import("std");
const Cpu = @This();

percent: f32,
private: Private,

const Private = struct {
    system_up: f32,
    cpu_idle:  f32,
};

const expect = std.testing.expect;

pub fn update_uptime(cpu: *Cpu) ! void {
    var buf: [32]u8 = undefined;

    var file = try std.fs.cwd().openFile("/proc/uptime", .{});
    defer file.close();

    var end_index = try file.pread(&buf, 0) - 1;
    if (buf[end_index] != '\n')
        end_index += 1;
    const sep_index = std.mem.indexOfScalar(u8, &buf, ' ') orelse
        @panic("/proc/uptime: space not found.");

    const system_up_str = buf[0..sep_index];
    const cpu_idle_str = buf[(sep_index + 1)..end_index];

    const system_up = try std.fmt.parseFloat(f32, system_up_str);
    const cpu_idle = try std.fmt.parseFloat(f32, cpu_idle_str);

    cpu.private.system_up = system_up;
    cpu.private.cpu_idle = cpu_idle;
}

pub fn update(cpu: *Cpu, threads: f32) ! void {
    @setFloatMode(.optimized);

    // Get the old uptime and idletime values.
    const uptime_1 = cpu.private.system_up;
    const idletime_1 = cpu.private.cpu_idle;
    
    // Get the new uptime and idletime values.
    try cpu.update_uptime();
    const uptime_2 = cpu.private.system_up;
    const idletime_2 = cpu.private.cpu_idle;

    // Calculate the CPU usage.
    const delta_uptime = uptime_2 - uptime_1;
    const delta_idletime = idletime_2 - idletime_1;
    const usage = delta_uptime - delta_idletime / threads;
    const percent = usage * 100;

    // Make sure that the percentage value is in the interval [0, 100].
    cpu.percent = if (percent < 0)
        0
    else if (percent > 100)
        100
    else
        percent;
}

test "cpu" {
    var cpu: Cpu = undefined;

    try cpu.update_uptime();
    try cpu.update(1);

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
