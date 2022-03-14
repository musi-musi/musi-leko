const std = @import("std");
const gl = @import("gl");
const leko = @import("leko");
const session = @import("session");

const leko_renderer = @import("../leko_renderer/_.zig");

const volume_model = leko_renderer.volume_model;

const Allocator = std.mem.Allocator;

const VolumeModel = volume_model.VolumeModel;
const VolumeModelManager = volume_model.VolumeModelManager;

var _model: VolumeModel = undefined;
var _model_manager: VolumeModelManager = undefined;

pub fn init(allocator: Allocator) !void {
    try volume_model.init();
    const volume = session.volume();
    const volume_manager = session.volumeManager();
    try _model.init(allocator, volume);
    try _model_manager.init(allocator, &_model);
    volume_manager.callback_chunk_loaded = &_model_manager.callback_chunk_loaded;
    volume_manager.callback_chunk_unloaded = &_model_manager.callback_chunk_unloaded;
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
