const builtin = @import("builtin");
const std = @import("std");
const zeit = @import("zeit"); // time
const modules = @import("modules.zig");
const Config = @import("Config.zig");
const Output = @import("Output.zig");
const Timestamps = @import("Timestamps.zig");

const stdout = std.io.getStdOut().writer();

pub fn main() ! void {
    // allocator
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer if (builtin.mode == .Debug) arena.deinit();
    const allocator = arena.allocator();

    // config
    var config: Config = .init(allocator);
    var module_intervals: Config.Module_intervals = undefined;
    const modules_used = try config.parse_config(&module_intervals);
    const update_interval = get_update_interval(
        &module_intervals, modules_used
    );

    // output
    var output: Output = .{ .config = config };

    // CPU
    var cpu_data: modules.Cpu = undefined;
    const threads: f32 = b: {
        if (!modules_used.cpu) {
            break :b undefined;
        }
        try cpu_data.update_uptime();
        break :b @floatFromInt(try std.Thread.getCpuCount());
    };

    // time
    var local = b: {
        if (!modules_used.time) {
            break :b undefined;
        }
        var env = try std.process.getEnvMap(allocator);
        defer env.deinit();
        break :b try zeit.local(allocator, &env);
    };
    defer if (builtin.mode == .Debug and modules_used.time) {
        local.deinit();
    };

    // backlight
    const backlight_dir_name = b: {
        if (!modules_used.backlight) {
            break :b undefined;
        }

        const cwd = std.fs.cwd();
        var backlight_base_dir = try cwd.openDir(
            modules.Backlight.base_dir_name, .{ .iterate = true }
        );
        defer backlight_base_dir.close();

        var backlight_iter = backlight_base_dir.iterate();
        const backlight_entry = try backlight_iter.next() orelse
            @panic("Backlight directory not found.");
        break :b backlight_entry.name;
    };

    var result: std.ArrayList(u8) = .init(allocator);
    defer if (builtin.mode == .Debug) result.deinit();

    var timestamps: Timestamps = .{};

    while (true) {
        defer {
            result.clearRetainingCapacity();
            std.time.sleep(update_interval); // one second
            output.text_index = 0;
        }

        for (output.config.module_list.items, 0..) |module, i| {
            if (i != 0) try result.append(' ');
            try output.handle_module(
                &result, module, &module_intervals, &timestamps,
                &cpu_data, threads, backlight_dir_name,
                local
            );
        }

        try stdout.print("{s}\n", .{result.items});
    }
}

fn get_update_interval(
    module_intervals: *const Config.Module_intervals,
    modules_used: Config.Modules_used,
)
u64 {
    const fields = std.meta.fields(Config.Module_intervals);

    var gcd = @field(module_intervals, fields[0].name);
    var gcd_defined = @field(modules_used, fields[0].name);

    inline for (fields[1..]) |field| {
        const interval = @field(module_intervals, field.name);
        const interval_defined = @field(modules_used, field.name);

        if (!gcd_defined) {
            gcd = interval;
            gcd_defined = interval_defined;
        }
        else if (interval_defined) {
            gcd = std.math.gcd(gcd, interval);
        }
    }

    return gcd;
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
