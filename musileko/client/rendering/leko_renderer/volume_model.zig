const std = @import("std");


const leko_renderer = @import("_.zig");
const chunk_mesh = leko_renderer.chunk_mesh;

const rendering = @import("../_.zig");

const engine = @import("../../../engine/_.zig");
const leko = engine.leko;

const client = @import("../../_.zig");

const nm = client.nm;
const util = client.util;

const Volume = leko.Volume;
const Chunk = leko.Chunk;
const ChunkMesh = leko_renderer.ChunkMesh;

const Allocator = std.mem.Allocator;

const Vec3i = nm.Vec3i;

const volume_manager_config = leko.config.volume_manager;

pub const volume_model = struct {

    pub fn init() !void {
        try chunk_mesh.init();
    }

    pub fn deinit() void {
        chunk_mesh.deinit();
    }

    pub fn setViewMatrix(view: nm.Mat4) void {
        chunk_mesh.setViewMatrix(view);
    }

    pub fn startDraw() void {
        chunk_mesh.startDraw();
    }

    pub fn drawModel(model: *const VolumeModel) void {
        var meshes = model.meshes.valueIterator();
        while (meshes.next()) |mesh| {
            chunk_mesh.bindMesh(mesh.*);
            chunk_mesh.drawMesh(mesh.*);
        }
    }
};


pub const VolumeModel = struct {

    volume: *const Volume,
    allocator: Allocator,
    meshes: ChunkMeshes,
    mesh_pool: ChunkMeshPool,

    pub const ChunkMeshes = leko.ChunkPosHashMap(*ChunkMesh);
    pub const ChunkMeshPool = util.Pool(ChunkMesh);

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator, volume: *const Volume) !void {
        self.allocator = allocator;
        self.volume = volume;
        self.meshes = ChunkMeshes.init(allocator);
        try self.mesh_pool.init(allocator, 0);
    }

    pub fn deinit(self: *Self) void {
        var meshes = self.meshes.valueIterator();
        while (meshes.next()) |mesh| {
            mesh.*.deinit(self.allocator);
            self.mesh_pool.checkIn(mesh.*);
        }
        self.meshes.deinit();
        self.mesh_pool.deinit();
    }

    fn activateChunkMesh(self: *Self, chunk: *Chunk) !*ChunkMesh {
        const position = chunk.*.position;
        if (self.meshes.get(position)) |existing| {
            return existing;
        }
        else {
            var mesh: *ChunkMesh = undefined;
            if (self.mesh_pool.checkOut()) |m| {
                mesh = m;
                mesh.clear();
                mesh.chunk = chunk;
            }
            else {
                mesh = try self.mesh_pool.alloc();
                mesh.init(chunk);
            }
            try self.meshes.put(position, mesh);
            return mesh;
        }
    }

    fn deactivateChunkMesh(self: *Self, position: Vec3i) void {
        if (self.meshes.get(position)) |mesh| {
            mesh.*.state = .inactive;
            _ = self.meshes.remove(position);
            self.mesh_pool.checkIn(mesh);
        }
    }


};

pub const VolumeModelManager = struct {
    
    allocator: Allocator,
    model: *VolumeModel,
    
    generate_thread_group: ChunkMeshGenerateThreadGroup = undefined,
    
    mesh_upload_queue: ChunkMeshAtomicQueue = undefined,

    listener_chunk_loaded: leko.ChunkEvent.Listener,
    listener_chunk_unloaded: leko.ChunkEvent.Listener,

    const ChunkMeshAtomicQueue = util.AtomicQueue(*ChunkMesh);
    const ChunkMeshGenerateThreadGroup = util.ThreadGroup(ChunkMeshGenerateJob);

    const ChunkMeshGenerateJob = struct {
        mesh: *ChunkMesh,
        parts: ChunkMesh.Parts,
        

    };

    const Self = @This();

    const load_radius = volume_manager_config.load_radius;
    const generate_group_config = util.ThreadGroupConfig {
        .thread_count = .{
            .cpu_factor = 0.75, 
        },
    };

    pub fn init(self: *Self, allocator: Allocator, model: *VolumeModel) !void {
        self.* = .{
            .allocator = allocator,
            .model = model,
            .mesh_upload_queue = try ChunkMeshAtomicQueue.init(allocator),
            .listener_chunk_loaded = leko.ChunkEvent.Listener.init(callbackChunkLoaded),
            .listener_chunk_unloaded = leko.ChunkEvent.Listener.init(callbackChunkUnloaded),
        };
        try self.generate_thread_group.init(allocator, generate_group_config, processGenerateMesh);
        try self.generate_thread_group.spawn(.{});
    }

    pub fn deinit(self: *Self) void {
        self.generate_thread_group.join();
        self.generate_thread_group.deinit(self.allocator);
        self.mesh_upload_queue.deinit();
    }

    pub fn uploadGeneratedMeshes(self: *Self) void {
        while (self.mesh_upload_queue.dequeue()) |mesh| {
            if (mesh.state == .active) {
                mesh.uploadData();
            }
        }
    }

    fn callbackChunkUnloaded(callback: *leko.ChunkEvent.Listener, chunk: *Chunk) !void {
        const self = @fieldParentPtr(Self, "listener_chunk_unloaded", callback);
        self.model.deactivateChunkMesh(chunk.position);
    }

    fn callbackChunkLoaded(callback: *leko.ChunkEvent.Listener, chunk: *Chunk) !void {
        const self = @fieldParentPtr(Self, "listener_chunk_loaded", callback);
        const mesh = try self.model.activateChunkMesh(chunk);
        try self.generate_thread_group.submitItem(.{
            .mesh = mesh,
            .parts = .middle_border,
        });

        const position = chunk.*.position;
        const model = self.model;

        const offsets = [3]i32{-1, 0, 1};
        inline for (offsets) |x| {
            inline for (offsets) |y| {
                inline for (offsets) |z| {
                    const offset = comptime Vec3i.init(.{x, y, z});
                    if (comptime !offset.eql(Vec3i.zero)) {
                        const neighbor_position = position.add(offset);
                        if (model.meshes.get(neighbor_position)) |neighbor_mesh| {
                            neighbor_mesh.state = .generating;
                            try self.generate_thread_group.submitItem(.{
                                .mesh = neighbor_mesh,
                                .parts = .border,
                            });
                        }
                    }
                }
            }
        }
    }

    fn processGenerateMesh(group: *ChunkMeshGenerateThreadGroup, job: ChunkMeshGenerateJob, _: usize) !void {
        const self = @fieldParentPtr(Self, "generate_thread_group", group);
        job.mesh.*.mutex.lock();
        defer job.mesh.*.mutex.unlock();
        job.mesh.*.state = .generating;
        try job.mesh.generateData(self.allocator, job.parts);
        job.mesh.*.state = .active;
        try self.*.mesh_upload_queue.enqueue(job.mesh);
    }

};