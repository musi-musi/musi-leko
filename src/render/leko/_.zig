   
pub const chunk_mesh = @import("chunk_mesh.zig").exports;
pub const volume = @import("volume.zig").exports;

pub fn init() !void {
    try chunk_mesh.init();
}

pub fn deinit() void {
    chunk_mesh.deinit();
}
