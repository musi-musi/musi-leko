const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const render = @import("render");
const input = @import("input");
const leko = @import("leko");

const Vec3 = nm.Vec3;
const Mat4 = nm.Mat4;

const speed: f32 = 10;

var _chunk: leko.Chunk = undefined;
var _camera_pos: Vec3 = undefined;
var _mouselook = input.MouseLook{};
var _view_matrix: Mat4 = undefined;

pub const exports = struct {

    pub fn init() void {

        _chunk.init(nm.Vec3i.zero);

        var perlin = nm.noise.Perlin3{};
        const scale = 0.1;

        for (_chunk.id_array.items) |*id, i| {
            const index = leko.LekoIndex.initI(i);
            const pos = index.vector().cast(f32);
            const sample = perlin.sample(pos.mulScalar(scale).v);
            if (sample > 0) {
                id.* = 1;
            }
            else {
                id.* = 0;
            }
        }

        _camera_pos = Vec3.init(.{0, 0, -5});
        window.setMouseMode(.hidden_raw);
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

    pub fn chunk() *const leko.Chunk {
        return &_chunk;
    }

};