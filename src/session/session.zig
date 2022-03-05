const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const render = @import("render");
const input = @import("input");
const leko = @import("leko");

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;
const Mat4 = nm.Mat4;

const speed: f32 = 10;

var _volume: leko.Volume = undefined;
var _camera_pos: Vec3 = undefined;
var _mouselook = input.MouseLook{};
var _view_matrix: Mat4 = undefined;

const Allocator = std.mem.Allocator;

pub const exports = struct {

    pub fn init(allocator: Allocator) !void {

        try _volume.init(allocator);
        
        var perlin = nm.noise.Perlin3{};
        const scale = 0.1;

        const view_radius: i32 = 4;
        var chunk_pos = Vec3i.fill(-view_radius);
        while (chunk_pos.v[0] < view_radius) : (chunk_pos.v[0] += 1) {
            chunk_pos.v[1] = -view_radius;
            while (chunk_pos.v[1] < view_radius) : (chunk_pos.v[1] += 1) {
                chunk_pos.v[2] = -view_radius;
                while (chunk_pos.v[2] < view_radius) : (chunk_pos.v[2] += 1) {
                    var chunk = try _volume.createChunk(chunk_pos);
                    for (chunk.id_array.items) |*id, i| {
                        const index = leko.LekoIndex.initI(i);
                        const pos = chunk_pos.mulScalar(leko.Chunk.width).add(index.vector().cast(i32)).cast(f32);
                        const sample = perlin.sample(pos.mulScalar(scale).v);
                        if (sample > 0) {
                            id.* = 1;
                        }
                        else {
                            id.* = 0;
                        }
                    }
                }
            }
        }

        _camera_pos = Vec3.init(.{0, 0, -5});
        window.setMouseMode(.hidden_raw);
    }

    pub fn deinit() void {
        _volume.deinit();
    }

    pub fn update() void {
        const delta = @floatCast(f32, window.frameTime());
        _mouselook.update();
        _view_matrix = _mouselook.viewMatrix();
        const forward = _view_matrix.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta * speed);
        const right = _view_matrix.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta * speed);
        const up = nm.Vec3.unit(.y).mulScalar(delta * speed);
        if (window.keyIsDown(.w)) _camera_pos = _camera_pos.add(forward);
        if (window.keyIsDown(.s)) _camera_pos = _camera_pos.sub(forward);
        if (window.keyIsDown(.a)) _camera_pos = _camera_pos.sub(right);
        if (window.keyIsDown(.d)) _camera_pos = _camera_pos.add(right);
        if (window.keyIsDown(.space)) _camera_pos = _camera_pos.add(up);
        if (window.keyIsDown(.left_shift)) _camera_pos = _camera_pos.sub(up);
    }

    pub fn viewMatrix() Mat4 {
        return nm.transform.createTranslate(_camera_pos.neg()).mul(_view_matrix);
    }

    pub fn volume() *const leko.Volume {
        return &_volume;
    }

};