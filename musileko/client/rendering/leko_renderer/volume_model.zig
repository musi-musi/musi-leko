const std = @import("std");


const leko_renderer = @import(".zig");
const chunk_mesh = leko_renderer.chunk_mesh;

const rendering = @import("../.zig");

const engine = @import("../../../engine/.zig");
const leko = engine.leko;

const client = @import("../../.zig");

const nm = client.nm;
const util = client.util;

const Volume = leko.Volume;
const Chunk = leko.Chunk;
const ChunkMesh = leko_renderer.ChunkMesh;

const Mutex = std.Thread.Mutex;

const Allocator = std.mem.Allocator;

const Vec3i = nm.Vec3i;
const Range3i = nm.Range3i;
const Axis3 = nm.Axis3;
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

    pub fn setProjectionMatrix(proj: nm.Mat4) void {
        chunk_mesh.setProjectionMatrix(proj);
    }

    pub fn startDraw() void {
        chunk_mesh.startDraw();
    }

    pub fn drawModel(model: *VolumeModel) void {
        var meshes = model.meshes.valueIterator();
        model.mutex.lock();
        defer model.mutex.unlock();
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
    mutex: Mutex,

    pub const ChunkMeshes = leko.ChunkPosHashMap(*ChunkMesh);
    pub const ChunkMeshPool = util.Pool(ChunkMesh);

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator, volume: *const Volume) !void {
        self.allocator = allocator;
        self.volume = volume;
        self.meshes = ChunkMeshes.init(allocator);
        self.mutex = Mutex{};
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

    listener_leko_edit: leko.LekoEditEvent.Listener,

    const ChunkMeshAtomicQueue = util.AtomicQueue([]*ChunkMesh);
    const ChunkMeshGenerateThreadGroup = util.ThreadGroup([]ChunkMeshGenerateJob);

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
            .listener_leko_edit = leko.LekoEditEvent.Listener.init(callbackLekoEdit),
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
        while (self.mesh_upload_queue.dequeue()) |meshes| {
            for (meshes) |mesh| {
                if (mesh.state == .active) {
                    mesh.uploadData();
                }
            }
            self.allocator.free(meshes);
        }
    }

    fn callbackChunkUnloaded(listener: *leko.ChunkEvent.Listener, chunk: *Chunk) !void {
        const self = @fieldParentPtr(Self, "listener_chunk_unloaded", listener);
        self.model.mutex.lock();
        defer self.model.mutex.unlock();
        self.model.deactivateChunkMesh(chunk.position);
    }

    fn callbackChunkLoaded(listener: *leko.ChunkEvent.Listener, chunk: *Chunk) !void {
        const self = @fieldParentPtr(Self, "listener_chunk_loaded", listener);
        const model = self.model;
        model.mutex.lock();
        defer model.mutex.unlock();
        const mesh = try model.activateChunkMesh(chunk);
        try self.submitSingleGenerateJob(mesh, .middle_border);
        

        const position = chunk.*.position;

        const offsets = [3]i32{-1, 0, 1};
        inline for (offsets) |x| {
            inline for (offsets) |y| {
                inline for (offsets) |z| {
                    const offset = comptime Vec3i.init(.{x, y, z});
                    if (comptime !offset.eql(Vec3i.zero)) {
                        const neighbor_position = position.add(offset);
                        if (model.meshes.get(neighbor_position)) |neighbor_mesh| {
                            neighbor_mesh.state = .generating;
                            try self.submitSingleGenerateJob(neighbor_mesh, .border);
                        }
                    }
                }
            }
        }
    }

    fn submitSingleGenerateJob(self: *Self, mesh: *ChunkMesh, parts: ChunkMesh.Parts) !void {
        const jobs = try self.allocator.alloc(ChunkMeshGenerateJob, 1);
        jobs[0] = .{
            .mesh = mesh,
            .parts = parts,
        };
        try self.generate_thread_group.submitItem(jobs);
    }

    fn processGenerateMesh(group: *ChunkMeshGenerateThreadGroup, jobs: []ChunkMeshGenerateJob, _: usize) !void {
        const self = @fieldParentPtr(Self, "generate_thread_group", group);
        var upload_list = try self.allocator.alloc(*ChunkMesh, jobs.len);
        for (jobs) |job, i| {
            job.mesh.*.mutex.lock();
            defer job.mesh.*.mutex.unlock();
            job.mesh.*.state = .generating;
            try job.mesh.generateData(self.allocator, job.parts);
            job.mesh.*.state = .active;
            upload_list[i] = job.mesh;
        }
        self.allocator.free(jobs);
        try self.*.mesh_upload_queue.enqueue(upload_list);
    }

    fn callbackLekoEdit(listener: *leko.LekoEditEvent.Listener, edit: leko.LekoEdit) !void {
        const self = @fieldParentPtr(Self, "listener_leko_edit", listener);
        // var job_list = try std.ArrayList(ChunkMeshGenerateJob).initCapacity(self.allocator, 1);
        self.model.mutex.lock();
        const edit_chunk_position = edit.reference.chunk.position;
        defer self.model.mutex.unlock();
        if (self.model.meshes.get(edit_chunk_position)) |edit_mesh| {
            const range_middle_only = Range3i.init([_]i32{2} ** 3, [_]i32{Chunk.width - 2} ** 3);
            const range_middle_border = Range3i.init([_]i32{1} ** 3, [_]i32{Chunk.width - 1} ** 3);
            const local_position = edit.reference.address.localPosition();
            if (range_middle_border.contains(local_position)) {
                // we only need to regenerate the edited chunk's mesh
                if (range_middle_only.contains(local_position)) {
                    try self.submitSingleGenerateJob(edit_mesh, .middle);
                }
                else {
                    try self.submitSingleGenerateJob(edit_mesh, .middle_border);
                }
            }
            else {
                // we need to generate neighbor meshes as well
                var edit_range = Range3i.init(edit_chunk_position.v, edit_chunk_position.add(Vec3i.one).v);
                inline for (comptime std.enums.values(Axis3)) |a| {
                    switch (local_position.get(a)) {
                        0 => edit_range.min.ptrMut(a).* -= 1,
                        Chunk.width - 1 => edit_range.max.ptrMut(a).* += 1,
                        else => {},
                    }
                }
                var job_list = try std.ArrayList(ChunkMeshGenerateJob).initCapacity(self.allocator, 1);
                try job_list.append(.{
                    .mesh = edit_mesh,
                    .parts = .middle,
                });
                var position = edit_range.min;
                while (position.v[0] < edit_range.max.v[0]) : (position.v[0] += 1) {
                    position.v[1] = edit_range.min.v[1];
                    while (position.v[1] < edit_range.max.v[1]) : (position.v[1] += 1) {
                        position.v[2] = edit_range.min.v[2];
                        while (position.v[2] < edit_range.max.v[2]) : (position.v[2] += 1) {
                            if (self.model.meshes.get(position)) |neighbor| {
                                try job_list.append(.{
                                    .mesh = neighbor,
                                    .parts = .border,
                                });
                            }
                        }
                    }
                }
                const jobs = job_list.toOwnedSlice();
                try self.generate_thread_group.submitItem(jobs);

            }
        }
    }

};