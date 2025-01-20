const std = @import("std");

pub const percent_len = "100 %".len;
pub const memory_len = "1024 KiB".len;

pub inline fn percent(writer: anytype, _percent: anytype) !void {
    try writer.print("{d:.0} %", .{_percent});
}

// Given a buffer and the memory amount in kibibytes, write to the buffer a
// string with the amount in a human-readable format with the appropriate unit.
pub fn memory(writer: anytype, _mem: f32) !void {
    @setFloatMode(.optimized);
    var mem = _mem;

    const unit = unit: {
        if (mem < 1 << 10) {
            break :unit "KiB";
        } if (mem < 1 << 20) {
            mem /= 1 << 10;
            break :unit "MiB";
        } if (mem < 1 << 30) {
            mem /= 1 << 20;
            break :unit "GiB";
        }
        mem /= 1 << 30;
        break :unit "TiB";
    };

    if (mem < 10) {
        try writer.print("{d:.2} {s}", .{mem, unit});
    } else if (mem < 100) {
        try writer.print("{d:.1} {s}", .{mem, unit});
    } else {
        try writer.print("{d:.0} {s}", .{mem, unit});
    }
}

const expectEqualStrings = std.testing.expectEqualStrings;

//test "percent" {
    //try expectEqualStrings((try percent(0)).slice(),     "0 %");
    //try expectEqualStrings((try percent(0.0)).slice(),   "0 %");
    //try expectEqualStrings((try percent(10)).slice(),    "10 %");
    //try expectEqualStrings((try percent(10.0)).slice(),  "10 %");
    //try expectEqualStrings((try percent(100)).slice(),   "100 %");
    //try expectEqualStrings((try percent(100.0)).slice(), "100 %");
//}

//test "memory" {
    //try expectEqualStrings((try memory(0)).slice(),    "0.00 KiB");
    //try expectEqualStrings((try memory(9)).slice(),    "9.00 KiB");
    //try expectEqualStrings((try memory(10)).slice(),   "10.0 KiB");
    //try expectEqualStrings((try memory(99)).slice(),   "99.0 KiB");
    //try expectEqualStrings((try memory(100)).slice(),  "100 KiB");
    //try expectEqualStrings((try memory(1000)).slice(), "1000 KiB");
    //try expectEqualStrings((try memory(1023)).slice(), "1023 KiB");
//
    //try expectEqualStrings((try memory(1 << 10)).slice(), "1.00 MiB");
    //try expectEqualStrings((try memory(1 << 20)).slice(), "1.00 GiB");
    //try expectEqualStrings((try memory(1 << 30)).slice(), "1.00 TiB");
//}

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
