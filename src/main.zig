const std = @import("std");
const nm = @import("nm");

const window = @import("window");
const render = @import("render");


const Vec3 = nm.Vec3;

const demo = render.demos.cube;

const speed: f32 = 3;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    try demo.init();
    defer demo.deinit();

    var eye = Vec3.init(.{5, 2, 3});

    while (window.update()) {
        if (window.keyWasPressed(.escape)) {
            window.close();
        }
        else {
            const delta = window.frameTime();
            const mv = @floatCast(f32, delta * speed);
            if (window.keyIsDown(.w)) eye = eye.add(Vec3.init(.{0, 0, mv}));
            if (window.keyIsDown(.s)) eye = eye.add(Vec3.init(.{0, 0, -mv}));
            if (window.keyIsDown(.a)) eye = eye.add(Vec3.init(.{-mv, 0, 0}));
            if (window.keyIsDown(.d)) eye = eye.add(Vec3.init(.{mv, 0, 0}));
            if (window.keyIsDown(.mouse_1)) eye = eye.add(Vec3.init(.{0, mv, 0}));
            if (window.keyIsDown(.mouse_2)) eye = eye.add(Vec3.init(.{0, -mv, 0}));
            demo.setViewMatrix(nm.transform.createLookAt(
                eye,
                Vec3.init(.{0.5, 0.5, 0.5}),
                Vec3.init(.{0, 1, 0}),
            ));
            demo.draw();
        }
    }
}