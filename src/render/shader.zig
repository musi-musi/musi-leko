const std = @import("std");
const gl = @import("gl");


const fmt = std.fmt;

pub fn Shader(comptime uniforms_: []const gl.Uniform, comptime vert_source_: [:0]const u8, comptime frag_source_: [:0]const u8, comptime headers_: []const [:0]const u8) type {
    comptime {

        var headers_source_list: [:0]const u8 = fmt.comptimePrint("#version {d}{d}0 core\n", .{gl.config.version_major, gl.config.version_minor});
        for (headers_) |header_source, i| {
            headers_source_list = fmt.comptimePrint("{s}\n#line 1 {d}\n{s}\n", .{headers_source_list, i + 1, header_source});
        }
        const vert_source = fmt.comptimePrint("{s}\n#line 1 0\n{s}\n", .{headers_source_list, vert_source_});
        const frag_source = fmt.comptimePrint("{s}\n#line 1 0\n{s}\n", .{headers_source_list, frag_source_});

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
                errdefer std.log.err("shader source:\nvertex:\n{s}\nfragment:\n{s}", .{vert_source, frag_source});
                self.vert_stage.source(vert_source);
                try self.vert_stage.compile();
                self.frag_stage.source(frag_source);
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

}