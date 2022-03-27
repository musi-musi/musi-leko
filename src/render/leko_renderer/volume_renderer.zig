   
const std = @import("std");
const leko = @import("leko");

const chunk_mesh = @import("chunk_mesh.zig").exports;
const volume_model = @import("volume_model.zig").exports;

const VolumeModel = volume_model.VolumeModel;
const VolumeModelManager = volume_model.VolumeModelManager;

pub fn init() !void {
    try volume_model.init();
}

pub fn deinit() void {
    volume_model.init();
}

pub const VolumeRenderer = struct {
    model_manager


};