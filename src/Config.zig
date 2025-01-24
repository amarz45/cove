const std = @import("std");
const c = @cImport({
    @cInclude("scfg.h");
});
const Config = @This();

const stderr = std.io.getStdErr().writer();
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

module_list:    ModuleList,
text_list:      VariableList,
backlight_list: VariableList,
battery_list:   VariableList,
cpu_list:       VariableList,
drive_list:     VariableList,
memory_list:    VariableList,
time_list:      VariableList,
str_list:       StrList,

const ModuleList = std.ArrayList(Module);
const VariableList = std.ArrayList(Variable);
const StrList = std.ArrayList(std.BoundedArray(u8, 32));

pub const Module = enum(u8) {
    separator,
    text,
    backlight,
    battery,
    cpu,
    memory,
    time,
};

pub const Variable = enum(u8) {
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
};

pub const ModuleIntervals = struct {
    backlight: u64,
    battery:   u64,
    cpu:       u64,
    memory:    u64,
    time:      u64,
};

pub const ModulesUsed = packed struct {
    backlight: bool = false,
    cpu:       bool = false,
    time:      bool = false,
};

pub fn parseConfig(
    config_ptr: *Config,
    module_intervals_ptr: *ModuleIntervals,
) !ModulesUsed {
    const cfg_file = "/home/amaral/.config/cove/cove.scfg";
    const file = c.fopen(cfg_file, "r");
    defer _ = c.fclose(file);

    var cfg = c.scfg_block{};
    defer c.scfg_block_finish(&cfg);

    _ = c.scfg_parse_file(&cfg, file);

    const output = cfg.directives[0].children;
    const directives_len = output.directives_len;
    try config_ptr.module_list.ensureTotalCapacityPrecise(directives_len);

    var modules_used: ModulesUsed = .{};

    {var i: usize = 0; while (i < directives_len) : (i += 1) {
        try parseModule(
            config_ptr, &output.directives[i], &modules_used,
            module_intervals_ptr
        );
    }}

    return modules_used;
}

fn parseModule(
    config_ptr: *Config,
    module_cfg: *allowzero c.scfg_directive,
    modules_used_ptr: *ModulesUsed,
    module_intervals_ptr: *ModuleIntervals,
) !void {
    const name = std.mem.span(module_cfg.name);
    const params_len = module_cfg.params_len;

    if (std.mem.eql(u8, name, "separator")) {
        if (params_len != 0) {
            _  = try stderr.write(
                "Error: The separator module does not take any parameters\n"
            );
            std.process.exit(1);
        }
        config_ptr.module_list.appendAssumeCapacity(.separator);
        return;
    }

    if (params_len == 0) {
        _ = try stderr.write("Error: you must give at least one parameter.\n");
        std.process.exit(1);
    }

    if (std.mem.eql(u8, name, "text")) {
        config_ptr.module_list.appendAssumeCapacity(.text);
        try config_ptr.str_list.append(try .fromSlice("Example"));
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

        interval = try toNanoseconds(num, unit);
        break :param std.mem.span(module_cfg.params[3]);
    };

    if (std.mem.eql(u8, name, "backlight")) {
        try parseParamGeneric(
            config_ptr, module_intervals_ptr, interval, param, "backlight"
        );
        modules_used_ptr.backlight = true;
    } else if (std.mem.eql(u8, name, "cpu")) {
        try parseParamGeneric(
            config_ptr, module_intervals_ptr, interval, param, "cpu"
        );
        modules_used_ptr.cpu = true;
    } else if (std.mem.eql(u8, name, "time")) {
        try parseParamGeneric(
            config_ptr, module_intervals_ptr, interval, param, "time"
        );
        modules_used_ptr.time = true;
    } else if (std.mem.eql(u8, name, "battery")) {
        try parseParamGeneric(
            config_ptr, module_intervals_ptr, interval, param, "battery"
        );
    } else if (std.mem.eql(u8, name, "memory")) {
        try parseParamGeneric(
            config_ptr, module_intervals_ptr, interval, param, "memory"
        );
    } else {
        try stderr.print("Error: invalid module {s}.\n", .{name});
        std.process.exit(1);
    }
}

fn parseParamGeneric(
    config_ptr: *Config,
    module_intervals_ptr: *ModuleIntervals,
    interval: u64,
    param: []const u8,
    comptime field: []const u8,
) !void {
    @field(module_intervals_ptr, field) = interval;
    config_ptr.module_list.appendAssumeCapacity(@field(Module, field));
    try parseParam(
        &@field(config_ptr, field++"_list"), &config_ptr.str_list, param
    );
}

/// This function tokenizes a given parameter and updates the respective lookup
/// tables. An example of a parameter would be `{used} / {total}` for memory. It
/// Should be split into the tokens `used`, `text`, `total`; and the `str_list`
/// array should have the string ` / ` appended to it.
fn parseParam(
    variable_list: *VariableList,
    str_list: *StrList,
    _param: []const u8,
) !void {
    var param = _param;
    if (std.mem.indexOfScalar(u8, param, '{')) |open_i| {
        if (open_i != 0) {
            try variable_list.append(.text);
            try str_list.append(try .fromSlice(param[0..open_i]));
        }

        while (std.mem.indexOfScalar(u8, param, '}')) |close_i| {
            const arg = param[(open_i + 1)..close_i];
            try variable_list.append(try varFromStr(arg));

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

test parseParam {
    const allocator = std.testing.allocator;

    var variable_list: VariableList = .init(allocator);
    var str_list: StrList = .init(allocator);
    defer {
        variable_list.deinit();
        str_list.deinit();
    }

    try parseParam(&variable_list, &str_list, "{used} / {total}");
    try expectEqual(variable_list.items.len, 3);
    try expectEqual(variable_list.items[0], .used);
    try expectEqual(variable_list.items[1], .text);
    try expectEqual(variable_list.items[2], .total);
    try expectEqual(str_list.items.len, 1);
    try expectEqualStrings(str_list.items[0].slice(), " / ");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parseParam(&variable_list, &str_list, "{used}{total}");
    try expectEqual(variable_list.items.len, 2);
    try expectEqual(variable_list.items[0], .used);
    try expectEqual(variable_list.items[1], .total);
    try expectEqual(str_list.items.len, 0);

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parseParam(&variable_list, &str_list, "Battery: {remaining%}");
    try expectEqual(variable_list.items.len, 2);
    try expectEqual(variable_list.items[0], .text);
    try expectEqual(variable_list.items[1], .remaining_percent);
    try expectEqual(str_list.items.len, 1);
    try expectEqualStrings(str_list.items[0].slice(), "Battery: ");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parseParam(&variable_list, &str_list, "{remaining%} battery");
    try expectEqual(variable_list.items.len, 2);
    try expectEqual(variable_list.items[0], .remaining_percent);
    try expectEqual(variable_list.items[1], .text);
    try expectEqual(str_list.items.len, 1);
    try expectEqualStrings(str_list.items[0].slice(), " battery");

    variable_list.clearRetainingCapacity();
    str_list.clearRetainingCapacity();

    try parseParam(&variable_list, &str_list, "lorem ipsum");
    try expectEqual(variable_list.items.len, 1);
    try expectEqual(variable_list.items[0], .text);
    try expectEqual(str_list.items.len, 1);
    try expectEqualStrings(str_list.items[0].slice(), "lorem ipsum");
}

fn varFromStr(str: []const u8) !Variable {
    return if (std.mem.eql(u8, str, "brightness%"))
        .percent
    else if (std.mem.eql(u8, str, "remaining"))
        .remaining
    else if (std.mem.eql(u8, str, "remaining%"))
        .remaining_percent
    else if (std.mem.eql(u8, str, "status"))
        .status
    else if (std.mem.eql(u8, str, "time_remaining"))
        .time_remaining
    else if (std.mem.eql(u8, str, "total"))
        .total
    else if (std.mem.eql(u8, str, "uptime"))
        .uptime
    else if (std.mem.eql(u8, str, "used"))
        .used
    else if (std.mem.eql(u8, str, "used%"))
        .used_percent
    else {
        try stderr.print("Error: invalid variable ‘{s}’.\n", .{str});
        std.process.exit(1);
    };
}

fn toNanoseconds(num: u64, unit: []const u8) !u64 {
    return if (std.mem.eql(u8, unit, "s"))
        num * 1_000_000_000
    else if (std.mem.eql(u8, unit, "ms"))
        num * 1_000_000
    else if (std.mem.eql(u8, unit, "us"))
        num * 1000
    else if (std.mem.eql(u8, unit, "ns"))
        num
    else {
        try stderr.print("Error: invalid unit ‘{s}’\n", .{unit});
        std.process.exit(1);
    };
}

test toNanoseconds {
    try expectEqual(toNanoseconds(1, "s"), 1_000_000_000);
    try expectEqual(toNanoseconds(1, "ms"), 1_000_000);
    try expectEqual(toNanoseconds(1, "us"), 1000);
    try expectEqual(toNanoseconds(1, "ns"), 1);

    try expectEqual(toNanoseconds(0, "s"), 0);
    try expectEqual(toNanoseconds(0, "ms"), 0);
    try expectEqual(toNanoseconds(0, "us"), 0);
    try expectEqual(toNanoseconds(0, "ns"), 0);

    try expectEqual(toNanoseconds(9, "s"), 9_000_000_000);
    try expectEqual(toNanoseconds(99, "ms"), 99_000_000);
    try expectEqual(toNanoseconds(999, "us"), 999_000);
    try expectEqual(toNanoseconds(9999, "ns"), 9999);
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
