const std = @import("std");
const nm = @import("nm");
const gl = @import("gl");
const window = @import("window");
const session = @import("session");
const leko = @import("leko");

// const leko = @import("leko/_.zig");
const debug = @import("debug/_.zig");

const cube = debug.cube;

const Allocator = std.mem.Allocator;

// const volume = leko.volume;

// var _model: volume.Model = undefined;

pub const exports = struct {

    pub fn init(allocator: Allocator) !void {
        _ = allocator;
        try cube.init();
        cube.setLight(nm.vec3(.{1, 2, 3}).norm());
        // try volume.init();

        // try _model.init(allocator, session.volume());

        // var chunks = session.volume().chunks.valueIterator();

        // while (chunks.next()) |chunk| {
        //     try _model.addChunk(chunk.*);
        // }
    }

    pub fn deinit() void {
        cube.deinit();
        // _model.deinit();
    }

    pub fn render() void {
        gl.clearColor(.{0, 0, 0, 1});
        gl.clearDepth(.float, 1);
        gl.clear(.color_depth);
        cube.setView(session.viewMatrix());
        cube.setProjection(projectionMatrix());
        cube.startDraw();
        var chunks_iter = session.volume().chunks.valueIterator();
        while (chunks_iter.next()) |chunk_ptr| {
            const chunk = chunk_ptr.*;
            const color = switch(chunk.*.state) {
                .inactive => nm.vec3(.{1, 0, 0}),
                .loading => nm.vec3(.{0.5, 1, 0.5}),
                .active => nm.vec3(.{0.5, 0.5, 1}),
            };
            cube.draw(chunk.*.position.mulScalar(@intCast(i32, leko.Chunk.width)).cast(f32), 0.5, color);
        }
        // volume.setViewMatrix(session.viewMatrix());
        // _model.render();
    }

};

fn projectionMatrix() nm.Mat4 {
    const width = window.width();
    const height = window.height();
    const fov_rad: f32 = std.math.pi / 180.0 * 90.0;
    const aspect = @intToFloat(f32, width) / @intToFloat(f32, height);
    return nm.transform.createPerspective(fov_rad, aspect, 0.001, 10000);
}