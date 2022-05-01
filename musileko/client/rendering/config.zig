pub const TextureUnit = enum(i32) {
    noise_array = 1,
    g_buffer_start = 2,

    const Self = @This();

    pub fn int(self: Self) i32 {
        return @enumToInt(self);
    }
};