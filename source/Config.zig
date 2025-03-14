const std = @import("std");
const testing = @import("testing.zig");
const c = @cImport({
    @cInclude("scfg.h");
});
const Config = @This();

const stderr = std.io.getStdErr().writer();
const expect_eql = testing.expect_eql; 
const expect_eql_str = testing.expect_eql_str;

module_list:    Module_list,
text_list:      Variable_list,
backlight_list: Variable_list,
battery_list:   Variable_list,
cpu_list:       Variable_list,
drive_list:     Variable_list,
memory_list:    Variable_list,
time_list:      Variable_list,
str_list:       Str_list,

const Module_list = std.ArrayList(Module);
const Variable_list = std.ArrayList(Variable);
const Str_list = std.ArrayList(std.BoundedArray(u8, 32));

pub const Module = enum(u8) {
    separator,
    text,
    backlight,
    battery,
    cpu,
    memory,
    time,
};

pub const Variable = enum {
    text,
    percent,
    remaining,
    remaining_percent,
    status,
    time_remaining,
    total,
    uptime,
    used,
    used_percent,

    const hashmap: std.StaticStringMap(Variable) = .initComptime(.{
        .{"brightness%",    .percent          },
        .{"remaining",      .remaining        },
        .{"remaining%",     .remaining_percent},
        .{"status",         .status           },
        .{"time_remaining", .time_remaining   },
        .{"total",          .total            },
        .{"uptime",         .uptime           },
        .{"used",           .used             },
        .{"used%",          .used_percent     },
    });

    fn get(str: []const u8) ! Variable {
        return hashmap.get(str) orelse {
            try stderr.print("Error: invalid variable ‘{s}’.\n", .{str});
            std.process.exit(1);
        };
    }
};

pub const Module_intervals = struct {
    backlight: u64,
    battery:   u64,
    cpu:       u64,
    memory:    u64,
    time:      u64,
};

pub const Modules_used = packed struct {
    backlight: bool = false,
    battery:   bool = false,
    cpu:       bool = false,
    memory:    bool = false,
    time:      bool = false,
};

pub fn init(allocator: std.mem.Allocator) Config {
    return .{
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
}

pub fn parse_config(
    config: *Config,
    module_intervals: *Module_intervals
)
! Modules_used {
    const xdg_config_home = std.posix.getenv("XDG_CONFIG_HOME");
    const config_dir = xdg_config_home orelse b: {
        var buf: [64]u8 = undefined;
        const home = std.posix.getenv("HOME") orelse {
            try stderr.writeAll("Home directory not found!\n");
            std.process.exit(1);
        };
        break :b try std.fmt.bufPrint(&buf, "{s}/.config", .{home});
    };

    var config_file_buf: [64]u8 = undefined;
    const config_file = try std.fmt.bufPrint(
        &config_file_buf, "{s}/cove/cove.scfg", .{config_dir}
    );

    var fba_buf: [64]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&fba_buf);
    const allocator = fba.allocator();

    const config_file_c = try allocator.dupeZ(u8, config_file);
    defer allocator.free(config_file_c);

    const file = c.fopen(config_file_c, "r") orelse {
        try stderr.print(
            "Error: Configuration file not found at ‘{s}’.\n", .{config_file}
        );
        std.process.exit(1);
    };
    defer _ = c.fclose(file);

    var cfg = c.scfg_block{};
    defer c.scfg_block_finish(&cfg);

    _ = c.scfg_parse_file(&cfg, file);

    const output = cfg.directives[0].children;
    const directives_len = output.directives_len;
    try config.module_list.ensureTotalCapacityPrecise(directives_len);

    var modules_used: Modules_used = .{};

    for (0..directives_len) |i| {
        try parse_module(
            config, &output.directives[i], &modules_used,
            module_intervals
        );
    }

    return modules_used;
}

fn parse_module(
    config: *Config,
    module_cfg: *allowzero c.scfg_directive,
    modules_used: *Modules_used,
    module_intervals: *Module_intervals,
)
! void {
    const name = std.mem.span(module_cfg.name);
    const params_len = module_cfg.params_len;

    if (std.mem.eql(u8, name, "separator")) {
        if (params_len != 0) {
            _  = try stderr.write(
                "Error: The separator module does not take any parameters\n"
            );
            std.process.exit(1);
        }
        config.module_list.appendAssumeCapacity(.separator);
        return;
    }

    if (params_len == 0) {
        _ = try stderr.write("Error: you must give at least one parameter.\n");
        std.process.exit(1);
    }

    if (std.mem.eql(u8, name, "text")) {
        config.module_list.appendAssumeCapacity(.text);
        try config.str_list.append(try .fromSlice("Example"));
        return;
    }

    var interval: u64 = std.time.ns_per_s;
    const param = param: {
        const param_0 = std.mem.span(module_cfg.params[0]);

        if (param_0[0] != '-') break :param param_0;

        if (!std.mem.eql(u8, param_0[1..], "interval")) {
            try stderr.print("Error: invalid parameter ‘{s}’\n", .{param_0});
            std.process.exit(1);
        }

        if (params_len < 4) {
            _ = try stderr.write(
                "Error: parameter ‘interval’ must take two arguments\n"
            );
            std.process.exit(1);
        }

        const num_str = std.mem.span(module_cfg.params[1]);
        const num = try std.fmt.parseUnsigned(u64, num_str, 10);
        const unit = std.mem.span(module_cfg.params[2]);

        interval = try to_nanoseconds(num, unit);
        break :param std.mem.span(module_cfg.params[3]);
    };

    if (std.mem.eql(u8, name, "backlight")) {
        try parse_param(
            config, module_intervals, interval, param, "backlight"
        );
        modules_used.backlight = true;
    }
    else if (std.mem.eql(u8, name, "cpu")) {
        try parse_param(
            config, module_intervals, interval, param, "cpu"
        );
        modules_used.cpu = true;
    }
    else if (std.mem.eql(u8, name, "time")) {
        try parse_param(
            config, module_intervals, interval, param, "time"
        );
        modules_used.time = true;
    }
    else if (std.mem.eql(u8, name, "battery")) {
        try parse_param(
            config, module_intervals, interval, param, "battery"
        );
        modules_used.battery = true;
    }
    else if (std.mem.eql(u8, name, "memory")) {
        try parse_param(
            config, module_intervals, interval, param, "memory"
        );
        modules_used.memory = true;
    }
    else {
        try stderr.print("Error: invalid module {s}.\n", .{name});
        std.process.exit(1);
    }
}

fn parse_param(
    config: *Config,
    module_intervals: *Module_intervals,
    interval: u64,
    param: []const u8,
    comptime field: []const u8,
)
! void {
    @field(module_intervals, field) = interval;
    config.module_list.appendAssumeCapacity(@field(Module, field));
    try _parse_param(
        &@field(config, field++"_list"), &config.str_list, param
    );
}

/// This function tokenizes a given parameter and updates the respective lookup
/// tables. An example of a parameter would be `{used} / {total}` for memory. It
/// Should be split into the tokens `used`, `text`, `total`; and the `str_list`
/// array should have the string ` / ` appended to it.
fn _parse_param(
    variable_list: *Variable_list,
    str_list: *Str_list,
    _param: []const u8,
)
! void {
    var param = _param;
    if (std.mem.indexOfScalar(u8, param, '{')) |open_i| {
        if (open_i != 0) {
            try variable_list.append(.text);
            try str_list.append(try .fromSlice(param[0..open_i]));
        }

        while (std.mem.indexOfScalar(u8, param, '}')) |close_i| {
            const arg = param[(open_i + 1)..close_i];
            try variable_list.append(try Variable.get(arg));

            param = param[(close_i + 1)..];
            if (std.mem.indexOfScalar(u8, param, '{')) |next_open_i| {
                if (next_open_i != 0) {
                    //= Only add to the list if the string is not empty.
                    try variable_list.append(.text);
                    const slice = param[0..next_open_i];
                    try str_list.append(try .fromSlice(slice));
                    param = param[next_open_i..];
                }
            } else {
                //= No additional open index: The rest of the string is plain
                //= text.
                if (param.len != 0) {
                    try variable_list.append(.text);
                    try str_list.append(try .fromSlice(param));
                }
                break;
            }
        }
    } else {
        //= No open index: The entire string is plain text.
        try variable_list.append(.text);
        try str_list.append(try .fromSlice(param));
    }
}

test parse_param {
    const allocator = std.testing.allocator;

    var variable_list: Variable_list = .init(allocator);
    var str_list: Str_list = .init(allocator);
    defer {
        variable_list.deinit();
        str_list.deinit();
    }

    try parse_param(&variable_list, &str_list, "{used} / {total}");
    try expect_eql(variable_list.items.len, 3);
    try expect_eql(variable_list.items[0], .used);
    try expect_eql(variable_list.items[1], .text);
    try expect_eql(variable_list.items[2], .total);
    try expect_eql(str_list.items.len, 1);
    try expect_eql_str(str_list.items[0].slice(), " / ");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parse_param(&variable_list, &str_list, "{used}{total}");
    try expect_eql(variable_list.items.len, 2);
    try expect_eql(variable_list.items[0], .used);
    try expect_eql(variable_list.items[1], .total);
    try expect_eql(str_list.items.len, 0);

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parse_param(&variable_list, &str_list, "Battery: {remaining%}");
    try expect_eql(variable_list.items.len, 2);
    try expect_eql(variable_list.items[0], .text);
    try expect_eql(variable_list.items[1], .remaining_percent);
    try expect_eql(str_list.items.len, 1);
    try expect_eql_str(str_list.items[0].slice(), "Battery: ");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parse_param(&variable_list, &str_list, "{remaining%} battery");
    try expect_eql(variable_list.items.len, 2);
    try expect_eql(variable_list.items[0], .remaining_percent);
    try expect_eql(variable_list.items[1], .text);
    try expect_eql(str_list.items.len, 1);
    try expect_eql_str(str_list.items[0].slice(), " battery");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parse_param(&variable_list, &str_list, "lorem ipsum");
    try expect_eql(variable_list.items.len, 1);
    try expect_eql(variable_list.items[0], .text);
    try expect_eql(str_list.items.len, 1);
    try expect_eql_str(str_list.items[0].slice(), "lorem ipsum");
}

fn to_nanoseconds(num: u64, unit: []const u8) ! u64 {
    return if (std.mem.eql(u8, unit, "s"))
        num * 1_000_000_000
    else if (std.mem.eql(u8, unit, "ms"))
        num * 1_000_000
    else if (std.mem.eql(u8, unit, "us")) blk: {
        @branchHint(.unlikely);
        break :blk num * 1000;
    } else if (std.mem.eql(u8, unit, "ns")) blk: {
        @branchHint(.cold);
        break :blk num;
    } else {
        @branchHint(.cold);
        try stderr.print("Error: invalid unit ‘{s}’\n", .{unit});
        std.process.exit(1);
    };
}

test to_nanoseconds {
    try expect_eql(to_nanoseconds(1, "s"), 1_000_000_000);
    try expect_eql(to_nanoseconds(1, "ms"), 1_000_000);
    try expect_eql(to_nanoseconds(1, "us"), 1000);
    try expect_eql(to_nanoseconds(1, "ns"), 1);

    try expect_eql(to_nanoseconds(0, "s"), 0);
    try expect_eql(to_nanoseconds(0, "ms"), 0);
    try expect_eql(to_nanoseconds(0, "us"), 0);
    try expect_eql(to_nanoseconds(0, "ns"), 0);

    try expect_eql(to_nanoseconds(9, "s"), 9_000_000_000);
    try expect_eql(to_nanoseconds(99, "ms"), 99_000_000);
    try expect_eql(to_nanoseconds(999, "us"), 999_000);
    try expect_eql(to_nanoseconds(9999, "ns"), 9999);
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
