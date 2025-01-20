//! This structure is used to store the timestamps of when the last time each
//! module was ran. This is used to check when it is necessary to update a
//! module.

const std = @import("std");
const Timestamps = @This();

backlight: i128,
battery:   i128,
cpu:       i128,
memory:    i128,
time:      i128,

/// This structure is used to check if the timestamps are defined. If they’re
/// not, that means that we’re on the first update interval so we must
/// initialize the timestamp.
pub const Defined = struct {
    timestamps: u8 = 0,

    //= Wrappers for bitwise arithmetic.
    pub inline fn set(defined: *Defined, flags: Flags) void {
        defined.timestamps |= @intFromEnum(flags);
    }

    pub inline fn isDefined(defined: Defined, flags: Flags) bool {
        return defined.timestamps & @intFromEnum(flags) != 0;
    }

    const Flags = enum(u8) {
        backlight = 1 << 0,
        battery   = 1 << 1,
        cpu       = 1 << 2,
        memory    = 1 << 3,
        time      = 1 << 4,
    };
};

/// An update is needed if the given timestamp is undefined or we have reached
/// or passed the update interval.
pub fn isUpdateNeeded(
    timestamps_ptr: *Timestamps,
    defined_ptr: *Defined,
    interval: u64,
    comptime field: []const u8,
) bool {
    const is_defined = defined_ptr.isDefined(@field(Defined.Flags, field));

    const timestamp_old = @field(timestamps_ptr, field);
    const timestamp_new = std.time.nanoTimestamp();

    if (is_defined) {
        if (timestamp_new - timestamp_old >= interval) {
            @field(timestamps_ptr, field) = timestamp_new;
            return true;
        }
        return false;
    }

    defined_ptr.set(@field(Defined.Flags, field));
    @field(timestamps_ptr, field) = timestamp_new;
    return true;
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
