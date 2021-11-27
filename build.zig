const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    b.installBinFile("deps/lib/glfw3.dll", "glfw3.dll");


    const exe = b.addExecutable("musileko", "src/main.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludeDir("deps/inc");
    // exe.addIncludeDir("C:/Users/sam/zig-windows-x86_64-0.8.0/lib/libc/include/any-windows-any");
    // exe.addIncludeDir("C:/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.11.25503/include");
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("deps/src/stb_image.c", &[_][]const u8{"-std=c99"});
    // exe.addIncludeDir("GLFW/include/GLFW");
    exe.addLibPath("deps/lib");
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("opengl32");
    // exe.linkSystemLibrary("deps/lib/cimguid");
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
