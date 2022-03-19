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

    exe.addLibPath("deps");
    exe.linkSystemLibrary("glfw3");
    
    exe.addIncludeDir("deps/");
    exe.addCSourceFile("deps/glad.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("deps/stb_image.c", &[_][]const u8{"-std=c99"});


    // const flags: []const []const u8 = &.{"-std=c++11"};


    // exe.addCSourceFile("deps/c.cpp", flags);

    // exe.addIncludeDir("deps/cimgui");
    // exe.addIncludeDir("deps/cimgui/imgui");
    // exe.addCSourceFile("deps/cimgui/cimgui.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/imgui.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/imgui_draw.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/imgui_demo.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/imgui_tables.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/imgui_widgets.cpp", flags);

    // exe.addIncludeDir("deps/cimgui/imgui/backends");
    // exe.addCSourceFile("deps/cimgui/imgui/backends/imgui_impl_glfw.cpp", flags);
    // exe.addCSourceFile("deps/cimgui/imgui/backends/imgui_impl_opengl3.cpp", flags);

    // switch (target.getOs().tag) {
    //     .windows => {
    //         exe.linkSystemLibrary("user32");
    //         exe.linkSystemLibrary("gdi32");
    //         exe.linkSystemLibrary("shell32");
    //         exe.linkSystemLibrary("opengl32");
    //     },
    //     .linux => {

    //     },
    //     else => @panic("unsupported os target"),
    // }
    // exe.linkSystemLibrary("deps/lib/cimguid");
    exe.linkLibCpp();
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