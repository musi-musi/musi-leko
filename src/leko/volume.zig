const std = @import("std");
const nm = @import("nm");

const chunk_ = @import("chunk.zig");
const util = @import("util");

const Chunk = chunk_.Chunk;

const Vec3i = nm.Vec3i;
const vec3i = nm.vec3i;

const Allocator = std.mem.Allocator;

const Cardinal3 = nm.Cardinal3;

pub const Volume = struct {

    allocator: Allocator,
    chunks: Chunks,
    chunk_pool: ChunkPool,

    pub const Chunks = ChunkPosHashMap(*Chunk);

    pub const ChunkPool = util.Pool(Chunk);

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator, initial_chunk_capacity: usize) !void  {
        self.allocator = allocator;
        self.chunks = Chunks.init(allocator);
        try self.chunk_pool.init(allocator, initial_chunk_capacity);
    }

    pub fn deinit(self: *Self) void {
        var chunks = self.chunks.valueIterator();
        while (chunks.next()) |chunk| {
            chunk.*.deinit();
            self.chunk_pool.checkIn(chunk.*);
        }
        self.chunks.deinit();
        self.chunk_pool.deinit();
    }

    pub fn activateChunk(self: *Self, chunk_pos: Vec3i) !*Chunk {
        if (self.chunks.get(chunk_pos)) |existing| {
            return existing;
        }
        else {
            const chunk = try self.chunk_pool.checkOutOrAlloc();
            chunk.init(chunk_pos);
            try self.chunks.put(chunk_pos, chunk);
            inline for (comptime std.enums.values(Cardinal3)) |direction| {
                const neighbor_pos = chunk_pos.add(Vec3i.unitSigned(direction));
                if (self.chunks.get(neighbor_pos)) |neighbor| {
                    chunk.neighbors[@enumToInt(direction)] = neighbor;
                    neighbor.neighbors[@enumToInt(comptime direction.neg())] = chunk;
                }
            }
            return chunk;
        }
    }

    pub fn deactivateChunk(self: *Self, chunk_pos: Vec3i) void {
        if (self.chunks.get(chunk_pos)) |chunk| {
            inline for (comptime std.enums.values(Cardinal3)) |direction| {
                if (chunk.neighbor(direction)) |neighbor| {
                    neighbor.neighbors[@enumToInt(comptime direction.neg())] = null;
                }
            }
            _ = self.chunks.remove(chunk_pos);
            chunk.deinit();
            self.chunk_pool.checkIn(chunk);
        }
    }

};

pub fn ChunkPosHashMap(comptime V: type) type {
    return std.HashMap(Vec3i, V, ChunkPosHashContext, 80);
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