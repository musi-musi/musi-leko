const std = @import("std");
const gl = @import("_.zig");
const client = @import("../_.zig");
const c = client.c;

pub fn TextureRgba8(comptime target_: TextureTarget) type {
    return Texture(target_, .{
        .channels = .rgba,
        .component = .byte,
    });
}

pub fn Texture(comptime target_: TextureTarget, comptime format_: PixelFormat) type {
    return struct {
        
        handle: c_uint,

        pub const target = target_;
        pub const format = format_;

        pub const Pixel = format.Pixel();

        const Self = @This();

        pub fn init() Self {
            var handle: c_uint = undefined;
            c.glCreateTextures(@enumToInt(target), 1, &handle);
            return .{
                .handle = handle,
            };
        }

        pub fn deinit(self: Self) void {
            c.glDeleteTextures(1, &self.handle);
        }

        pub fn bind(self: Self, unit: c_uint) void {
            c.glBindTextureUnit(unit, self.handle);
        }

        pub fn setFilter(self: Self, min_filter: TextureFilter, mag_filter: TextureFilter) void {
            c.glTextureParameteri(self.handle, c.GL_TEXTURE_MIN_FILTER, @enumToInt(min_filter));
            c.glTextureParameteri(self.handle, c.GL_TEXTURE_MAG_FILTER, @enumToInt(mag_filter));
        }

        pub usingnamespace switch (target) {
            .texture_2d => struct {
                
                pub fn alloc(self: Self, width: usize, height: usize) void {
                    const w = @intCast(c_int, width);
                    const h = @intCast(c_int, height);
                    c.glTextureStorage2D(self.handle, 1, comptime format.sizedFormat(), w, h);
                }

                pub fn upload(self: Self, width: usize, height: usize, data: []const Pixel) void {
                    const w = @intCast(c_int, width);
                    const h = @intCast(c_int, height);
                    const x: c_int = 0;
                    const y: c_int = 0;
                    const mip: c_int = 0;
                    const channels = @enumToInt(format.channels);
                    const component = @enumToInt(format.component);
                    c.glTextureSubImage2D(self.handle, mip, x, y, w, h, channels, component, @ptrCast(*const anyopaque, data.ptr));
                }

            },
            .array_2d => struct {
                
                pub fn alloc(self: Self, width: usize, height: usize, count: usize) void {
                    const w = @intCast(c_int, width);
                    const h = @intCast(c_int, height);
                    const cnt = @intCast(c_int, count);
                    c.glTextureStorage3D(self.handle, 1, comptime format.sizedFormat(), w, h, cnt);
                }

                pub fn upload(self: Self, width: usize, height: usize, index: usize, data: []const Pixel) void {
                    const w = @intCast(c_int, width);
                    const h = @intCast(c_int, height);
                    const i = @intCast(c_int, index);
                    const x: c_int = 0;
                    const y: c_int = 0;
                    const mip: c_int = 0;
                    const channels = @enumToInt(format.channels);
                    const component = @enumToInt(format.component);
                    c.glTextureSubImage2D(self.handle, mip, x, y, i, w, h, 1, channels, component, @ptrCast(*const anyopaque, data.ptr));
                }

            },
        };

    };
}

pub const TextureTarget = enum(c_uint) {
    texture_2d = c.GL_TEXTURE_2D,
    array_2d = c.GL_TEXTURE_2D_ARRAY,

    const Self = @This();

    pub fn isArray(self: Self) bool {
        return switch (self) {
            .texture_2d => false,
            .array_2d => true,
        };
    }

    pub fn dimensions(self: Self) u32 {
        return switch (self) {
            .texture_2d => 2,
            .array_2d => 3,
        };
    }

};

pub const TextureFilter = enum(c_int) {
    nearest = c.GL_NEAREST,
    linear = c.GL_LINEAR,
};

pub const PixelFormat = struct {

    channels: PixelChannels = .rgba,
    component: PixelComponent = .byte,

    const Self = @This();

    pub fn Pixel(comptime self: Self) type {
        return [self.channels.dimensions()]self.component.Type();
    }

    pub fn sizedFormat(comptime self: Self) c_uint {
        return switch (self.channels) {
            .r => switch (self.component) {
                .byte => @as(c_uint, c.GL_R8),
                .signed_byte => @as(c_uint, c.GL_R8_SNORM),
                .short => @as(c_uint, c.GL_R16),
                .signed_short => @as(c_uint, c.GL_R16_SNORM),
                .float => @as(c_uint, c.GL_R32F),
            },
            .rg => switch (self.component) {
                .byte => @as(c_uint, c.GL_RG8),
                .signed_byte => @as(c_uint, c.GL_RG8_SNORM),
                .short => @as(c_uint, c.GL_RG16),
                .signed_short => @as(c_uint, c.GL_RG16_SNORM),
                .float => @as(c_uint, c.GL_RG32F),
            },
            .rgb => switch (self.component) {
                .byte => @as(c_uint, c.GL_RGB8),
                .signed_byte => @as(c_uint, c.GL_RGB8_SNORM),
                // .short => @as(c_uint, c.GL_RGB16),
                .short => @compileError("no 16 bit unsigned rgb format"),
                .signed_short => @as(c_uint, c.GL_RGB16_SNORM),
                .float => @as(c_uint, c.GL_RGB32F),
            },
            .rgba => switch (self.component) {
                .byte => @as(c_uint, c.GL_RGBA8),
                .signed_byte => @as(c_uint, c.GL_RGBA8_SNORM),
                .short => @as(c_uint, c.GL_RGBA16),
                .signed_short => @as(c_uint, c.GL_RGBA16_SNORM),
                .float => @as(c_uint, c.GL_RGBA32F),
            },
        };
    }

};

pub const PixelChannels = enum(c_uint) {
    r = c.GL_RED,
    rg = c.GL_RG,
    rgb = c.GL_RGB,
    rgba = c.GL_RGBA,

    const Self = @This();

    pub fn fromDimensions(dims: u32) Self {
        return switch (dims) {
            1 => .r,
            2 => .rg,
            3 => .rgb,
            4 => .rgba,
            else => .rgba,
        };
    }

    pub fn dimensions(self: Self) u32 {
        return switch(self) {
            .r => 1,
            .rg => 2,
            .rgb => 3,
            .rgba => 4,
        };
    }

};

pub const PixelComponent = enum(c_uint) {
    byte = c.GL_UNSIGNED_BYTE,
    signed_byte = c.GL_BYTE,
    short = c.GL_UNSIGNED_SHORT,
    signed_short = c.GL_SHORT,
    float = c.GL_FLOAT,

    const Self = @This();

    pub fn Type(comptime self: Self) type {
        return switch(self) {
            .byte => u8,
            .signed_byte => i8,
            .short => u16,
            .signed_short => i16,
            .float => f32,
        };
    }
};