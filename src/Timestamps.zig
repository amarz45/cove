//! This structure is used to store the timestamps of when the last time each
//! module was ran. This is used to check when it is necessary to update a
//! module.

const std = @import("std");
const Timestamps = @This();

backlight: ?i128 = null,
battery:   ?i128 = null,
cpu:       ?i128 = null,
memory:    ?i128 = null,
time:      ?i128 = null,

/// An update is needed if the given timestamp is null or we have reached or
/// passed the update interval.
pub fn isUpdateNeeded(
    timestamps_ptr: *Timestamps,
    interval: u64,
    comptime field: []const u8,
) bool {
    const timestamp_new = std.time.nanoTimestamp();
    if (@field(timestamps_ptr, field)) |timestamp_old| {
        if (timestamp_new - timestamp_old >= interval) {
            @branchHint(.unlikely);
            @field(timestamps_ptr, field) = timestamp_new;
            return true;
        } else {
            @branchHint(.likely);
            return false;
        }
    } else {
        @branchHint(.cold);
        @field(timestamps_ptr, field) = timestamp_new;
        return true;
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
