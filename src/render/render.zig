const std = @import("std");
const session = @import("session");
const leko = @import("leko/_.zig");

const Allocator = std.mem.Allocator;

const volume = leko.volume;

var _model: volume.Model = undefined;

pub const exports = struct {

    pub fn init(allocator: Allocator) !void {
        try volume.init();

        try _model.init(allocator, session.volume());

        var chunks = session.volume().chunks.valueIterator();

        while (chunks.next()) |chunk| {
            try _model.addChunk(chunk.*);
        }
    }

    pub fn deinit() void {
        _model.deinit();
    }

    pub fn render() void {
        volume.setViewMatrix(session.viewMatrix());
        _model.render();
    }

};