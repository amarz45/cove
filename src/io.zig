const std = @import("std");
const Dir = std.fs.Dir;

pub fn readLineFile(buf: []u8, dir: Dir, filename: []const u8) ![]const u8 {
    var file = try dir.openFile(filename, .{});
    defer file.close();

    var end_index = try file.pread(buf, 0) - 1;
    if (buf[end_index] != '\n') end_index += 1;

    return buf[0..end_index];
}

pub fn readFirstChar(buf: []u8, dir: Dir, filename: []const u8) !u8 {
    var file = try dir.openFile(filename, .{});
    defer file.close();

    _ = try file.pread(buf, 0);

    return buf[0];
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
