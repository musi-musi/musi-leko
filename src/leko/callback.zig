const Chunk = @import("chunk.zig").Chunk;

pub const ChunkCallback = struct {

    callback_fn: CallbackFn = noop,

    pub const CallbackFn = fn (*Self, *Chunk) anyerror!void;

    const Self = @This();

    pub fn call(self: *Self, chunk: *Chunk) !void {
        try self.callback_fn(self, chunk);
    }

    fn noop(_: *Self, _: *Chunk) !void {}

};