const std = @import("std");
const nm = @import("nm");

const leko = @import("_.zig");

const Chunk = leko.Chunk;
const Volume = leko.Volume;
const Address = leko.Address;
const Reference = leko.Reference;

const Axis3 = nm.Axis3;
const Cardinal3 = nm.Cardinal3;
const Vec3 = nm.Vec3;
const Vec3u = nm.Vec3u;
const Vec3i = nm.Vec3i;
const Bounds3 = nm.Bounds3;
const Range3i = nm.Range3i;

const m = std.math;

pub const CollisionState = enum {
    nonsolid,
    solid,
};

pub fn collisionState(reference: Reference) CollisionState {
    return switch (reference.chunk.id_array.get(reference.address)) {
        0 => .nonsolid,
        else => .solid,
    };
}

/// check if any solid leko are within `range`
/// unloaded chunks are considered completely solid
pub fn checkSolidInRange(volume: *Volume, range: Range3i) bool {
    const min = range.min;
    const max = range.max;
    var pos = min;
    while (pos.v[0] < max.v[0]) : (pos.v[0] += 1) {
        pos.v[1] = min.v[1];
        while (pos.v[1] < max.v[1]) : (pos.v[1] += 1) {
            pos.v[2] = min.v[2];
            while (pos.v[2] < max.v[2]) : (pos.v[2] += 1) {
                // NOTE: this does a chunk lookup for each position. we can do better, but this works for now
                if (Reference.initGlobalPosition(volume, pos)) |reference| {
                    if (collisionState(reference) == .solid) {
                        return true;
                    }
                }
                else {
                    // unloaded chunks are solid
                    return true;
                }
            }
        }
    }
    return false;
}

/// check if any leko on the face of a range are solid
/// used to check if a bounding box can move in that direction
pub fn checkSolidInRangeMove(volume: *Volume, range: Range3i, comptime move: Cardinal3) bool {
    const axis = comptime move.axis();
    const u = @intToEnum(Axis3, (@intCast(u32, @enumToInt(axis)) + 1) % 3);
    const v = @intToEnum(Axis3, (@intCast(u32, @enumToInt(axis)) + 2) % 3);
    const move_position = switch(comptime move.sign()) {
        .positive => range.max.get(axis),
        .negative => range.min.get(axis) - 1,
    };
    var min: Vec3i = undefined;
    min.set(u, range.min.get(u));
    min.set(v, range.min.get(v));
    min.set(axis, move_position);
    var max: Vec3i = undefined;
    max.set(u, range.max.get(u));
    max.set(v, range.max.get(v));
    max.set(axis, move_position + 1);
    return checkSolidInRange(volume, Range3i.init(min.v, max.v));
}

/// try to move `bounds` `move` units along `axis`
/// if no collision occurs, `null` is returned
/// if collision occurs, return the actual distance moved
pub fn moveBoundsAxis(volume: *Volume, bounds: *Bounds3, move: f32, comptime axis: Axis3) ?f32 {
    const sign: nm.Sign = if (move < 0) .negative else .positive;
    // const incr = sign.scalar(i32);
    const incr_float = sign.scalar(f32);
    const direction_pos = comptime Cardinal3.init(axis, .positive);
    const direction_neg = comptime Cardinal3.init(axis, .negative);
    var range: Range3i = undefined;
    const start_center = bounds.center;
    range.min = bounds.min().floor().cast(i32);
    range.max = bounds.max().ceil().cast(i32);
    var remaining = move;
    const edge_dist = switch (sign) {
        .positive => @intToFloat(f32, range.max.get(axis)) - bounds.max().get(axis),
        .negative => @intToFloat(f32, range.min.get(axis)) - bounds.min().get(axis),
    };
    if (m.signbit(edge_dist) == m.signbit(remaining)) {
        remaining -= edge_dist;
        while (m.absFloat(remaining) > 0 and m.signbit(move) == m.signbit(remaining)) {
            const space_occupied = switch(sign) {
                .positive => checkSolidInRangeMove(volume, range, direction_pos),
                .negative => checkSolidInRangeMove(volume, range, direction_neg),
            };
            if (space_occupied) {
                // handle collision
                const new_position = switch (sign) {
                    .positive => @intToFloat(f32, range.max.get(axis)) - bounds.radius.get(axis),
                    .negative => @intToFloat(f32, range.min.get(axis)) + bounds.radius.get(axis),
                };
                const delta = new_position - bounds.center.get(axis);
                std.log.debug("{s} delta: {}!", .{@tagName(axis), delta});
                bounds.center.set(axis, new_position);
                return delta;
            }
            else {
                bounds.center.ptrMut(axis).* += incr_float;
                range.min = bounds.min().floor().cast(i32);
                range.max = bounds.max().ceil().cast(i32);
                remaining -= incr_float;
            }
        }
    }
    bounds.center = start_center;
    bounds.center.ptrMut(axis).* += move;
    return null;
}