const std = @import("std");
const nm = @import("nm");
const util = @import("util");

const Volume = @import("volume.zig").Volume;
const Chunk = @import("chunk.zig").Chunk;
const LekoIndex = @import("chunk.zig").LekoIndex;

const Vec3 = nm.Vec3;
const Vec3i = nm.Vec3i;

const Allocator = std.mem.Allocator;

pub const VolumeManager = struct {

    volume: *Volume,
    allocator: Allocator,

    /// center of the loading zone in chunks
    load_center: Vec3i,
    /// radius in chunks of the loading zone
    load_radius: u32,

    load_thread_group: ChunkLoadThreadGroup,

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator, volume: *Volume) !void {
        self.allocator = allocator;
        self.volume = volume;
        self.load_center = Vec3i.fill(std.math.maxInt(i32));    // garuntee the first load center will be different
        self.load_radius = 4;   // hard code for now
        try self.load_thread_group.init(allocator);
        try self.load_thread_group.spawn();
    }

    pub fn deinit(self: *Self) void {
        self.load_thread_group.join();
        self.load_thread_group.deinit();
    }

    pub fn update(self: *Self, load_center: Vec3) !void {
        const new_center: Vec3i = load_center.floor().add(Vec3.fill(@intToFloat(f32, Chunk.width / 2))).divScalar(@intToFloat(f32, Chunk.width)).cast(i32);
        if (!new_center.eql(self.load_center)) {
            self.load_center = new_center;
            const load_min = new_center.sub(Vec3i.fill(@intCast(i32, self.load_radius)));
            const load_max = new_center.add(Vec3i.fill(@intCast(i32, self.load_radius)));
            var unload_list = std.ArrayList(*Chunk).init(self.allocator);
            var chunks_iter = self.volume.chunks.valueIterator();
            while (chunks_iter.next()) |chunk| {
                const pos = chunk.*.position;
                if (
                    (pos.v[0] < load_min.v[0] or pos.v[0] >= load_max.v[0]) or
                    (pos.v[1] < load_min.v[1] or pos.v[1] >= load_max.v[1]) or
                    (pos.v[2] < load_min.v[2] or pos.v[2] >= load_max.v[2])
                ) {
                    // std.log.info("unload chunk {}", .{pos});
                    try unload_list.append(chunk.*);
                }
            }
            for (unload_list.items) |chunk| {
                self.volume.deleteChunk(chunk.position);
            }
            unload_list.deinit();
            var x = load_min.v[0];
            while (x < load_max.v[0]) : (x += 1) {
                var y = load_min.v[1];
                while (y < load_max.v[1]) : (y += 1) {
                    var z = load_min.v[2];
                    while (z < load_max.v[2]) : (z += 1) {
                        const pos = Vec3i.init(.{x, y, z});
                        if (!self.volume.chunks.contains(pos)) {
                            const chunk = try self.volume.createChunk(pos);
                            // std.log.info("load chunk {}", .{pos});
                            chunk.state = .loading;
                            try self.load_thread_group.submitChunk(chunk);
                        }
                    }
                }
            }
        }
    }

};

const ChunkLoadThreadGroup = struct {

    allocator: Allocator,
    thread_group: ThreadGroup,

    const ThreadGroup = util.ThreadGroup(*Chunk);

    const Self = @This();

    fn init(self: *Self, allocator: Allocator) !void {
        self.allocator = allocator;
        try self.thread_group.init(allocator, processChunk, 1, 1024);
    }

    fn deinit(self: *Self) void {
        self.thread_group.deinit(self.allocator);
    }

    fn spawn(self: *Self) !void {
        try self.thread_group.spawn(.{});
    }

    fn join(self: *Self) void {
        self.thread_group.join();
    }

    fn submitChunk(self: *Self, chunk: *Chunk) !void {
        try self.thread_group.submitItem(chunk);
    }

    fn processChunk(thread_group: *ThreadGroup, chunk: *Chunk, _: usize) !void {
        // std.log.info("thread {} generate chunk {}", .{thread_index, chunk.*.position});
        const self = @fieldParentPtr(Self, "thread_group", thread_group);
        _ = self;
        const perlin = nm.noise.Perlin3{};
        const scale: f32 = 0.1;
        for (chunk.id_array.items) |*id, i| {
            const index = LekoIndex.initI(i);
            const pos = chunk.position.mulScalar(Chunk.width).add(index.vector().cast(i32)).cast(f32);
            const sample = perlin.sample(pos.mulScalar(scale).v);
            if (sample > 0) {
                id.* = 1;
            }
            else {
                id.* = 0;
            }
        }
        chunk.state = .active;
    }

};