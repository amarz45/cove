const builtin = @import("builtin");
const std = @import("std");
const zeit = @import("zeit"); // time
const modules = @import("modules.zig");
const Config = @import("Config.zig");
const Output = @import("Output.zig");
const Timestamps = @import("Timestamps.zig");

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    // allocator
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer if (builtin.mode == .Debug) arena.deinit();
    const allocator = arena.allocator();

    // config
    var config: Config = .{
        .module_list    = .init(allocator),
        .text_list      = .init(allocator),
        .backlight_list = .init(allocator),
        .battery_list   = .init(allocator),
        .cpu_list       = .init(allocator),
        .drive_list     = .init(allocator),
        .memory_list    = .init(allocator),
        .time_list      = .init(allocator),
        .str_list       = .init(allocator),
    };
    var module_intervals: Config.ModuleIntervals = undefined;
    const modules_used = try config.parseConfig(&module_intervals);

    // output
    var output: Output = .{ .config = config };

    // CPU
    var cpu_data: modules.Cpu = undefined;
    const threads: f32 = threads: {
        if (!modules_used.cpu) {
            break :threads undefined;
        }
        try cpu_data.updateUptime();
        break :threads @floatFromInt(try std.Thread.getCpuCount());
    };

    // time
    var local = local: {
        if (!modules_used.time) {
            break :local undefined;
        }
        var env = try std.process.getEnvMap(allocator);
        defer env.deinit();
        break :local try zeit.local(allocator, &env);
    };
    defer if (builtin.mode == .Debug and modules_used.time) {
        local.deinit();
    };

    // backlight
    const backlight_dir_name = backlight_dir_name: {
        if (!modules_used.backlight) {
            break :backlight_dir_name undefined;
        }

        const cwd = std.fs.cwd();
        var backlight_base_dir = try cwd.openDir(
            modules.Backlight.base_dir_name, .{ .iterate = true }
        );
        defer backlight_base_dir.close();

        var backlight_iter = backlight_base_dir.iterate();
        const backlight_entry = try backlight_iter.next() orelse
            @panic("Backlight directory not found.");
        break :backlight_dir_name backlight_entry.name;
    };

    var result: std.ArrayList(u8) = .init(allocator);
    defer if (builtin.mode == .Debug) result.deinit();

    var timestamps: Timestamps = undefined;
    var timestamps_defined: Timestamps.Defined = .{};

    while (true) {
        defer {
            result.clearRetainingCapacity();
            std.time.sleep(std.time.ns_per_s); // one second
            output.text_index = 0;
        }

        for (output.config.module_list.items, 0..) |module, i| {
            if (i != 0) try result.append(' ');
            try output.handleModule(
                &result, module, &module_intervals, &timestamps,
                &timestamps_defined, &cpu_data, threads, backlight_dir_name,
                local
            );
        }

        try stdout.print("{s}\n", .{result.items});
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
