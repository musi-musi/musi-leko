const std = @import("std");
const session = @import("session");
const leko = @import("leko/_.zig");

const Allocator = std.mem.Allocator;

const chunkmesh = leko.chunkmesh;

var _mesh: chunkmesh.Mesh = undefined;

pub const exports = struct {

    pub fn init(allocator: Allocator) !void {
        try chunkmesh.init();
        _mesh = chunkmesh.Mesh.init(session.chunk());

        try _mesh.generateData(allocator);
        _mesh.uploadData();
        chunkmesh.bindMesh(&_mesh);
    }

    pub fn deinit(allocator: Allocator) void {
        chunkmesh.deinit();
        _mesh.deinit(allocator);
    }

    pub fn render() void {
        chunkmesh.startDraw();
        chunkmesh.setViewMatrix(session.viewMatrix());
        chunkmesh.drawMesh(&_mesh);
    }

};