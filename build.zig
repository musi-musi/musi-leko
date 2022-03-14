const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

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

    addPkgs(exe);

    exe.addIncludeDir("deps/inc");
    // exe.addIncludeDir("C:/Users/sam/zig-windows-x86_64-0.8.0/lib/libc/include/any-windows-any");
    // exe.addIncludeDir("C:/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.11.25503/include");
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("deps/src/stb_image.c", &[_][]const u8{"-std=c99"});
    // exe.addIncludeDir("GLFW/include/GLFW");
    exe.addLibPath("deps/lib");
    exe.linkSystemLibrary("glfw3");
    switch (target.getOs().tag) {
        .windows => {
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("shell32");
            exe.linkSystemLibrary("opengl32");
        },
        .linux => {

        },
        else => @panic("unsupported os target"),
    }
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

fn addPkgs(step: *std.build.LibExeObjStep) void {
    const c = Pkg {
        .name = "c",
        .path = FileSource.relative("src/c.zig"),
    };
    const nm = Pkg {
        .name = "nm",
        .path = FileSource.relative("src/nanpa-musi/_.zig"),
    };
    const util = Pkg {
        .name = "util",
        .path = FileSource.relative("src/util/_.zig"),
    };
    const gl = Pkg {
        .name = "gl",
        .path = FileSource.relative("src/gl/_.zig"),
        .dependencies = &[_]Pkg{ c },
    };
    const window = Pkg {
        .name = "window",
        .path = FileSource.relative("src/window/_.zig"),
        .dependencies = &[_]Pkg{ c, gl, nm },
    };
    const leko = Pkg {
        .name = "leko",
        .path = FileSource.relative("src/leko/_.zig"),
        .dependencies = &[_]Pkg{ nm, util },
    };
    const input = Pkg {
        .name = "input",
        .path = FileSource.relative("src/input/_.zig"),
        .dependencies = &[_]Pkg{ nm, window },
    };
    const session = Pkg {
        .name = "session",
        .path = FileSource.relative("src/session/_.zig"),
        .dependencies = &[_]Pkg{ nm, window, leko, input, util },
    };
    const render = Pkg {
        .name = "render",
        .path = FileSource.relative("src/render/_.zig"),
        .dependencies = &[_]Pkg{ nm, gl, window, leko, session, util },
    };
    step.addPackage(c);
    step.addPackage(nm);
    step.addPackage(util);
    step.addPackage(gl);
    step.addPackage(window);
    step.addPackage(leko);
    step.addPackage(input);
    step.addPackage(session);
    step.addPackage(render);
}