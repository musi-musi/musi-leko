const std = @import("std");
const build = std.build;

pub fn addSources(step: *build.LibExeObjStep, comptime cimgui_root: []const u8) !void {
    step.addIncludeDir(cimgui_root);
    const flags = "";
    step.addIncludeDir(cimgui_root ++ "/imgui");
    step.addCSourceFile(cimgui_root ++ "/cimgui.cpp", flags);
    step.addCSourceFile(cimgui_root ++ "/imgui/imgui.cpp", flags);
    step.addCSourceFile(cimgui_root ++ "/imgui/imgui_draw.cpp", flags);
    step.addCSourceFile(cimgui_root ++ "/imgui/imgui_demo.cpp", flags);
    step.addCSourceFile(cimgui_root ++ "/imgui/imgui_tables.cpp", flags);
    step.addCSourceFile(cimgui_root ++ "/imgui/imgui_widgets.cpp", flags);
}