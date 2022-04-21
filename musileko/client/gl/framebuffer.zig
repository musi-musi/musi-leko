const std = @import("std");
const gl = @import(".zig");
const client = @import("../.zig");
const c = client.c;

const PixelFormat = gl.PixelFormat;
const PixelComponent = gl.PixelComponent;

pub fn Framebuffer(comptime color_formats_: []const PixelFormat, comptime depth_component_: ?PixelComponent) type {
    return struct {

        handle: c_uint,

        pub const color_formats = color_formats_;
        pub const depth_component = depth_component_;
        pub const depth_format: ?PixelFormat = (
            if (depth_component) |dc| (
                PixelFormat{ .channels = .depth, .component = dc }
            )
            else (
                null
            )
        );

        pub fn ColorTexture(comptime index: usize) type {
            return gl.Texture(.texture_2d, color_formats[index]);
        }

        pub const DepthTexture: type = (
            if (depth_format) |df| (
                gl.Texture(.texture_2d, df)
            )
            else (
                void
            )
        );

        const Self = @This();

        pub fn init() Self {
            var handle: c_uint = undefined;
            c.glCreateFramebuffers(1, &handle);
            return .{
                .handle = handle,
            };
        }

        pub fn deinit(self: Self) void {
            c.glDeleteFramebuffers(1, &self.handle);
        }

        pub fn attachColor(self: Self, comptime index: usize, texture: ColorTexture(index)) void {
            c.glNamedFramebufferTexture(self.handle, c.GL_COLOR_ATTACHMENT0 + index, texture.handle, 0);
        }

        pub fn attachDepth(self: Self, texture: DepthTexture) void {
            c.glNamedFramebufferTexture(self.handle, c.GL_DEPTH_ATTACHMENT, texture.handle, 0);
        }

        pub fn bind(self: Self) void {
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.handle);

            comptime var attachments: [color_formats.len]c_uint = undefined;
            comptime for (attachments) |*attachment, i| {
                attachment.* = c.GL_COLOR_ATTACHMENT0 + i;
            };
            c.glDrawBuffers(attachments.len, &attachments);
        }

        pub fn clearColor(self: Self, comptime index: usize, value: color_formats[index].Pixel()) void {
            self.clearBuffer(index, color_formats[index], value);
        }

        pub fn clearDepth(self: Self, value: depth_component.?.Type()) void {
            self.clearBuffer(0, depth_format.?, .{value});
        }

        fn clearBuffer(_: Self, comptime index: usize, comptime format: PixelFormat, value: format.Pixel()) void {
            const array_len = switch(format.channels) {
                .depth => 1,
                else => 4,
            };
            const buffer_type = switch(format.channels) {
                .depth => c.GL_DEPTH,
                else => c.GL_COLOR,
            };
            const element_type = switch (format.component) {
                .u8norm, .u8, .u16norm, .u16, .u32 => c_uint,
                .i8norm, .i8, .i16norm, .i16, .i32 => c_int,
                .f32 => f32,
            };
            var a = std.mem.zeroes([array_len]element_type);
            for (value) |v, i| {
                a[i] = switch (element_type) {
                    f32 => @floatCast(f32, v),
                    c_uint => @intCast(c_uint, v),
                    c_int => @intCast(c_int, v),
                    else => unreachable,
                };
            }
            switch (element_type) {
                c_uint => c.glClearBufferuiv(buffer_type, index, &a),
                c_int => c.glClearBufferiv(buffer_type, index, &a),
                f32 => c.glClearBufferfv(buffer_type, index, &a),
                else => unreachable,
            }
        }

        pub fn blit(
            self: Self, target_handle: c_uint,
            src_pos: [2]c_int, src_size: [2]c_int,
            des_pos: [2]c_int, des_size: [2]c_int,
            mask: FramebufferBlitMask,
            filter: gl.TextureFilter,
        ) void {
            c.glBlitNamedFramebuffer(
                self.handle, target_handle,
                src_pos[0], src_pos[1],
                src_size[0], src_size[1],
                des_pos[0], des_pos[1],
                des_size[0], des_size[1],
                @enumToInt(mask),
                @enumToInt(filter),
            );
        }

    };

}

pub const FramebufferBlitMask = enum(c_uint) {
    color = c.GL_COLOR_BUFFER_BIT,
    depth = c.GL_DEPTH_BUFFER_BIT,
    stencil = c.GL_STENCIL_BUFFER_BIT,
    color_depth = c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT,
    color_stencil = c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
    depth_stencil = c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
    color_depth_stencil = c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT,
};

pub fn bindDefaultFramebuffer() void {
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
}
