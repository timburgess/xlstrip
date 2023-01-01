const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();


    // const lib = try libxml2.create(b, target, mode, .{
    //     // These are the minimal options to NOT depend on any other libraries.
    //     // If you have these libraries, just set these to true.
    //     .iconv = false,
    //     .lzma = false,
    //     .zlib = false,
    // });

    const exe = b.addExecutable("xmlparser", "src/main.zig");

    exe.addIncludePath("/usr/include/libxml2");

    // link against libc & libxml2
    exe.linkLibC();
    exe.linkSystemLibrary("xml2");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // test code
    const exe_tests = b.addTest("src/main.zig");
    exe_tests.linkLibC();
    exe_tests.addIncludePath("/usr/include/libxml2");
    exe_tests.linkSystemLibrary("xml2");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
