const std = @import("std");
const nm = @import("nm");
const leko = @import("leko");

const chunkmesh = @import("chunkmesh.zig");

const Volume = leko.Volume;
const Chunk = leko.Chunk;
const ChunkMesh = chunkmesh.Mesh;

const Allocator = std.mem.Allocator;

pub usingnamespace exports;
pub const exports = struct {

    pub fn init() !void {
        try chunkmesh.init();
    }

    pub fn deinit() void {
        chunkmesh.deinit();
    }

    pub fn setViewMatrix(view: nm.Mat4) void {
        chunkmesh.setViewMatrix(view);
    }
    
    pub const Model = struct {

        volume: *const Volume,
        allocator: Allocator,
        chunk_meshes: ChunkMeshes,


        pub const ChunkMeshes = std.ArrayList(*ChunkMesh);

        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator, volume: *const Volume) !void {
            self.allocator = allocator;
            self.volume = volume;
            self.chunk_meshes = ChunkMeshes.init(allocator);
        }

        pub fn deinit(self: *Self) void {
            for (self.chunk_meshes.items) |mesh| {
                mesh.deinit(self.allocator);
                self.allocator.destroy(mesh);
            }
            self.chunk_meshes.deinit();
        }

        pub fn addChunk(self: *Self, chunk: *const Chunk) !void {
            var mesh = try self.allocator.create(ChunkMesh);
            errdefer self.allocator.destroy(mesh);
            mesh.init(chunk);
            errdefer mesh.deinit(self.allocator);
            try mesh.generateData(self.allocator);
            mesh.uploadData();
            try self.chunk_meshes.append(mesh);
        }


        pub fn render(self: Self) void {
            chunkmesh.startDraw();
            for (self.chunk_meshes.items) |mesh| {
                chunkmesh.bindMesh(mesh);
                chunkmesh.drawMesh(mesh);
            }
        }

    };

};
