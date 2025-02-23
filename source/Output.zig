const std = @import("std");
const zeit = @import("zeit");
const modules = @import("modules.zig");
const markup = @import("markup.zig");
const fmt = @import("fmt.zig");
const Config = @import("Config.zig");
const Timestamps = @import("Timestamps.zig");
const Output = @This();

config:                 Config,
backlight_percent:      Array_percent        = undefined,
battery_capacity:       Array_percent        = undefined,
cpu_usage:              Array_percent        = undefined,

memory_total:           Array_memory         = undefined,
memory_free:            Array_memory         = undefined,
memory_buffers:         Array_memory         = undefined,
memory_cached:          Array_memory         = undefined,
memory_used:            Array_memory         = undefined,

battery_time_remaining: Array_battery_time   = undefined,
battery_status:         Array_battery_status = undefined,

uptime:                 Array_uptime         = undefined,
time:                   Array_time           = undefined,

text_index:             u64                  = 0,

const Array_percent = std.BoundedArray(u8, fmt.percent_len);
const Array_memory = std.BoundedArray(u8, fmt.memory_len);
const Array_battery_time = std.BoundedArray(u8, modules.Battery.time_len);
const Array_battery_status = std.BoundedArray(u8, "Not charging".len);
const Array_uptime = std.BoundedArray(u8, fmt.time_len);
const Array_time = std.BoundedArray(u8, 128);

pub fn handle_module(
    output: *Output,
    result: *std.ArrayList(u8),
    module: Config.Module,
    module_intervals: *Config.Module_intervals,
    timestamps: *Timestamps,
    cpu_data: *modules.Cpu,
    threads: f32,
    backlight_dir_name: []const u8,
    local: zeit.TimeZone,
)
! void {
    switch (module) {
        .separator => {
            try result.appendSlice(markup.separator);
        },
        .text => {
            try output.update_text(result);
        },
        .backlight => {
            try output.update_backlight(
                result, timestamps, module_intervals.backlight.?,
                backlight_dir_name
            );
        },
        .battery => {
            try output.update_battery(
                result, timestamps, module_intervals.battery.?
            );
        },
        .cpu => {
            try output.update_cpu(
                result, timestamps, module_intervals.cpu.?,
                cpu_data, threads
            );
        },
        .memory => {
            try output.update_memory(
                result, timestamps, module_intervals.memory.?
            );
        },
        .time => {
            try output.update_time(result, local);
        },
    }
}

pub fn update_text(output: *Output, result: *std.ArrayList(u8)) ! void {
    const config = output.config;
    for (config.text_list.items) |arg| switch (arg) {
        .text => try output.append_text(result),
        else  => {},
    };
}

pub fn update_backlight(
    output: *Output,
    result: *std.ArrayList(u8),
    timestamps: *Timestamps,
    interval: u64,
    dir_name: []const u8,
)
! void {
    const backlight: modules.Backlight = try .init(dir_name);

    const prefix: []const u8 = prefix: {
        break :prefix if (backlight.percent < 25)
            "󰃞"
        else if (backlight.percent < 50)
            "󰃝"
        else if (backlight.percent < 75)
            "󰃟"
        else
            "󰃠";
    }++" ";

    try result.appendSlice(prefix);

    const update_needed = timestamps.is_update_needed(
        interval, "backlight"
    );

    const config = output.config;
    for (config.backlight_list.items) |arg| switch (arg) {
        .percent => {
            if (update_needed) {
                output.backlight_percent.clear();
                const writer = output.backlight_percent.writer();
                try fmt.percent(writer, backlight.percent);
            }
            const array = output.backlight_percent;
            try result.appendSlice(array.constSlice());
        },
        .text => {
            try output.append_text(result);
        },
        else => {},
    };
}

pub fn update_battery(
    output: *Output,
    result: *std.ArrayList(u8),
    timestamps: *Timestamps,
    interval: u64,
)
! void {
    const battery: modules.Battery = try .init();

    const prefix = switch (battery.status) {
        .charging => switch (battery.capacity) {
            0...9   => "󰢟", 10...19 => "󰢜", 20...29 => "󰂆", 30...39 => "󰂇",
            40...49 => "󰂈", 50...59 => "󰢝", 60...69 => "󰂉", 70...79 => "󰢞",
            80...89 => "󰂊", 90...99 => "󰂋", else    => "󰂅"
        },
        else => switch (battery.capacity) {
            0...9   => "󰂎", 10...19 => "󰁺", 20...29 => "󰁻", 30...39 => "󰁼",
            40...49 => "󰁽", 50...59 => "󰁾", 60...69 => "󰁿", 70...79 => "󰂀",
            80...89 => "󰂁", 90...99 => "󰂂", else    => "󰁹"
        },
    }++" ";

    try result.appendSlice(prefix);

    const update_needed = timestamps.is_update_needed(
        interval, "battery"
    );

    const config = output.config;
    for (config.battery_list.items) |arg| switch (arg) {
        .remaining_percent => {
            if (update_needed) {
                output.battery_capacity.clear();
                const writer = output.battery_capacity.writer();
                try fmt.percent(writer, battery.capacity);
            }
            const array = output.battery_capacity;
            try result.appendSlice(array.constSlice());
        },
        .status => {
            if (update_needed) {
                const status = switch (battery.status) {
                    .charging     => "Charging",
                    .discharging  => "Discharging",
                    .not_charging => "Not charging",
                    else          => "Unknown",
                };
                output.battery_status.clear();
                const writer = output.battery_status.writer();
                _ = try writer.write(status);
            }
            const array = output.battery_status;
            try result.appendSlice(array.constSlice());
        },
        .time_remaining => {
            if (update_needed) {
                output.battery_time_remaining.clear();
                const writer = output.battery_time_remaining.writer();
                try battery.get_time_remaining(writer);
            }
            const array = output.battery_time_remaining;
            try result.appendSlice(array.constSlice());
        },
        .text => {
            try output.append_text(result);
        },
        else => {},
    };
}

pub fn update_memory(
    output: *Output,
    result: *std.ArrayList(u8),
    timestamps: *Timestamps,
    interval: u64,
)
! void {
    const memory: modules.Memory = try .init();
    try result.appendSlice("󰍛 ");

    const update_needed = timestamps.is_update_needed(
        interval, "memory"
    );

    const config = output.config;
    for (config.memory_list.items) |arg| switch (arg) {
        .used => {
            if (update_needed) {
                output.memory_used.clear();
                const used = memory.get_used();
                try fmt.memory(output.memory_used.writer(), used);
            }
            const array = output.memory_used;
            try result.appendSlice(array.constSlice());
        },
        .total => {
            if (update_needed) {
                output.memory_total.clear();
                try fmt.memory(output.memory_total.writer(), memory.total);
            }
            const array = output.memory_total;
            try result.appendSlice(array.constSlice());
        },
        .text => {
            try output.append_text(result);
        },
        else => {},
    };
}

pub fn update_cpu(
    output: *Output,
    result: *std.ArrayList(u8),
    timestamps: *Timestamps,
    interval: u64,
    cpu: *modules.Cpu,
    threads: f32,
)
! void {
    try result.appendSlice("󰘚 ");

    const update_needed = timestamps.is_update_needed(
        interval, "cpu"
    );

    if (update_needed) try cpu.update(threads);

    const config = output.config;
    for (config.cpu_list.items) |arg| switch (arg) {
        .uptime => {
            if (update_needed) {
                output.uptime.clear();
                try fmt.time(output.uptime.writer(), cpu.system_up);
            }
            const array = output.uptime;
            try result.appendSlice(array.constSlice());
        },
        .used_percent => {
            if (update_needed) {
                output.cpu_usage.clear();
                try fmt.percent(output.cpu_usage.writer(), cpu.percent);
            }
            const array = output.cpu_usage;
            try result.appendSlice(array.constSlice());
        },
        .text => {
            try output.append_text(result);
        },
        else => {},
    };
}

pub fn update_time(
    output: *Output,
    result: *std.ArrayList(u8),
    local: zeit.TimeZone,
)
! void {
    try result.appendSlice("󰃰 ");

    const config = output.config;
    const time_fmt = config.str_list.items[output.text_index].constSlice();
    output.text_index += 1;

    const now = try zeit.instant(.{});
    const now_local = now.in(&local);
    const dt = now_local.time();

    output.time.clear();
    try dt.strftime(output.time.writer(), time_fmt);

    try result.appendSlice(output.time.constSlice());
}

inline fn append_text(output: *Output, result: *std.ArrayList(u8))
! void {
    const config = output.config;
    const array = config.str_list.items[output.text_index];
    try result.appendSlice(array.constSlice());
    output.text_index += 1;
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
