const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

const Allocator = std.mem.Allocator;

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    b.installBinFile("musileko/c/glfw3.dll", "glfw3.dll");


    const exe = b.addExecutable("musileko", "musileko/_.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addLibPath("musileko/c");
    exe.linkSystemLibrary("glfw3");
    
    const c_flags = .{ "-std=c99", "-I./musileko/c/"};

    exe.addIncludeDir("musileko/c/");
    exe.addIncludeDir("musileko/c/glad/include");
    exe.addCSourceFile("musileko/c/glad/src/glad.c", &c_flags);
    exe.addCSourceFile("musileko/c/stb_image.c", &c_flags);


    const flags: []const []const u8 = &.{
        "-std=c++11",
        "-I./musileko/c",
        "-I./musileko/c/glad/include",
        "-I./musileko/c/cimgui",
        "-I./musileko/c/cimgui/imgui",
        "-I./musileko/c/imgui_impl",
    };


    exe.addCSourceFile("musileko/c/imgui_impl.cpp", flags);

    exe.addIncludeDir("musileko/c/cimgui");
    exe.addIncludeDir("musileko/c/cimgui/imgui");
    exe.addCSourceFile("musileko/c/cimgui/cimgui.cpp", flags);
    exe.addCSourceFile("musileko/c/cimgui/imgui/imgui.cpp", flags);
    exe.addCSourceFile("musileko/c/cimgui/imgui/imgui_draw.cpp", flags);
    exe.addCSourceFile("musileko/c/cimgui/imgui/imgui_demo.cpp", flags);
    exe.addCSourceFile("musileko/c/cimgui/imgui/imgui_tables.cpp", flags);
    exe.addCSourceFile("musileko/c/cimgui/imgui/imgui_widgets.cpp", flags);

    exe.addIncludeDir("musileko/c/imgui_impl");
    exe.addCSourceFile("musileko/c/imgui_impl/imgui_impl_glfw.cpp", flags);
    exe.addCSourceFile("musileko/c/imgui_impl/imgui_impl_opengl3.cpp", flags);

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

    var generate_imports = try GenerateImportsStep.init(b, "musileko");
    exe.step.dependOn(&generate_imports.step);
    var clean_imports = try CleanImportsStep.init(b, "musileko");
    exe.step.dependOn(&clean_imports.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("srmusileko/c/main.zig");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    const generate_imports_step = b.step("imports", "generate imports");
    generate_imports_step.dependOn(&generate_imports.step);
    const clean_imports_step = b.step("clean_imports", "clean imports");
    clean_imports_step.dependOn(&clean_imports.step);
}

const fs = std.fs;


const Step = std.build.Step;
const Builder = std.build.Builder;

const GenerateImportsStep = struct {
    step: Step,
    builder: *Builder,
    root_path: []const u8,

    const Self = @This();

    pub fn init(builder: *Builder, root_path: []const u8) !*Self {
        const self = try builder.allocator.create(Self);
        self.* = Self {
            .builder = builder,
            .step = Step.init(.custom, builder.fmt("generate imports {s}", .{root_path}), builder.allocator, make),
            .root_path = root_path,
        };
        return self;
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(Self, "step", step);
        var root = try fs.cwd().openDir(self.root_path, .{ .iterate = true });
        defer root.close();
        try self.generateImports(root);
    }

    fn generateImports(self: Self, dir: fs.Dir) anyerror!void {
        _ = self;
        if (try hasZigFiles(dir)) {
            var imports_file = try dir.createFile(".zig", .{});
            defer imports_file.close();
            const writer = imports_file.writer();
            try writer.writeAll("// generated imports file\n");
            var children = dir.iterate();
            while (try children.next()) |child| {
                if (child.name[0] != '.') {
                    if (child.kind == .Directory) {
                        var child_dir = try dir.openDir(child.name, .{ .iterate = true });
                        defer child_dir.close();
                        if (try hasZigFiles(child_dir)) {
                            try writer.print("pub const @\"{s}\" =  @import(\"{s}/.zig\");\n", .{child.name, child.name});
                            try self.generateImports(child_dir);
                        }
                    }
                }
            }
            try writer.writeAll("\n");
            children = dir.iterate();
            while (try children.next()) |child| {
                if (child.name[0] != '.') {
                    switch (child.kind) {
                        .File => {
                            if (std.mem.endsWith(u8, child.name, ".zig") and !std.mem.eql(u8, child.name, "_.zig")) {
                                try writer.print("pub usingnamespace @import(\"{s}\");\n", .{child.name});
                            }
                        },
                        else => {},
                    }
                }
            }
        }
    }

    fn hasZigFiles(dir: fs.Dir) anyerror!bool    {
        var children = dir.iterate();
        while (try children.next()) |child| {
            switch (child.kind) {
                .File => {
                    if (std.mem.endsWith(u8, child.name, ".zig")) {
                        return true;
                    }
                },
                .Directory => {
                    var child_dir = try dir.openDir(child.name, .{ .iterate = true });
                    defer child_dir.close();
                    if (try hasZigFiles(child_dir)) {
                        return true;
                    }
                },
                else => {},
            }
        }
        return false;
    }

};

const CleanImportsStep = struct {
    step: Step,
    builder: *Builder,
    root_path: []const u8,

    const Self = @This();

    pub fn init(builder: *Builder, root_path: []const u8) !*Self {
        const self = try builder.allocator.create(Self);
        self.* = Self {
            .builder = builder,
            .step = Step.init(.custom, builder.fmt("generate imports {s}", .{root_path}), builder.allocator, make),
            .root_path = root_path,
        };
        return self;
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(Self, "step", step);
        var root = try fs.cwd().openDir(self.root_path, .{ .iterate = true });
        defer root.close();
        try self.cleanImports(root);
    }

    fn cleanImports(self: Self, dir: fs.Dir) anyerror!void {
        dir.deleteFile(".zig") catch {};
        var children = dir.iterate();
        while (try children.next()) |child| {
            if (child.kind == .Directory) {
                var child_dir = try dir.openDir(child.name, .{ .iterate = true, });
                defer child_dir.close();
                try self.cleanImports(child_dir);
            }
        }
    }

};