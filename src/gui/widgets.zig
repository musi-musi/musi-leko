const std = @import("std");
const gui = @import("_.zig");
const c = gui.c;
const types = gui.types;
const nm = @import("nm");

const CStr = [:0]const u8;

pub const SliderFlags = enum(c_int) {
    none = c.ImGuiSliderFlags_None,
    always_clamp = c.ImGuiSliderFlags_AlwaysClamp,
    logarithmic = c.ImGuiSliderFlags_Logarithmic,
    no_round = c.ImGuiSliderFlags_NoRoundToFormat,
    no_input = c.ImGuiSliderFlags_NoInput,

};

pub const SliderConfig = struct {
    speed: f32 = 1,
    min: f32 = -std.math.f32_max,
    max: f32 = std.math.f32_max,
    format: CStr = "%8.4f",
    flags: []const SliderFlags = &.{ .none },
};


pub fn float(label: CStr, v: *f32, config: SliderConfig) bool {
    return c.igDragFloat(
        label.ptr,
        v,
        config.speed,
        config.min,
        config.max,
        config.format.ptr,
        types.sumFlags(SliderFlags, config.flags),
    );
}

pub fn float2(label: CStr, v: *[2]f32, config: SliderConfig) bool {
    return c.igDragFloat2(
        label.ptr,
        v,
        config.speed,
        config.min,
        config.max,
        config.format.ptr,
        types.sumFlags(SliderFlags, config.flags),
    );
}

pub fn float3(label: CStr, v: *[3]f32, config: SliderConfig) bool {
    return c.igDragFloat3(
        label.ptr,
        v,
        config.speed,
        config.min,
        config.max,
        config.format.ptr,
        types.sumFlags(SliderFlags, config.flags),
    );
}

pub fn float4(label: CStr, v: *[4]f32, config: SliderConfig) bool {
    return c.igDragFloat4(
        label.ptr,
        v,
        config.speed,
        config.min,
        config.max,
        config.format.ptr,
        types.sumFlags(SliderFlags, config.flags),
    );
}

pub const ColorEditFlags = enum(c_int) {
    none = c.ImGuiColorEditFlags_None,
    no_alpha = c.ImGuiColorEditFlags_NoAlpha,
    no_picker = c.ImGuiColorEditFlags_NoPicker,
    no_options = c.ImGuiColorEditFlags_NoOptions,
    no_small_preview = c.ImGuiColorEditFlags_NoSmallPreview,
    no_inputs = c.ImGuiColorEditFlags_NoInputs,
    no_tooltip = c.ImGuiColorEditFlags_NoTooltip,
    no_label = c.ImGuiColorEditFlags_NoLabel,
    no_side_preview = c.ImGuiColorEditFlags_NoSidePreview,
    no_drag_drop = c.ImGuiColorEditFlags_NoDragDrop,
    no_border = c.ImGuiColorEditFlags_NoBorder,
    no_alpha_bar = c.ImGuiColorEditFlags_AlphaBar,
    no_alpha_preview = c.ImGuiColorEditFlags_AlphaPreview,
    no_alpha_preview_half = c.ImGuiColorEditFlags_AlphaPreviewHalf,
    hdr = c.ImGuiColorEditFlags_HDR,
    display_rgb = c.ImGuiColorEditFlags_DisplayRGB,
    display_hsv = c.ImGuiColorEditFlags_DisplayHSV,
    display_hex = c.ImGuiColorEditFlags_DisplayHex,
    uint8 = c.ImGuiColorEditFlags_Uint8,
    float = c.ImGuiColorEditFlags_Float,
    picker_hue_bar = c.ImGuiColorEditFlags_PickerHueBar,
    pucker_hue_wheel = c.ImGuiColorEditFlags_PickerHueWheel,
    input_rgb = c.ImGuiColorEditFlags_InputRGB,
    input_hsv = c.ImGuiColorEditFlags_InputHSV,
};

pub fn color3(label: CStr, value: *[3]f32, flags: []const ColorEditFlags) bool {
    return c.igColorEdit3(label.ptr, value, types.sumFlags(ColorEditFlags, flags));
}

pub fn color4(label: CStr, value: *[3]f32, flags: []const ColorEditFlags) bool {
    return c.igColorEdit3(label.ptr, value, types.sumFlags(ColorEditFlags, flags));
}

pub fn text(comptime buflen: usize, comptime format: []const u8, args: anytype) void {
    var buf = std.mem.zeroes([buflen]u8);
    _ = std.fmt.bufPrintZ(&buf, format, args) catch {};
    c.igText(&buf);
}