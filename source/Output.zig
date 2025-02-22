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
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    module: Config.Module,
    module_intervals_ptr: *Config.Module_intervals,
    timestamps_ptr: *Timestamps,
    cpu_data_ptr: *modules.Cpu,
    threads: f32,
    backlight_dir_name: []const u8,
    local: zeit.TimeZone,
) !void {
    switch (module) {
        .separator => {
            try result_ptr.appendSlice(markup.separator);
        },
        .text => {
            try output_ptr.update_text(result_ptr);
        },
        .backlight => {
            try output_ptr.update_backlight(
                result_ptr, timestamps_ptr, module_intervals_ptr.backlight,
                backlight_dir_name
            );
        },
        .battery => {
            try output_ptr.update_battery(
                result_ptr, timestamps_ptr, module_intervals_ptr.battery
            );
        },
        .cpu => {
            try output_ptr.update_cpu(
                result_ptr, timestamps_ptr, module_intervals_ptr.cpu,
                cpu_data_ptr, threads
            );
        },
        .memory => {
            try output_ptr.update_memory(
                result_ptr, timestamps_ptr, module_intervals_ptr.memory
            );
        },
        .time => {
            try output_ptr.update_time(result_ptr, local);
        },
    }
}

pub fn update_text(output_ptr: *Output, result_ptr: *std.ArrayList(u8)) !void {
    const config = output_ptr.config;
    for (config.text_list.items) |arg| switch (arg) {
        .text => {
            const array = config.str_list.items[output_ptr.text_index];
            try result_ptr.appendSlice(array.constSlice());
            output_ptr.text_index += 1;
        },
        else => {},
    };
}

pub fn update_backlight(
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    timestamps_ptr: *Timestamps,
    interval: u64,
    dir_name: []const u8,
) !void {
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

    try result_ptr.appendSlice(prefix);

    const update_needed = timestamps_ptr.is_update_needed(
        interval, "backlight"
    );

    const config = output_ptr.config;
    for (config.backlight_list.items) |arg| switch (arg) {
        .percent => {
            if (update_needed) {
                output_ptr.backlight_percent.clear();
                const writer = output_ptr.backlight_percent.writer();
                try fmt.percent(writer, backlight.percent);
            }
            const array = output_ptr.backlight_percent;
            try result_ptr.appendSlice(array.constSlice());
        },
        .text => {
            const array = config.str_list.items[output_ptr.text_index];
            try result_ptr.appendSlice(array.constSlice());
            output_ptr.text_index += 1;
        },
        else => {},
    };
}

pub fn update_battery(
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    timestamps_ptr: *Timestamps,
    interval: u64,
) !void {
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

    try result_ptr.appendSlice(prefix);

    const update_needed = timestamps_ptr.is_update_needed(
        interval, "battery"
    );

    const config = output_ptr.config;
    for (config.battery_list.items) |arg| switch (arg) {
        .remaining_percent => {
            if (update_needed) {
                output_ptr.battery_capacity.clear();
                const writer = output_ptr.battery_capacity.writer();
                try fmt.percent(writer, battery.capacity);
            }
            const array = output_ptr.battery_capacity;
            try result_ptr.appendSlice(array.constSlice());
        },
        .status => {
            if (update_needed) {
                const status = switch (battery.status) {
                    .charging     => "Charging",
                    .discharging  => "Discharging",
                    .not_charging => "Not charging",
                    else          => "Unknown",
                };
                output_ptr.battery_status.clear();
                const writer = output_ptr.battery_status.writer();
                _ = try writer.write(status);
            }
            const array = output_ptr.battery_status;
            try result_ptr.appendSlice(array.constSlice());
        },
        .time_remaining => {
            if (update_needed) {
                output_ptr.battery_time_remaining.clear();
                const writer = output_ptr.battery_time_remaining.writer();
                try battery.get_time_remaining(writer);
            }
            try result_ptr.appendSlice(output_ptr.battery_time_remaining.constSlice());
        },
        .text => {
            const slice = config.str_list.items[output_ptr.text_index].constSlice();
            try result_ptr.appendSlice(slice);
            output_ptr.text_index += 1;
        },
        else => {},
    };
}

pub fn update_memory(
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    timestamps_ptr: *Timestamps,
    interval: u64,
) !void {
    const memory: modules.Memory = try .init();
    try result_ptr.appendSlice("󰍛 ");

    const update_needed = timestamps_ptr.is_update_needed(
        interval, "memory"
    );

    const config = output_ptr.config;
    for (config.memory_list.items) |arg| switch (arg) {
        .used => {
            if (update_needed) {
                output_ptr.memory_used.clear();
                const used = memory.get_used();
                try fmt.memory(output_ptr.memory_used.writer(), used);
            }
            try result_ptr.appendSlice(output_ptr.memory_used.constSlice());
        },
        .total => {
            if (update_needed) {
                output_ptr.memory_total.clear();
                try fmt.memory(output_ptr.memory_total.writer(), memory.total);
            }
            try result_ptr.appendSlice(output_ptr.memory_total.constSlice());
        },
        .text => {
            const slice = config.str_list.items[output_ptr.text_index].constSlice();
            try result_ptr.appendSlice(slice);
            output_ptr.text_index += 1;
        },
        else => {},
    };
}

pub fn update_cpu(
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    timestamps_ptr: *Timestamps,
    interval: u64,
    cpu: *modules.Cpu,
    threads: f32,
) !void {
    try result_ptr.appendSlice("󰘚 ");

    const update_needed = timestamps_ptr.is_update_needed(
        interval, "cpu"
    );

    if (update_needed) try cpu.update(threads);

    const config = output_ptr.config;
    for (config.cpu_list.items) |arg| switch (arg) {
        .uptime => {
            if (update_needed) {
                output_ptr.uptime.clear();
                try fmt.time(output_ptr.uptime.writer(), cpu.system_up);
            }
            try result_ptr.appendSlice(output_ptr.uptime.constSlice());
        },
        .used_percent => {
            if (update_needed) {
                output_ptr.cpu_usage.clear();
                try fmt.percent(output_ptr.cpu_usage.writer(), cpu.percent);
            }
            try result_ptr.appendSlice(output_ptr.cpu_usage.constSlice());
        },
        .text => {
            const slice = config.str_list.items[output_ptr.text_index].constSlice();
            try result_ptr.appendSlice(slice);
            output_ptr.text_index += 1;
        },
        else => {},
    };
}

pub fn update_time(
    output_ptr: *Output,
    result_ptr: *std.ArrayList(u8),
    local: zeit.TimeZone,
) !void {
    try result_ptr.appendSlice("󰃰 ");

    const time_fmt = output_ptr.config.str_list.items[output_ptr.text_index].constSlice();
    output_ptr.text_index += 1;

    const now = try zeit.instant(.{});
    const now_local = now.in(&local);
    const dt = now_local.time();

    output_ptr.time.clear();
    try dt.strftime(output_ptr.time.writer(), time_fmt);

    try result_ptr.appendSlice(output_ptr.time.constSlice());
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
