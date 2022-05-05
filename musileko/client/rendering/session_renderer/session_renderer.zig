const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;
const window = client.window;
const gui = client.gui;

const engine = @import("../../../engine/.zig");
const leko = engine.leko;
const session = engine.session;

const rendering = @import("../.zig");
const Camera = rendering.Camera;

const deferred = rendering.deferred;

const material = rendering.material;

const leko_renderer = rendering.leko_renderer;

const volume_model = leko_renderer.volume_model;
const selection_cube = leko_renderer.selection_cube;

const Allocator = std.mem.Allocator;

const VolumeModel = leko_renderer.VolumeModel;
const VolumeModelManager = leko_renderer.VolumeModelManager;

var _model: VolumeModel = undefined;
var _model_manager: VolumeModelManager = undefined;
var _deferred_pass: deferred.Pass = undefined;

var _pattern: material.Pattern = .{
    .warp_uv_scale = nm.Vec2.one,
    .warp_amount = nm.Vec2.init(.{0, 1}),
    .noise_uv_scale = nm.Vec2.init(.{0.5, 2}),
    .color_bands = 3,
};

var _pallete: material.Pallete = .{
    .color0 = nm.Vec4.init(.{0.27, 0.20, 0.30, 1.0}),
    .color1 = nm.Vec4.init(.{0.35, 0.25, 0.32, 1.0}),
    .color_dark = nm.Vec4.init(.{0.07, 0.03, 0.10, 1.0}),
};

var _material_window: gui.Window = .{
    .title = "material",
    .flags = &.{.always_auto_resize},
};

var _pass_properties: deferred.PassProperties = .{
    .fog_falloff = 5,
    .fog_start = 1.5,
    .fog_end = 3.75,
    .fog_color = nm.Vec4.init(.{0.1, 0, 0.1, 1}),
    .ao_bands = 3,
};

pub fn init(allocator: Allocator) !void {
    try volume_model.init();
    const volume = session.volume();
    const volume_manager = session.volumeManager();
    try _model.init(allocator, volume);
    try _model_manager.init(allocator, &_model);
    volume_manager.event_chunk_loaded.addListener(&_model_manager.listener_chunk_loaded);
    volume_manager.event_chunk_unloaded.addListener(&_model_manager.listener_chunk_unloaded);
    volume_manager.event_leko_edit.addListener(&_model_manager.listener_leko_edit);
    selection_cube.init();
    try _deferred_pass.init();
}

pub fn deinit() void {
    _model_manager.deinit();
    _model.deinit();
    _deferred_pass.deinit();
    volume_model.deinit();
    selection_cube.deinit();
}

pub fn render() void {
    gl.clearColor(_pass_properties.fog_color.v);
    gl.clearDepth(.float, 1);
    gl.clear(.color_depth);
    _model_manager.uploadGeneratedMeshes();
    var camera = Camera {
        .view = session.viewMatrix(),
        .proj = undefined,
    };
    camera.calculatePerspective(window.width(), window.height());
    _deferred_pass.setCamera(camera);
    _deferred_pass.setProperties(_pass_properties);
    _deferred_pass.setMaterialPattern(_pattern);
    _deferred_pass.setMaterialPallete(_pallete);
    if (_deferred_pass.begin()) {
        defer _deferred_pass.finish();

        const player = session.player();

        leko_renderer.chunk_mesh.setCamera(camera);
        leko_renderer.chunk_mesh.setPlayerSelection(player.select_reference);
        volume_model.startDraw();
        volume_model.drawModel(&_model);

    }
}

pub fn projectionMatrix() nm.Mat4 {
    const width = window.width();
    const height = window.height();
    const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov_rad, aspect, 0.01, 1000);
}


pub fn materialEditorWindow() void {
    if (_material_window.begin()) {
        defer _material_window.end();
        _ = deferred.passPropertiesEditor(&_pass_properties, "pass");
        _ = material.patternEditor(&_pattern, "pattern");
        _ = material.palleteEditor(&_pallete, "pallete");
    }
}