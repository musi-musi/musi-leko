const std = @import("std");
const math = std.math;

const asserts = @import("asserts.zig");
const vector = @import("vector.zig");
const matrix = @import("matrix.zig");

fn transformGeneric(comptime Scalar: type) type {
    comptime asserts.assertFloat(Scalar);
    return struct {

        pub const Vec3 = vector.Vector(Scalar, 3);
        pub const Vec4 = vector.Vector(Scalar, 4);
        pub const Mat4 = matrix.Matrix(Scalar, 4, 4);

        pub fn createTranslate(translate: Vec3) Mat4 {
            const x = translate.get(.x);
            const y = translate.get(.y);
            const z = translate.get(.z);
            return Mat4.init(.{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ x, y, z, 1 },
            });
        }

        pub fn createScale(scale: Vec3) Mat4 {
            const x = scale.get(.x);
            const y = scale.get(.y);
            const z = scale.get(.z);
            return Mat4.init(.{
                .{ x, 0, 0, 0 },
                .{ 0, y, 0, 0 },
                .{ 0, 0, z, 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn createAxisAngle(axis: Vec3, angle: Scalar) Mat4 {
            const x = axis.get(.x);
            const y = axis.get(.y);
            const z = axis.get(.z);
            const cos = std.math.cos(angle);
            const sin = std.math.sin(angle);

            return Mat4.init(.{
                .{ cos + x * x * (1 - cos), x * y * (1 - cos) - z * sin, x * z * (1 - cos) + y * sin, 0 },
                .{ y * x * (1 - cos) + z * sin, cos + y * y * (1 - cos), y * z * (1 - cos) - x * sin, 0 },
                .{ z * x * (1 * cos) - y * sin, z * y * (1 - cos) + x * sin, cos + z * z * (1 - cos), 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn createEulerZXY(euler: Vec3) Mat4 {
            const x = euler.get(.x);
            const y = euler.get(.y);
            const z = euler.get(.z);
            const sin = std.math.sin;
            const cos = std.math.cos;
            const c1 = cos(z);
            const s1 = sin(z);
            const c2 = cos(x);
            const s2 = sin(x);
            const c3 = cos(y);
            const s3 = sin(y);
            return Mat4.init(.{
                .{c1*c3 - s1*s2*s3, -c2*s1, c1*s3 + c3*s1*s2, 0},
                .{c3*s1 + c1*s2*s3, c1*c2, s1*s3 - c1*c3*s2, 0},
                .{-c2*s3, s2, c2*c3, 0},
                .{ 0, 0, 0, 1 }
            }).transpose();
        }

        pub fn createLook(eye: Vec3, direction: Vec3, up: Vec3) Mat4 {
            const f = direction.norm();
            const s = up.cross(f).norm();
            const u = f.cross(s);
            var result = Mat4.identity;
            result.v[0][0] = s.get(.x);
            result.v[1][0] = s.get(.y);
            result.v[2][0] = s.get(.z);
            result.v[0][1] = u.get(.x);
            result.v[1][1] = u.get(.y);
            result.v[2][1] = u.get(.z);
            result.v[0][2] = f.get(.x);
            result.v[1][2] = f.get(.y);
            result.v[2][2] = f.get(.z);
            result.v[3][0] = -s.dot(eye);
            result.v[3][1] = -u.dot(eye);
            result.v[3][2] = -f.dot(eye);
            return result;
        }

        pub fn createLookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
            return createLook(eye, target.sub(eye), up);
        }

        pub fn createPerspective(fov: Scalar, aspect: Scalar, near: Scalar, far: Scalar) Mat4 {
            const tan = std.math.tan(fov / 2);
            var result = Mat4.zero;
            result.v[0][0] = 1.0 / (aspect * tan);
            result.v[1][1] = 1.0 / (tan);
            result.v[2][2] = far / (far - near);
            result.v[2][3] = 1;
            result.v[3][2] = -(far * near) / (far - near);
            return result;
        }

        /// creates an orthogonal projection matrix.
        /// `left`, `right`, `bottom` and `top` are the borders of the screen whereas `near` and `far` define the
        /// distance of the near and far clipping planes.
        pub fn createOrthogonal(left: Scalar, right: Scalar, bottom: Scalar, top: Scalar, near: Scalar, far: Scalar) Mat4 {
            var result = Mat4.identity;
            result.v[0][0] = 2 / (right - left);
            result.v[1][1] = 2 / (top - bottom);
            result.v[2][2] = 1 / (far - near);
            result.v[3][0] = -(right + left) / (right - left);
            result.v[3][1] = -(top + bottom) / (top - bottom);
            result.v[3][2] = -near / (far - near);
            return result;
        }

    };
}

pub const transform = transformGeneric(f32);