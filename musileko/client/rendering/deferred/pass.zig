const std = @import("std");

const client = @import("../../.zig");
const gl = client.gl;
const nm = client.nm;
const gui = client.gui;

const rendering = @import("../.zig");

const deferred = @import(".zig");

const GBuffer = deferred.GBuffer;

const Vec4 = nm.Vec4;

pub const Pass = struct {

    buffer: GBuffer,
    screen_mesh: ScreenMesh,
    shader: Shader,
    noise_texture: NoiseTexture,

    const Shader = rendering.Shader(
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
        self.shader.uniforms.setMultiple(camera);
    }

    pub fn setProperties(self: Self, properties: PassProperties) void {
        self.shader.uniforms.setMultiple(properties);
    }

    pub fn setMaterialPattern(self: Self, pattern: rendering.material.Pattern) void {
        self.shader.uniforms.setMultiple(pattern);
    }

    pub fn setMaterialPallete(self: Self, pallete: rendering.material.Pallete) void {
        self.shader.uniforms.setMultiple(pallete);
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
    fog_falloff: f32,
    fog_start: f32,
    fog_end: f32,
    fog_color: Vec4,
    ao_bands: f32,

};

pub fn passPropertiesEditor(properties: *PassProperties, name: []const u8) bool {
    var dirty: bool = false;
    gui.text(64, "{s}", .{name});
    dirty = gui.float("fog falloff", &properties.fog_falloff, .{.speed = 0.1}) or dirty;
    dirty = gui.float("fog start", &properties.fog_start, .{.speed = 0.1}) or dirty;
    dirty = gui.float("fog end", &properties.fog_end, .{.speed = 0.1}) or dirty;
    dirty = gui.color4("fog color", &properties.fog_color.v, &.{}) or dirty;
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
