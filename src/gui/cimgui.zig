const std = @import("std");
const c = @import("c");
const window = @import("window");
const input = @import("input");

const types = @import("types.zig");
const widgets = @import("widgets.zig");


pub var input_handle: input.InputHandle = .{ .is_active = false };

var _stats_window: Window = .{
    .title = "stats",
    .flags = &.{.no_move, .no_decoration},
};

pub fn init() !void {
    _ = c.igCreateContext(0);
    _ = c.imgui_glfw_init(window.handle(), 1);
    _ = c.imgui_gl_init();

    const io = c.igGetIO();
    io.*.FontGlobalScale = 2;
    io.*.IniFilename = null;

    const style = c.igGetStyle();
    style.*.WindowBorderSize = 0;
    style.*.WindowRounding = 8;

}

pub fn newFrame() void {
    c.imgui_glfw_set_io_enabled(input_handle.is_active);
    c.imgui_glfw_frame();
    c.imgui_gl_frame();
    c.igNewFrame();
}

pub fn render() void {
    c.igRender();
    c.imgui_gl_render(c.igGetDrawData());
}

pub fn deinit() void {
    c.imgui_gl_shutdown();
    c.imgui_glfw_shutdown();
    c.igDestroyContext(0);
}

pub fn showDemo() void {
    var show: bool = true;
    c.igShowDemoWindow(&show);
}


pub fn showStats() void {
    if (_stats_window.begin()) {
        defer _stats_window.end();
        _stats_window.position(.{8, 8});
        const frame_time = @floatCast(f32, window.frameTime());
        widgets.text(64, "fps:   {d: >5.2}", .{1 / frame_time});
        widgets.text(64, "delta: {d: >5.4}", .{frame_time});
    }
}


pub const WindowFlags = enum(c_int) {
    none = c.ImGuiWindowFlags_None,
    no_title_bar = c.ImGuiWindowFlags_NoTitleBar,
    no_resize = c.ImGuiWindowFlags_NoResize,
    no_move = c.ImGuiWindowFlags_NoMove,
    no_scrollbar = c.ImGuiWindowFlags_NoScrollbar,
    no_mouse_scroll = c.ImGuiWindowFlags_NoScrollWithMouse,
    no_collapse = c.ImGuiWindowFlags_NoCollapse,
    always_auto_resize = c.ImGuiWindowFlags_AlwaysAutoResize,
    no_background = c.ImGuiWindowFlags_NoBackground,
    no_saved_settings = c.ImGuiWindowFlags_NoSavedSettings,
    no_mouse_input = c.ImGuiWindowFlags_NoMouseInputs,
    menu_bar = c.ImGuiWindowFlags_MenuBar,
    horizontal_scrollbar = c.ImGuiWindowFlags_HorizontalScrollbar,
    no_focus_on_appear = c.ImGuiWindowFlags_NoFocusOnAppearing,
    no_front_on_focus = c.ImGuiWindowFlags_NoBringToFrontOnFocus,
    always_vertical_scrollbar = c.ImGuiWindowFlags_AlwaysVerticalScrollbar,
    always_horizontal_scrollbar = c.ImGuiWindowFlags_AlwaysHorizontalScrollbar,
    always_use_padding = c.ImGuiWindowFlags_AlwaysUseWindowPadding,
    no_nav_input = c.ImGuiWindowFlags_NoNavInputs,
    no_nav_focus = c.ImGuiWindowFlags_NoNavFocus,
    unsaved_document = c.ImGuiWindowFlags_UnsavedDocument,
    no_nav = c.ImGuiWindowFlags_NoNav,
    no_decoration = c.ImGuiWindowFlags_NoDecoration,
    no_input = c.ImGuiWindowFlags_NoInputs,
    nav_flattened = c.ImGuiWindowFlags_NavFlattened,
    child_window = c.ImGuiWindowFlags_ChildWindow,
    tooltip = c.ImGuiWindowFlags_Tooltip,
    popup = c.ImGuiWindowFlags_Popup,
    modal = c.ImGuiWindowFlags_Modal,
    child_menu = c.ImGuiWindowFlags_ChildMenu,
};

pub const Cond = enum(c_int) {
    none = c.ImGuiCond_None,
    always = c.ImGuiCond_Always,
    once = c.ImGuiCond_Once,
    first_use_ever = c.ImGuiCond_FirstUseEver,
    appearing = c.ImGuiCond_Appearing,
};

pub const Window = struct {
    title: [:0]const u8,
    flags: []const WindowFlags = &.{.none},
    show: bool = true,

    const Self = @This();


    pub fn position(_: Self, pos: [2]f32) void {
        c.igSetWindowPos_Vec2(types.cvec2(pos), @enumToInt(Cond.always));
    }


    pub fn begin(self: *Self) bool {
        var flags_sum: c_int = 0;
        for (self.flags) |flag| {
            flags_sum |= @enumToInt(flag);
        }
        return c.igBegin(self.title.ptr, &self.show, flags_sum);
    }

    pub fn end(_: *Self) void {
        c.igEnd();
    }
};