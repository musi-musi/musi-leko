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

    b.installBinFile("deps/glfw3.dll", "glfw3.dll");


    const exe = b.addExecutable("musileko", "src/main.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);

    addPkgs(exe);

    exe.addLibPath("deps");
    exe.linkSystemLibrary("glfw3");
    
    const c_flags = .{ "-std=c99", "-I./deps/"};

    exe.addIncludeDir("deps/");
    exe.addCSourceFile("deps/glad.c", &c_flags);
    exe.addCSourceFile("deps/stb_image.c", &c_flags);


    const flags: []const []const u8 = &.{
        "-std=c++11",
        "-I./deps",
        "-I./deps/cimgui",
        "-I./deps/cimgui/imgui",
        "-I./deps/imgui_impl",
    };


    exe.addCSourceFile("deps/imgui_impl.cpp", flags);

    exe.addIncludeDir("deps/cimgui");
    exe.addIncludeDir("deps/cimgui/imgui");
    exe.addCSourceFile("deps/cimgui/cimgui.cpp", flags);
    exe.addCSourceFile("deps/cimgui/imgui/imgui.cpp", flags);
    exe.addCSourceFile("deps/cimgui/imgui/imgui_draw.cpp", flags);
    exe.addCSourceFile("deps/cimgui/imgui/imgui_demo.cpp", flags);
    exe.addCSourceFile("deps/cimgui/imgui/imgui_tables.cpp", flags);
    exe.addCSourceFile("deps/cimgui/imgui/imgui_widgets.cpp", flags);

    exe.addIncludeDir("deps/imgui_impl");
    exe.addCSourceFile("deps/imgui_impl/imgui_impl_glfw.cpp", flags);
    exe.addCSourceFile("deps/imgui_impl/imgui_impl_opengl3.cpp", flags);

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
    const input = Pkg {
        .name = "input",
        .path = FileSource.relative("src/input/_.zig"),
        .dependencies = &[_]Pkg{ nm, window },
    };
    const gui = Pkg {
        .name = "gui",
        .path = FileSource.relative("src/gui/_.zig"),
        .dependencies = &[_]Pkg{ c, gl, nm, util, window, input },
    };
    const leko = Pkg {
        .name = "leko",
        .path = FileSource.relative("src/leko/_.zig"),
        .dependencies = &[_]Pkg{ nm, util },
    };
    const session = Pkg {
        .name = "session",
        .path = FileSource.relative("src/session/_.zig"),
        .dependencies = &[_]Pkg{ nm, window, leko, input, util, gui },
    };
    const render = Pkg {
        .name = "render",
        .path = FileSource.relative("src/render/_.zig"),
        .dependencies = &[_]Pkg{ nm, gl, window, leko, session, util, gui },
    };
    step.addPackage(c);
    step.addPackage(nm);
    step.addPackage(util);
    step.addPackage(gl);
    step.addPackage(window);
    step.addPackage(input);
    step.addPackage(gui);
    step.addPackage(leko);
    step.addPackage(session);
    step.addPackage(render);
}