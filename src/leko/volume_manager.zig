const std = @import("std");
const nm = @import("nm");
const util = @import("util");

const Volume = @import("volume.zig").Volume;
const Chunk = @import("chunk.zig").Chunk;
const LekoIndex = @import("chunk.zig").LekoIndex;

const callback = @import("callback.zig");
const config = @import("config.zig").volume_manager;

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;

const Allocator = std.mem.Allocator;


pub const VolumeManager = struct {

    allocator: Allocator,
    volume: *Volume,

    /// center of the loading zone in chunks
    load_center: Vec3i,
    /// radius in chunks of the loading zone
    load_radius: u32 = config.load_radius,

    load_thread_group: ChunkThreadGroup = undefined,

    loaded_chunk_queue: ChunkAtomicQueue,
    callback_chunk_loaded: ?*callback.ChunkCallback = null,
    callback_chunk_unloaded: ?*callback.ChunkCallback = null,

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator, volume: *Volume) !void {
        self.* = .{
            .allocator = allocator,
            .volume = volume,
            .load_center = Vec3i.fill(std.math.maxInt(i32)),    // garuntee the first load center will be different
            .loaded_chunk_queue = try ChunkAtomicQueue.init(allocator),
        };
        try self.load_thread_group.init(allocator, config.load_group_config, processLoadChunk);
        try self.load_thread_group.spawn(.{});
    }

    pub fn deinit(self: *Self) void {
        self.load_thread_group.join();
        self.load_thread_group.deinit(self.allocator);
        self.loaded_chunk_queue.deinit();
    }

    pub fn update(self: *Self, load_center: Vec3) !void {
        const chunk_center = comptime Vec3.fill(@intToFloat(f32, Chunk.width / 2));
        const chunk_width = @intToFloat(f32, Chunk.width);
        const new_center: Vec3i = (
            load_center.floor()
            .add(chunk_center)
            .divScalar(chunk_width)
            .floor().cast(i32)
        );
        if (!new_center.eql(self.load_center)) {
            self.load_center = new_center;
            const load_min = new_center.sub(Vec3i.fill(@intCast(i32, self.load_radius)));
            const load_max = new_center.add(Vec3i.fill(@intCast(i32, self.load_radius)));
            var chunk_list = std.ArrayList(*Chunk).init(self.allocator);
            defer chunk_list.deinit();
            var chunks_iter = self.volume.chunks.valueIterator();
            while (chunks_iter.next()) |chunk| {
                const pos = chunk.*.position;
                if (
                    (pos.v[0] < load_min.v[0] or pos.v[0] >= load_max.v[0]) or
                    (pos.v[1] < load_min.v[1] or pos.v[1] >= load_max.v[1]) or
                    (pos.v[2] < load_min.v[2] or pos.v[2] >= load_max.v[2])
                ) {
                    try chunk_list.append(chunk.*);
                }
            }
            for (chunk_list.items) |chunk| {
                if (self.callback_chunk_unloaded) |callback_chunk_unloaded| {
                    try callback_chunk_unloaded.call(chunk);
                }
                self.volume.deactivateChunk(chunk.position);
            }
            chunk_list.clearRetainingCapacity();
            var x = load_min.v[0];
            while (x < load_max.v[0]) : (x += 1) {
                var y = load_min.v[1];
                while (y < load_max.v[1]) : (y += 1) {
                    var z = load_min.v[2];
                    while (z < load_max.v[2]) : (z += 1) {
                        const pos = Vec3i.init(.{x, y, z});
                        if (!self.volume.chunks.contains(pos)) {
                            const chunk = try self.volume.activateChunk(pos);
                            chunk.state = .loading;
                            try chunk_list.append(chunk);
                        }
                    }
                }
            }
            try self.load_thread_group.submitItems(chunk_list.items);
        }
        while (self.loaded_chunk_queue.dequeue()) |chunk| {
            if (self.callback_chunk_loaded) |callback_chunk_loaded| {
                try callback_chunk_loaded.call(chunk);
            }
        }
    }

    fn processLoadChunk(group: *ChunkThreadGroup, chunk: *Chunk, _: usize) !void {
        const self = @fieldParentPtr(Self, "load_thread_group", group);
        const perlin = nm.noise.Perlin3(null){};
        const scale: f32 = 0.025;
        for (chunk.id_array.items) |*id, i| {
            const index = LekoIndex.initI(i);
            const pos = chunk.position.mulScalar(Chunk.width).add(index.vector().cast(i32)).cast(f32);
            const sample = perlin.sample(pos.mulScalar(scale).v);
            if (sample > 0.25) {
                id.* = 1;
            }
            else {
                id.* = 0;
            }
        }
        chunk.state = .active;
        try self.loaded_chunk_queue.enqueue(chunk);
    }

};

pub const ChunkThreadGroup = util.ThreadGroup(*Chunk);
pub const ChunkAtomicQueue = util.AtomicQueue(*Chunk);