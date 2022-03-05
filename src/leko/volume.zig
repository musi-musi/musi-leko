const std = @import("std");
const nm = @import("nm");

const chunk = @import("chunk.zig");

const Chunk = chunk.Chunk;

const Vec3i = nm.Vec3i;
const vec3i = nm.vec3i;

const Allocator = std.mem.Allocator;

pub const Volume = struct {

};

pub fn ChunkPosHashMap(comptime V: type) type {
    return std.HashMapUnmanaged(Vec3i, V, ChunkPosHashContext, 80);
}

const ChunkPosHashContext = struct {
    
    const Self = @This();

    pub fn hash(_: Self, chunk_pos: Vec3i) u64 {
        return (
            0xF9E0_B182_EF07_AABE ^ (@intCast(u64, @bitCast(u32, chunk_pos.v[0])) << 32) ^
            0x0BB4_2282_BBFF_C67C ^ (@intCast(u64, @bitCast(u32, chunk_pos.v[1])) << 16) ^
            0xCBA4_882E_ACF3_006C ^ (@intCast(u64, @bitCast(u32, chunk_pos.v[2])))
        );
    }

    pub fn eql(_: Self, a: Vec3i, b: Vec3i) bool {
        return a.eql(b);
    }

};