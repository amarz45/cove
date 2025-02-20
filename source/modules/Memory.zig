const std = @import("std");
const Memory = @This();

total:   f32,
free:    f32,
buffers: f32,
cached:  f32,

pub fn init() !Memory {
    return .{
        .total   = try get_entry("Total:"),
        .free    = try get_entry("Free:"),
        .buffers = try get_entry("Buffers:"),
        .cached  = try get_entry("Cached:"),
    };
}

pub fn get_used(memory: *const Memory) f32 {
    @setFloatMode(.optimized);
    return memory.total - memory.free - memory.buffers - memory.cached;
}

// Get an entry from `/proc/meminfo`. This is very inefficient because we are
// re-reading the file for each entry, but I plan to use syscalls for most
// memory information in the future.
fn get_entry(comptime entry: []const u8) !f32 {
    var file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf: [256]u8 = undefined;
    const close_index = try file.pread(&buf, 0);
    const slice = buf[0..close_index];

    const slice_index = std.mem.indexOf(u8, slice, entry) orelse
        @panic("/proc/meminfo: entry ‘"++entry++"’ not found.");

    const slice_no_entry = buf[(slice_index + entry.len)..];
    const slice_no_spaces = std.mem.trimLeft(u8, slice_no_entry, " ");
    const unit_index = std.mem.indexOfScalar(u8, slice_no_spaces, 'k') orelse
        @panic("/proc/meminfo: unit not found for entry ‘"++entry++"’.");
    const slice_num = slice_no_spaces[0..(unit_index - 1)];

    return std.fmt.parseFloat(f32, slice_num);
}

const expect = std.testing.expect;

test "memory" {
    const memory: Memory = try .init();

    try expect(memory.total >= 0);
    try expect(memory.free >= 0);
    try expect(memory.buffers >= 0);
    try expect(memory.cached >= 0);
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
