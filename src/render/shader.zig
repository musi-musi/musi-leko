const std = @import("std");
const gl = @import("gl");

pub fn Shader(comptime uniforms_: []const gl.Uniform, comptime vert_source_: [:0]const u8, comptime frag_source_: [:0]const u8) type {
    return struct {

        program: gl.Program,
        vert_stage: gl.VertexStage,
        frag_stage: gl.FragmentStage,
        uniforms: Uniforms,

        pub const Uniforms = gl.ProgramUniforms(uniforms_);

        const Self = @This();

        pub fn init() !Self {
            var self = Self {
                .program = gl.Program.init(),
                .vert_stage = gl.VertexStage.init(),
                .frag_stage = gl.FragmentStage.init(),
                .uniforms = undefined,
            };
            self.vert_stage.source(vert_source_);
            try self.vert_stage.compile();
            self.frag_stage.source(frag_source_);
            try self.frag_stage.compile();
            self.program.attach(.vertex, self.vert_stage);
            self.program.attach(.fragment, self.frag_stage);
            try self.program.link();
            self.uniforms = Uniforms.init(self.program.handle);
            return self;
        }

        pub fn deinit(self: Self) void {
            self.program.deinit();
            self.vert_stage.deinit();
            self.frag_stage.deinit();
        }

        pub fn use(self: Self) void {
            self.program.use();
        }


    };
}