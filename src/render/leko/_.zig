   
pub const chunkmesh = @import("chunkmesh.zig").exports;
pub const volume = @import("volume.zig").exports;

pub fn init() !void {
    try chunkmesh.init();
}

pub fn deinit() void {
    chunkmesh.deinit();
}
