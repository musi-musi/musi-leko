const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;

pub const GBuffer = struct {

    framebuffer: Framebuffer,
    textures: Textures,
    width: usize,
    height: usize,

    pub const Framebuffer = gl.Framebuffer(&.{
        gl.PixelFormat { // color
            .channels = .srgb_alpha,
            .component = .u8norm,
        },
        gl.PixelFormat { // outline
            .channels = .rgba,
            .component = .u8norm,
        },
        gl.PixelFormat { // position
            .channels = .rgba,
            .component = .f32,
        },
        gl.PixelFormat { // normal
            .channels = .rgb,
            .component = .u8norm,
        },
        gl.PixelFormat { // uv
            .channels = .rg,
            .component = .f32,
        },
    }, .f32);

    pub const Textures = struct {

        depth: Depth,
        color: Color,
        outline: Outline,
        position: Position,
        normal: Normal,
        uv: Uv,

        pub const Depth = Framebuffer.DepthTexture;
        pub const Color = Framebuffer.ColorTexture(0);
        pub const Outline = Framebuffer.ColorTexture(1);
        pub const Position = Framebuffer.ColorTexture(2);
        pub const Normal = Framebuffer.ColorTexture(3);
        pub const Uv = Framebuffer.ColorTexture(4);

        pub fn init(self: *Textures) void {
            self.depth = Depth.init();
            self.color = Color.init();
            self.outline = Outline.init();
            self.position = Position.init();
            self.normal = Normal.init();
            self.uv = Uv.init();
        }

        pub fn deinit(self: *Textures) void {
            self.depth.deinit();
            self.color.deinit();
            self.outline.deinit();
            self.position.deinit();
            self.normal.deinit();
            self.uv.deinit();
        }


    };

    const Self = @This();

    pub fn init(self: *Self, width: usize, height: usize) void {
        self.framebuffer = Framebuffer.init();
        self.textures.init();
        self.textures.depth.allocFramebuffer(width, height);
        self.textures.color.allocFramebuffer(width, height);
        self.textures.outline.allocFramebuffer(width, height);
        self.textures.position.allocFramebuffer(width, height);
        self.textures.normal.allocFramebuffer(width, height);
        self.textures.uv.allocFramebuffer(width, height);
        self.framebuffer.attachDepth(self.textures.depth);
        self.framebuffer.attachColor(0, self.textures.color);
        self.framebuffer.attachColor(1, self.textures.outline);
        self.framebuffer.attachColor(2, self.textures.position);
        self.framebuffer.attachColor(3, self.textures.normal);
        self.framebuffer.attachColor(4, self.textures.uv);
        self.width = width;
        self.height = height;

    }

    pub fn deinit(self: *Self) void {
        self.framebuffer.deinit();
        self.textures.deinit();
    }

    pub fn resize(self: *Self, width: usize, height: usize) void {
        self.deinit();
        self.init(width, height);
    }

    pub fn setAsTarget(self: Self) void {
        self.framebuffer.bind();
    }

    pub fn clear(self: Self) void {
        self.framebuffer.clearColor(0, .{0, 0, 0, 0});
        self.framebuffer.clearColor(1, .{0, 0, 0, 0});
        self.framebuffer.clearColor(2, .{0, 0, 0, 0});
        self.framebuffer.clearColor(3, .{0, 0, 0});
        self.framebuffer.clearColor(4, .{0, 0});
        self.framebuffer.clearDepth(1);
    }

    pub fn blitDepth(self: Self, target_handle: c_uint) void {
        const w = @intCast(c_int, self.width);
        const h = @intCast(c_int, self.height);
        self.framebuffer.blit(target_handle,
            .{0, 0}, .{w, h},
            .{0, 0}, .{w, h},
            .depth,
            .nearest,
        );

    }

};
