const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const render = @import("render");
const input = @import("input");
const leko = @import("leko");

const chunkmesh = render.leko.chunkmesh;

const Vec3 = nm.Vec3;

const speed: f32 = 3;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    try render.leko.init();
    defer render.leko.deinit();

    var chunk = leko.Chunk.init(nm.Vec3i.zero);

    var perlin = nm.noise.Perlin3{};
    const scale = 0.1;

    for (chunk.id_array.items) |*id, i| {
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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var mesh = chunkmesh.Mesh.init(&chunk);
    defer mesh.deinit(allocator);

    try mesh.generateData(allocator);
    mesh.uploadData();
    chunkmesh.bindMesh(&mesh);


    var eye = Vec3.init(.{0, 0, -5});
    var mouselook = input.MouseLook{};
    window.setMouseMode(.hidden_raw);
    while (window.update()) {
        if (window.keyWasPressed(.escape)) {
            window.close();
        }
        else {
            if (window.keyWasPressed(.f_4)) {
                window.setDisplayMode(switch (window.displayMode()) {
                    .windowed => .borderless,
                    .borderless => .windowed,
                });
            }
            const delta = @floatCast(f32, window.frameTime());
            mouselook.update();
            const view = mouselook.viewMatrix();
            const forward = view.transformDirection(nm.Vec3.unit(.z)).mulScalar(delta * speed);
            const right = view.transformDirection(nm.Vec3.unit(.x)).mulScalar(delta * speed);
            const up = nm.Vec3.unit(.y).mulScalar(delta * speed);
            if (window.keyIsDown(.w)) eye = eye.add(forward);
            if (window.keyIsDown(.s)) eye = eye.sub(forward);
            if (window.keyIsDown(.a)) eye = eye.sub(right);
            if (window.keyIsDown(.d)) eye = eye.add(right);
            if (window.keyIsDown(.space)) eye = eye.add(up);
            if (window.keyIsDown(.left_shift)) eye = eye.sub(up);
            chunkmesh.startDraw();
            chunkmesh.setViewMatrix(nm.transform.createTranslate(eye.neg()).mul(view));
            chunkmesh.drawMesh(&mesh);
        }
    }
}