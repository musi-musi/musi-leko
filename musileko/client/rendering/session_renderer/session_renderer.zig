const std = @import("std");

const client = @import("../../_.zig");
const gl = client.gl;

const engine = @import("../../../engine/_.zig");
const leko = engine.leko;
const session = engine.session;

const rendering = @import("../_.zig");

const leko_renderer = rendering.leko_renderer;

const volume_model = leko_renderer.volume_model;

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
}

pub fn deinit() void {
    _model_manager.deinit();
    _model.deinit();
    volume_model.deinit();
}

pub fn render() void {
    gl.clearColor(.{0, 0, 0, 1});
    gl.clearDepth(.float, 1);
    gl.clear(.color_depth);
    _model_manager.uploadGeneratedMeshes();
    volume_model.setViewMatrix(session.viewMatrix());
    volume_model.startDraw();
    volume_model.drawModel(&_model);
}

