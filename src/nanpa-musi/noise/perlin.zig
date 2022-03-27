const std = @import("std");
const vector = @import("../vector.zig");
const asserts = @import("../asserts.zig");

pub fn Perlin1(comptime wrap: ?usize) type { return Perlin(f32, 1, wrap); }
pub fn Perlin2(comptime wrap: ?usize) type { return Perlin(f32, 2, wrap); }
pub fn Perlin3(comptime wrap: ?usize) type { return Perlin(f32, 3, wrap); }
pub fn Perlin4(comptime wrap: ?usize) type { return Perlin(f32, 4, wrap); }
pub fn Perlin1d(comptime wrap: ?usize) type { return Perlin(f64, 1, wrap); }
pub fn Perlin2d(comptime wrap: ?usize) type { return Perlin(f64, 2, wrap); }
pub fn Perlin3d(comptime wrap: ?usize) type { return Perlin(f64, 3, wrap); }
pub fn Perlin4d(comptime wrap: ?usize) type { return Perlin(f64, 4, wrap); }

pub fn Perlin(comptime Scalar_: type, comptime dimensions_: u32, comptime wrap_: ?usize) type {
    return struct {

        pub const Scalar = Scalar_;
        pub const dimensions = dimensions_;

        pub const Vector = vector.Vector(Scalar, dimensions);
        pub const IVector = vector.Vector(isize, dimensions);
        
        const wrap = wrap_;


        const Self = @This();

        const gradient_table = blk: {
            @setEvalBranchQuota(100000);
            var result: [548]Vector = undefined;
            var rng = std.rand.DefaultPrng.init(0);
            const r = rng.random();
            var v = 0;
            while (v < result.len) : (v += 1) {
                var g: Vector = undefined;
                for (Vector.indices) |i| {
                    g.v[i] = (r.float(Scalar) * 2) - 1;
                }
                if (dimensions > 1) {
                    var mag: Scalar = 0;
                    for (Vector.indices) |i| {
                        mag += g.v[i] * g.v[i];
                    }
                    mag = std.math.sqrt(mag);
                    for (Vector.indices) |i| {
                        g.v[i] /= mag;
                    }
                    result[v] = g;
                }
            }
            break: blk result;
        };

        fn mod(position: IVector) IVector {
            if (wrap) |w| {
                var result: IVector = undefined;
                inline for (IVector.indices) |i| {
                    result.v[i] = @rem(position.v[i], w);
                }
                return result;
            }
            else {
                return position;
            }
        }

        pub fn sample(self: Self, value: Vector.Value) Scalar {
            _ = self;
            var v = Vector.init(value);
            const min: IVector = v.floor().cast(isize);
            const max = min.add(IVector.fill(1));
            const a = min.v;
            // const a = mod(min).v;
            const b = mod(max).v;
            const s = v.sub(min.cast(Scalar)).v;
            switch (dimensions) {
                1 => {
                    return interpolate(
                        dotGradient(.{a[0]}, value),
                        dotGradient(.{b[0]}, value),
                    s[0]);
                },
                2 => {
                    return interpolate(
                        interpolate(
                            dotGradient(.{a[0], a[1]}, value),
                            dotGradient(.{b[0], a[1]}, value),
                        s[0]),
                        interpolate(
                            dotGradient(.{a[0], b[1]}, value),
                            dotGradient(.{b[0], b[1]}, value),
                        s[0]),
                    s[1]);
                },
                3 => {
                    return interpolate(
                        interpolate(
                            interpolate(
                                dotGradient(.{a[0], a[1], a[2]}, value),
                                dotGradient(.{b[0], a[1], a[2]}, value),
                            s[0]),
                            interpolate(
                                dotGradient(.{a[0], b[1], a[2]}, value),
                                dotGradient(.{b[0], b[1], a[2]}, value),
                            s[0]),
                        s[1]),
                        interpolate(
                            interpolate(
                                dotGradient(.{a[0], a[1], b[2]}, value),
                                dotGradient(.{b[0], a[1], b[2]}, value),
                            s[0]),
                            interpolate(
                                dotGradient(.{a[0], b[1], b[2]}, value),
                                dotGradient(.{b[0], b[1], b[2]}, value),
                            s[0]),
                        s[1]),
                    s[2]);
                },
                4 => {
                    return interpolate(
                        interpolate(
                            interpolate(
                                interpolate(
                                    dotGradient(.{a[0], a[1], a[2], a[3]}, value),
                                    dotGradient(.{b[0], a[1], a[2], a[3]}, value),
                                s[0]),
                                interpolate(
                                    dotGradient(.{a[0], b[1], a[2], a[3]}, value),
                                    dotGradient(.{b[0], b[1], a[2], a[3]}, value),
                                s[0]),
                            s[1]),
                            interpolate(
                                interpolate(
                                    dotGradient(.{a[0], a[1], b[2], a[3]}, value),
                                    dotGradient(.{b[0], a[1], b[2], a[3]}, value),
                                s[0]),
                                interpolate(
                                    dotGradient(.{a[0], b[1], b[2], a[3]}, value),
                                    dotGradient(.{b[0], b[1], b[2], a[3]}, value),
                                s[0]),
                            s[1]),
                        s[2]),
                        interpolate(
                            interpolate(
                                interpolate(
                                    dotGradient(.{a[0], a[1], a[2], b[3]}, value),
                                    dotGradient(.{b[0], a[1], a[2], b[3]}, value),
                                s[0]),
                                interpolate(
                                    dotGradient(.{a[0], b[1], a[2], b[3]}, value),
                                    dotGradient(.{b[0], b[1], a[2], b[3]}, value),
                                s[0]),
                            s[1]),
                            interpolate(
                                interpolate(
                                    dotGradient(.{a[0], a[1], b[2], b[3]}, value),
                                    dotGradient(.{b[0], a[1], b[2], b[3]}, value),
                                s[0]),
                                interpolate(
                                    dotGradient(.{a[0], b[1], b[2], b[3]}, value),
                                    dotGradient(.{b[0], b[1], b[2], b[3]}, value),
                                s[0]),
                            s[1]),
                        s[2]),
                    s[3]);
                },
                else => unreachable,
            }
        }

        fn interpolate(a: Scalar, b: Scalar, t: Scalar) Scalar {
            return (b - a) * (3 - t * 2) * t * t + a;
        }

        fn dotGradient(value: [dimensions]isize, position: Vector.Value) Scalar {
            const grad = gradient(value);
            var dist: Vector = undefined;
            inline for(Vector.indices) |i| {
                dist.v[i] = @intToFloat(Scalar, value[i]) - position[i];
            }
            return dist.dot(grad);
        }

        fn gradient(value: [dimensions]isize) Vector {
            comptime var rng = std.rand.DefaultPrng.init(0);
            const r = comptime rng.random();
            var hash = comptime r.int(usize);
            comptime var i = 0;
            inline while (i < dimensions) : (i += 1) {
                hash ^= (@bitCast(usize, value[i]) << 5 * i )^ comptime r.int(usize) +% r.int(usize);
                hash ^= (@bitCast(usize, value[i]) << 2 * i + 3 )^ comptime r.int(usize) +% r.int(usize);
                hash ^= (@bitCast(usize, value[i]) << i + 6 )^ comptime r.int(usize) +% r.int(usize);
            }
            return gradient_table[hash % gradient_table.len];
        }


    };
}