const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;
const window = client.window;

const engine = @import("../../../engine/.zig");
const leko = engine.leko;
const session = engine.session;

const rendering = @import("../.zig");
const Camera = rendering.Camera;

const leko_renderer = rendering.leko_renderer;

const volume_model = leko_renderer.volume_model;
const selection_cube = leko_renderer.selection_cube;

const Allocator = std.mem.Allocator;

const VolumeModel = leko_renderer.VolumeModel;
const VolumeModelManager = leko_renderer.VolumeModelManager;

var _model: VolumeModel = undefined;
var _model_manager: VolumeModelManager = undefined;

pub fn init(allocator: Allocator) !void {
    try volume_model.init();
    const volume = session.volume();
    const volume_manager = session.volumeManager();
    try _model.init(allocator, volume);
    try _model_manager.init(allocator, &_model);
    volume_manager.event_chunk_loaded.addListener(&_model_manager.listener_chunk_loaded);
    volume_manager.event_chunk_unloaded.addListener(&_model_manager.listener_chunk_unloaded);
    try selection_cube.init();
}

pub fn deinit() void {
    _model_manager.deinit();
    _model.deinit();
    volume_model.deinit();
    selection_cube.deinit();
}

pub fn render() void {
    gl.clearColor(.{0, 0, 0, 1});
    gl.clearDepth(.float, 1);
    gl.clear(.color_depth);
    _model_manager.uploadGeneratedMeshes();
    const camera = Camera {
        .proj = projectionMatrix(),
        .view = session.viewMatrix(),
    };
    volume_model.setViewMatrix(camera.view);
    volume_model.setProjectionMatrix(camera.proj);
    volume_model.startDraw();
    volume_model.drawModel(&_model);
    const player = session.player();
    if (player.select_reference) |selection| {
        selection_cube.setCamera(camera);
        selection_cube.startDraw();
        selection_cube.draw(selection.reference.globalPosition());
    }
}

pub fn projectionMatrix() nm.Mat4 {
    const width = window.width();
    const height = window.height();
    const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov_rad, aspect, 0.01, 1000);
}