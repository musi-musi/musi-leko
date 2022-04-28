const std = @import("std");
const gl = @import(".zig");
const client = @import("../.zig");
const c = client.c;

pub fn TextureRgba8(comptime target_: TextureTarget) type {
    return Texture(target_, .{
        .channels = .rgba,
        .component = .u8norm,
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
            c.glTextureParameteri(self.handle, c.GL_TEXTURE_MIN_FILTER, @intCast(c_int, @enumToInt(min_filter)));
            c.glTextureParameteri(self.handle, c.GL_TEXTURE_MAG_FILTER, @intCast(c_int, @enumToInt(mag_filter)));
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
                    const channels = format.channels.glType();
                    const component = format.component.glType();
                    c.glTextureSubImage2D(self.handle, mip, x, y, w, h, channels, component, @ptrCast(*const anyopaque, data.ptr));
                }

                /// allocate for framebuffer usage
                pub fn allocFramebuffer(self: Self, width: usize, height: usize) void {
                    // const w = @intCast(c_int, width);
                    // const h = @intCast(c_int, height);
                    // const mip: c_int = 0;
                    // const channels = format.channels.glType();
                    // const component = format.component.glType();
                    // c.glTextureImage2D(self.handle, mip, comptime format.sizedFormat(), w, h, 0, channels, component, null);
                    self.alloc(width, height);
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
                    const channels = format.channels.glType();
                    const component = format.component.glType();
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

pub const TextureFilter = enum(c_uint) {
    nearest = c.GL_NEAREST,
    linear = c.GL_LINEAR,
};

pub const PixelFormat = struct {
    channels: PixelChannels = .rgba,
    component: PixelComponent = .u8norm,

    const Self = @This();

    pub fn Pixel(comptime self: Self) type {
        return [self.channels.dimensions()]self.component.Type();
    }

    pub fn sizedFormat(comptime self: Self) c_uint {
        return switch (self.channels) {
            .r => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_R8),
                .i8norm => @as(c_uint, c.GL_R8_SNORM),
                .u8 => @as(c_uint, c.GL_R8UI),
                .i8 => @as(c_uint, c.GL_R8I),
                .u16norm => @as(c_uint, c.GL_R16),
                .i16norm => @as(c_uint, c.GL_R16_SNORM),
                .u16 => @as(c_uint, c.GL_R16UI),
                .i16 => @as(c_uint, c.GL_R16I),
                .u32 => @as(c_uint, c.GL_R32UI),
                .i32 => @as(c_uint, c.GL_R32I),
                .f32 => @as(c_uint, c.GL_R32F),
            },
            .rg => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_RG8),
                .i8norm => @as(c_uint, c.GL_RG8_SNORM),
                .u8 => @as(c_uint, c.GL_RG8UI),
                .i8 => @as(c_uint, c.GL_RG8I),
                .u16norm => @as(c_uint, c.GL_RG16),
                .i16norm => @as(c_uint, c.GL_RG16_SNORM),
                .u16 => @as(c_uint, c.GL_RG16UI),
                .i16 => @as(c_uint, c.GL_RG16I),
                .u32 => @as(c_uint, c.GL_RG32UI),
                .i32 => @as(c_uint, c.GL_RG32I),
                .f32 => @as(c_uint, c.GL_RG32F),
            },
            .rgb => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_RGB8),
                .i8norm => @as(c_uint, c.GL_RGB8_SNORM),
                .u8 => @as(c_uint, c.GL_RGB8UI),
                .i8 => @as(c_uint, c.GL_RGB8I),
                .u16norm => @as(c_uint, c.GL_RGB16),
                .i16norm => @as(c_uint, c.GL_RGB16_SNORM),
                .u16 => @as(c_uint, c.GL_RGB16UI),
                .i16 => @as(c_uint, c.GL_RGB16I),
                .u32 => @as(c_uint, c.GL_RGB32UI),
                .i32 => @as(c_uint, c.GL_RGB32I),
                .f32 => @as(c_uint, c.GL_RGB32F),
            },
            .srgb => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_SRGB8),
                else => @compileError("srgb is only valid for byte bit depth"),
            },
            .rgba => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_RGBA8),
                .i8norm => @as(c_uint, c.GL_RGBA8_SNORM),
                .u8 => @as(c_uint, c.GL_RGBA8UI),
                .i8 => @as(c_uint, c.GL_RGBA8I),
                .u16norm => @as(c_uint, c.GL_RGBA16),
                .i16norm => @as(c_uint, c.GL_RGBA16_SNORM),
                .u16 => @as(c_uint, c.GL_RGBA16UI),
                .i16 => @as(c_uint, c.GL_RGBA16I),
                .u32 => @as(c_uint, c.GL_RGBA32UI),
                .i32 => @as(c_uint, c.GL_RGBA32I),
                .f32 => @as(c_uint, c.GL_RGBA32F),
            },
            .srgb_alpha => switch (self.component) {
                .u8norm => @as(c_uint, c.GL_SRGB8_ALPHA8),
                else => @compileError("srgb_alpha is only valid for byte bit depth"),
            },
            .depth => switch (self.component) {
                .u16 => @as(c_uint, c.GL_DEPTH_COMPONENT16),
                .u32 => @as(c_uint, c.GL_DEPTH_COMPONENT32),
                .f32 => @as(c_uint, c.GL_DEPTH_COMPONENT32F),
                else => @compileError("unsupported depth format"),
            },
        };
    }

};

pub const PixelChannels = enum(c_uint) {
    r,
    rg,
    rgb,
    srgb,
    rgba,
    srgb_alpha,
    depth,

    const Self = @This();

    pub fn fromDimensions(dims: u32, srgb: bool) Self {
        return if (!srgb) {
            switch (dims) {
                1 => .r,
                2 => .rg,
                3 => .rgb,
                4 => .rgba,
                else => .rgba,
            }
        } else {
            switch (dims) {
                1 => @compileError("srgb is not supported for channel count 1"),
                2 => @compileError("srgb is not supported for channel count 2"),
                3 => .srgb,
                4 => .srgb_alpha,
                else => .srgb_alpha,
            }
        };
    }

    pub fn dimensions(self: Self) u32 {
        return switch(self) {
            .r => 1,
            .rg => 2,
            .rgb => 3,
            .srgb => 3,
            .rgba => 4,
            .srgb_alpha => 4,
            .depth => 1,
        };
    }

    pub fn glType(comptime self: Self) c_uint {
        return switch(self) {
            .r => c.GL_RED,
            .rg => c.GL_RG,
            .rgb => c.GL_RGB,
            .srgb => c.GL_RGB,
            .rgba => c.GL_RGBA,
            .srgb_alpha => c.GL_RGBA,
            .depth => c.GL_DEPTH_COMPONENT,
        };
    }

};

pub const PixelComponent = enum(c_uint) {
    u8norm,
    i8norm,
    @"u8",
    @"i8",
    @"u16",
    @"i16",
    u16norm,
    i16norm,
    @"u32",
    @"i32",
    @"f32",

    const Self = @This();

    pub fn Type(comptime self: Self) type {
        return switch(self) {
            .u8norm => u8,
            .i8norm => i8,
            .u8 => u8,
            .i8 => i8,
            .u16norm => u16,
            .i16norm => i16,
            .u16 => u16,
            .i16 => i16,
            .u32 => u32,
            .i32 => i32,
            .f32 => f32,
        };
    }

    pub fn glType(comptime self: Self) c_uint {
        return switch(self) {
            .u8norm => c.GL_UNSIGNED_BYTE,
            .i8norm => c.GL_BYTE,
            .u8 => c.GL_UNSIGNED_BYTE,
            .i8 => c.GL_BYTE,
            .u16norm => c.GL_UNSIGNED_SHORT,
            .i16norm => c.GL_SHORT,
            .u16 => c.GL_UNSIGNED_SHORT,
            .i16 => c.GL_SHORT,
            .u32 => c.GL_UNSIGNED_INT,
            .i32 => c.GL_INT,
            .f32 => c.GL_FLOAT,
        };
    }

};
