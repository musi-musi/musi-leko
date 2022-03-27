const std = @import("std");
const asserts = @import("asserts.zig");
const vector = @import("vector.zig");

pub fn Matrix(comptime Scalar_: type, comptime rows_: comptime_int, comptime cols_: comptime_int) type {
    comptime asserts.assertFloat(Scalar_);
    comptime asserts.assertValidDimensionCount(rows_);
    comptime asserts.assertValidDimensionCount(cols_);
    if (rows_ != cols_) @compileError("TODO: support non-square mats"); // TODO: support non-square mats
    return struct {
        v: Value,

        pub const Value = [rows][cols]Scalar;

        pub const Scalar = Scalar_;
        pub const Vector = vector.Vector(Scalar, rows);
        pub const rows = rows_;
        pub const cols = cols_;

        pub const row_indices = ([_]usize{ 0, 1, 2, 3, })[0..rows];
        pub const col_indices = ([_]usize{ 0, 1, 2, 3, })[0..cols];

        const Self = @This();
        
        pub const zero = fill(0);
        pub const identity = blk: {
            var id = zero;
            for (row_indices) |r| {
                id.v[r][r] = 1;
            }
            break :blk id;
        };

        pub fn init(value: Value) Self {
            return Self { .v = value };
        }

        pub fn fill(v: Scalar) Self {
            var self: Self = undefined;
            inline for(row_indices) |r| {
                inline for(col_indices) |c| {
                    self.v[r][c] = v;
                }
            }
            return self;
        }

        pub fn transform(self: Self, vec: Vector) Vector {
            var res = Vector.zero;
            inline for(col_indices) |c| {
                inline for(row_indices) |r| {
                    res.v[r] += vec.v[c] * self.v[r][c];
                }
            }
            return res;
        }

        /// the vector with one less dimension
        pub const ShortVector = vector.Vector(Scalar, rows - 1);

        pub fn transformDirection(self: Self, vec: ShortVector) ShortVector {
            return self.transform(vec.addDimension(0)).removeDimension();
        }
        
        pub fn transformPosition(self: Self, vec: ShortVector) ShortVector {
            return self.transform(vec.addDimension(1)).removeDimension();
        }

        pub fn mul(ma: Self, mb: Self) Self {
            // TODO: support non-square mats
            var res: Self = undefined;
            inline for (row_indices) |r| {
                inline for (col_indices) |c| {
                    var sum: Scalar = 0;
                    inline for (row_indices) |i| {
                        sum += ma.v[r][i] * mb.v[i][c];
                    }
                    res.v[r][c] = sum;
                }
            }
            return res;
        }

        pub fn transpose(self: Self) Self {
            var res: Self = undefined;
            inline for (row_indices) |r| {
                inline for (col_indices) |c| {
                    res.v[r][c] = self.v[c][r];
                }
            }
            return res;
        }

        pub fn invert(self: Self) ?Self {
            // https://github.com/stackgl/gl-mat4/blob/master/invert.js
            const a = @bitCast([16]Scalar, self.v);

            const a00 = a[0];
            const a01 = a[1];
            const a02 = a[2];
            const a03 = a[3];
            const a10 = a[4];
            const a11 = a[5];
            const a12 = a[6];
            const a13 = a[7];
            const a20 = a[8];
            const a21 = a[9];
            const a22 = a[10];
            const a23 = a[11];
            const a30 = a[12];
            const a31 = a[13];
            const a32 = a[14];
            const a33 = a[15];

            const b00 = a00 * a11 - a01 * a10;
            const b01 = a00 * a12 - a02 * a10;
            const b02 = a00 * a13 - a03 * a10;
            const b03 = a01 * a12 - a02 * a11;
            const b04 = a01 * a13 - a03 * a11;
            const b05 = a02 * a13 - a03 * a12;
            const b06 = a20 * a31 - a21 * a30;
            const b07 = a20 * a32 - a22 * a30;
            const b08 = a20 * a33 - a23 * a30;
            const b09 = a21 * a32 - a22 * a31;
            const b10 = a21 * a33 - a23 * a31;
            const b11 = a22 * a33 - a23 * a32;

            // Calculate the determinant
            var det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

            if (std.math.approxEqAbs(Scalar, det, 0, 1e-8)) {
                return null;
            }
            det = 1.0 / det;

            const result = [16]Scalar{
                (a11 * b11 - a12 * b10 + a13 * b09) * det, // 0
                (a02 * b10 - a01 * b11 - a03 * b09) * det, // 1
                (a31 * b05 - a32 * b04 + a33 * b03) * det, // 2
                (a22 * b04 - a21 * b05 - a23 * b03) * det, // 3
                (a12 * b08 - a10 * b11 - a13 * b07) * det, // 4
                (a00 * b11 - a02 * b08 + a03 * b07) * det, // 5
                (a32 * b02 - a30 * b05 - a33 * b01) * det, // 6
                (a20 * b05 - a22 * b02 + a23 * b01) * det, // 7
                (a10 * b10 - a11 * b08 + a13 * b06) * det, // 8
                (a01 * b08 - a00 * b10 - a03 * b06) * det, // 9
                (a30 * b04 - a31 * b02 + a33 * b00) * det, // 10
                (a21 * b02 - a20 * b04 - a23 * b00) * det, // 11
                (a11 * b07 - a10 * b09 - a12 * b06) * det, // 12
                (a00 * b09 - a01 * b07 + a02 * b06) * det, // 13
                (a31 * b01 - a30 * b03 - a32 * b00) * det, // 14
                (a20 * b03 - a21 * b01 + a22 * b00) * det, // 15
            };
            return init(@bitCast([4][4]Scalar, result));
        }


    };
}

pub const Mat2 = Matrix(f32, 2, 2);
pub const Mat3 = Matrix(f32, 3, 3);
pub const Mat4 = Matrix(f32, 4, 4);

pub const Mat2d = Matrix(f64, 2, 2);
pub const Mat3d = Matrix(f64, 3, 3);
pub const Mat4d = Matrix(f64, 4, 4);