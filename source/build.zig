const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cove",
        .root_source_file = b.path("cove.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zeit = b.dependency("zeit", .{
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("scfg");

    exe.root_module.addImport("zeit", zeit.module("zeit"));

    const tests = b.addTest(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    b.installArtifact(exe);
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
// -------------------------------------------------------------------------- //
