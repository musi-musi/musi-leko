const std = @import("std");
const rendering = @import(".zig");
const client = @import("../.zig");

const gui = client.gui;
const gl = client.gl;
const nm = client.nm;

const Vec2 = nm.Vec2;
const Vec4 = nm.Vec4;

pub const material = struct {

    pub const Pattern = struct {
        warp_uv_scale: Vec2,
        warp_amount: Vec2,
        noise_uv_scale: Vec2,
        color_bands: f32,
    };

    pub const Pallete = struct {
        color0: Vec4,
        color1: Vec4,
        color_dark: Vec4,
    };

    const slider_config: gui.SliderConfig = .{
        .speed = 0.01,
    };

    pub fn patternEditor(pattern: *Pattern, name: []const u8) bool {
        var dirty: bool = false;
        gui.text(64, "{s}", .{name});
        dirty = gui.float2("warp scale", &pattern.warp_uv_scale.v, slider_config) or dirty;
        dirty = gui.float2("warp amount", &pattern.warp_amount.v, slider_config) or dirty;
        dirty = gui.float2("noise scale", &pattern.noise_uv_scale.v, slider_config) or dirty;
        dirty = gui.float("bands", &pattern.color_bands, .{.speed = 0.1}) or dirty;
        return dirty;
    }
    pub fn palleteEditor(pallete: *Pallete, name: []const u8) bool {
        var dirty: bool = false;
        gui.text(64, "{s}", .{name});
        dirty = gui.color4("color 0", &pallete.color0.v, &.{}) or dirty;
        dirty = gui.color4("color 1", &pallete.color1.v, &.{}) or dirty;
        dirty = gui.color4("dark", &pallete.color_dark.v, &.{}) or dirty;
        return dirty;
    }

};
