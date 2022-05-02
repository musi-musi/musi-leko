const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;
const gui = client.gui;

const rendering = @import("../.zig");

const deferred = @import(".zig");

const GBuffer = deferred.GBuffer;

pub const Pass = struct {

    buffer: GBuffer,
    screen_mesh: ScreenMesh,
    shader: Shader,
    noise_texture: NoiseTexture,

    const Shader = rendering.Shader(&.{
            gl.uniformTextureUnit("g_color"),
            gl.uniformTextureUnit("g_outline"),
            gl.uniformTextureUnit("g_position"),
            gl.uniformTextureUnit("g_normal"),
            gl.uniformTextureUnit("g_uv"),
            gl.uniformTextureUnit("g_lighting"),

            gl.uniform("screen_size", .vec2),

            gl.uniform("light_direction", .vec3),
            gl.uniform("ao_bands", .float),

            gl.uniform("view", .mat4),
            gl.uniform("proj", .mat4),

            gl.uniformTextureUnit("tex_noise"),
            
            gl.uniform("warp_uv_scale", .vec2),
            gl.uniform("warp_amount", .vec2),
            gl.uniform("noise_uv_scale", .vec2),
            gl.uniform("color_bands", .float),

            gl.uniform("pallete_a", .vec4),
            gl.uniform("pallete_b", .vec4),
            gl.uniform("pallete_dark", .vec4),
        },
        @embedFile("deferred.vert"),
        @embedFile("deferred.frag"),
        &.{},
    );

    const NoiseTexture = gl.Texture(.texture_2d, .{
        .channels = .rg,
        .component = .f32,
    });

    const Self = @This();

    pub fn init(self: *Self) !void {
        const width = client.window.width();
        const height = client.window.height();
        self.buffer.init(width, height);
        self.screen_mesh.init();
        self.shader = try Shader.init();
        self.setScreenSize(width, height);
        self.setLightDirection(nm.Vec3.init(.{1, 3, 2}).norm());

        self.noise_texture = NoiseTexture.init();
        const size: u32 = 256;
        // const perlin_wrap: f32 = 64;
        const Data = [size][size][2]f32;
        // const perlin = nm.noise.Perlin2(perlin_wrap){};
        var data: Data = undefined;
        var rng = std.rand.DefaultPrng.init(0);
        const r = rng.random();
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            // const u = @intToFloat(f32, x) / @intToFloat(f32, size) * (perlin_wrap);
            var y: u32 = 0;
            while (y < size) : (y += 1) {
                // const v = @intToFloat(f32, y) / @intToFloat(f32, size) * (perlin_wrap);
                data[x][y][0] = (r.float(f32) * 2) - 1;
                data[x][y][1] = (r.float(f32) * 2) - 1;
                // data[x][y][0] = perlin.sample(.{u, v});
                // data[x][y][1] = perlin.sample(.{u, v});
            }
        }

        self.noise_texture.alloc(size, size);
        self.noise_texture.upload(size, size, @ptrCast(*[size * size][2]f32, &data));
        self.shader.uniforms.set("tex_noise", 1);
        self.noise_texture.setFilter(.linear, .linear);
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
        self.screen_mesh.deinit();
        self.shader.deinit();
    }

    pub fn setScreenSize(self: Self, width: usize, height: usize) void {
        const w = @intToFloat(f32, width);
        const h = @intToFloat(f32, height);
        self.shader.uniforms.set("screen_size", .{w, h});
    }

    pub fn setLightDirection(self: Self, light_direction: nm.Vec3) void {
        self.shader.uniforms.set("light_direction", light_direction.v);
    }

    pub fn setCamera(self: Self, camera: rendering.Camera) void {
        self.shader.uniforms.set("view", camera.view.v);
        self.shader.uniforms.set("proj", camera.proj.v);
    }

    pub fn setProperties(self: Self, properties: PassProperties) void {
        self.shader.uniforms.set("ao_bands", properties.ao_bands);
    }

    pub fn setMaterialPattern(self: Self, pattern: rendering.material.Pattern) void {
        self.shader.uniforms.set("warp_uv_scale", pattern.warp_uv_scale.v);
        self.shader.uniforms.set("warp_amount", pattern.warp_amount.v);
        self.shader.uniforms.set("noise_uv_scale", pattern.noise_uv_scale.v);
        self.shader.uniforms.set("color_bands", pattern.color_bands);
    }

    pub fn setMaterialPallete(self: Self, pallete: rendering.material.Pallete) void {
        self.shader.uniforms.set("pallete_a", pallete.color0.v);
        self.shader.uniforms.set("pallete_b", pallete.color1.v);
        self.shader.uniforms.set("pallete_dark", pallete.color_dark.v);
    }

    pub fn begin(self: *Self) bool {
        const width = client.window.width();
        const height = client.window.height();
        if (width != self.buffer.width or height != self.buffer.height) {
            self.buffer.resize(width, height);
            self.setScreenSize(width, height);
        }
        if (self.buffer.is_complete) {
            self.buffer.setAsTarget();
            self.buffer.clear();
        }
        return self.buffer.is_complete;
    }

    pub fn finish(self: Self) void {
        gl.bindDefaultFramebuffer();
        gl.disableDepthTest();

        const TU = rendering.TextureUnit;
        
        self.noise_texture.bind(TU.noise_array.int());
        self.shader.uniforms.set("tex_noise", TU.noise_array.int());


        const g_buffer_start = TU.g_buffer_start.int();

        self.buffer.textures.color.bind(g_buffer_start + 0);
        self.shader.uniforms.set("g_color", g_buffer_start + 0);
        self.buffer.textures.outline.bind(g_buffer_start + 1);
        self.shader.uniforms.set("g_outline", g_buffer_start + 1);
        self.buffer.textures.position.bind(g_buffer_start + 2);
        self.shader.uniforms.set("g_position", g_buffer_start + 2);
        self.buffer.textures.normal.bind(g_buffer_start + 3);
        self.shader.uniforms.set("g_normal", g_buffer_start + 3);
        self.buffer.textures.uv.bind(g_buffer_start + 4);
        self.shader.uniforms.set("g_uv", g_buffer_start + 4);
        self.buffer.textures.lighting.bind(g_buffer_start + 5);
        self.shader.uniforms.set("g_lighting", g_buffer_start + 5);
        self.shader.use();
        self.screen_mesh.startDraw();
        self.screen_mesh.draw();
        gl.enableDepthTest();
        // self.buffer.blitDepth(0); // produces GL_INVALID_OPERATION because the default depth buffer is not f32
    }


};

pub const PassProperties = struct {
    ao_bands: f32,

};

pub fn passPropertiesEditor(properties: *PassProperties, name: []const u8) bool {
    var dirty: bool = false;
    gui.text(64, "{s}", .{name});
    dirty = gui.float("ao bands", &properties.ao_bands, .{.speed = 0.1}) or dirty;
    return dirty;
}

pub const ScreenMesh = struct {

    array: Array,
    vertex_buffer: VertexBuffer,
    index_buffer: Array.IndexBuffer,

    pub const Vertex = struct {
        position: [2]f32,
    };

    pub const VertexBuffer = gl.VertexBuffer(Vertex);

    pub const Array = gl.Array(struct {
        verts: gl.BufferBind(Vertex, .{}),
    }, .uint);

    const Self = @This();

    pub fn init(self: *Self) void {
        self.array = Array.init();
        self.vertex_buffer = VertexBuffer.init();
        self.index_buffer = Array.IndexBuffer.init();

        self.vertex_buffer.data(&.{
            .{ .position = .{-1, -1} },
            .{ .position = .{ 1, -1} },
            .{ .position = .{-1,  1} },
            .{ .position = .{ 1,  1} },
        }, .static_draw);
        self.index_buffer.data(&.{
            0, 1, 3, 0, 3, 2,
        }, .static_draw);

        self.array.buffer_binds.verts.bindBuffer(self.vertex_buffer);
        self.array.bindIndexBuffer(self.index_buffer);
    }

    pub fn deinit(self: Self) void {
        self.array.deinit();
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }

    pub fn startDraw(self: Self) void {
        self.array.bind();
    }

    pub fn draw(_: Self) void  {
        gl.drawElements(.triangles, 6, .uint);
    }

};
