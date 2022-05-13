const std = @import("std");
const gl = @import(".zig");
const client = @import("../.zig");
const c = client.c;
pub const ProgramError = error {
    CompilationFailed,
    LinkingFailed,
};

/// a glsl shader program
pub const Program = struct {    
    handle: c_uint,

    const Self = @This();

    pub fn init() Self {
        return Self {
            .handle = c.glCreateProgram(),
        };
    }

    pub fn deinit(self: Self) void {
        c.glDeleteProgram(self.handle);
    }

    pub fn attach(self: Self, comptime stage_type: StageType, stage: Stage(stage_type)) void {
        c.glAttachShader(self.handle, stage.handle);
    }

    pub fn link(self: Self) ProgramError!void {
        c.glLinkProgram(self.handle);
        var success: c_int = undefined;
        c.glGetProgramiv(self.handle, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            const max_msg_size = 512;
            var msg: [512]u8 = undefined;
            c.glGetProgramInfoLog(self.handle, max_msg_size, null, &msg);
            std.log.err("failed to link shader program:\n{s}", .{msg});
            return ProgramError.CompilationFailed;
        }
    }

    pub fn use(self: Self) void {
        c.glUseProgram(self.handle);
    }

};

pub const StageType = enum(c_int) {
    vertex = c.GL_VERTEX_SHADER,
    fragment = c.GL_FRAGMENT_SHADER,
};

pub const VertexStage = Stage(.vertex);
pub const FragmentStage = Stage(.fragment);

/// a glsl shader stage, create one for each `StageType` you need, attach to a `Program` and link
pub fn Stage(comptime stage_type_: StageType) type {
    return struct {
        handle: c_uint,

        pub const stage_type = stage_type_;

        const Self = @This();

        pub fn init() Self {
            return Self {
                .handle = c.glCreateShader(@enumToInt(stage_type)),
            };
        }

        pub fn deinit(self: Self) void {
            c.glDeleteShader(self.handle);
        }

        pub fn source(self: Self, text: [:0]const u8) void {
            const len: c_int = @intCast(c_int, text.len);
            c.glShaderSource(self.handle, 1, &text.ptr, &len);
        }

        pub fn compile(self: Self) ProgramError!void {
            c.glCompileShader(self.handle);
            var success: c_int = undefined;
            c.glGetShaderiv(self.handle, c.GL_COMPILE_STATUS, &success);
            if (success == 0) {
                const max_msg_size = 512;
                var msg: [512]u8 = undefined;
                c.glGetShaderInfoLog(self.handle, max_msg_size, null, &msg);
                std.log.err("failed to compile {s} shader program stage:\n{s}", .{ @tagName(stage_type), msg});
                return ProgramError.CompilationFailed;
            }
        }

    };
}

/// interface for working with uniforms for a specific program
/// `uniforms` is a list of `Uniform` declarations
/// ex:
/// ```zig
/// &program.Uniform{
///     program.uniform("model", .mat4),
///     program.uniform("light", .vec3),
///     program.uniformArray("colors", .vec4, 8),
/// }   
/// ```
pub fn ProgramUniforms(comptime uniforms_: []const Uniform) type {
    return struct {
        program: c_uint,
        locations: [uniforms.len]c_int,

        pub const uniforms = uniforms_;

        const Self = @This();

        pub fn init(program: c_uint) Self {
            var self: Self = undefined;
            self.program = program;
            inline for (uniforms) |uni, i| {
                self.locations[i] = c.glGetUniformLocation(program, uni.name ++ "");
            }
            return self;
        }

        pub fn indexOf(comptime name: []const u8) usize {
            for (uniforms) |uni, i| {
                if (std.mem.eql(u8, name, uni.name)) {
                    return i;
                }
            }
            @compileError("no such uniform \"" ++ name ++ "\"");
        }

        pub fn hasUniform(comptime name: []const u8) bool {
            for (uniforms) |uni| {
                if (std.mem.eql(u8, name, uni.name)) {
                    return true;
                }
            }
            return false;
        }

        pub fn Value(comptime name: []const u8) type {
            return uniforms[indexOf(name)].uniform_type.Type();
        }

        pub fn set(self: Self, comptime name: []const u8, value: Value(name)) void {
            const index = comptime indexOf(name);

            const uniform_type = uniforms[index].uniform_type;
            
            const location = self.locations[index];
            const count = uniform_type.count orelse 1;
            const transpose = 0;
            const ptr = @ptrCast(uniform_type.ValuePointer(), &value);
            
            switch (uniform_type.primitive) {
                .float => c.glProgramUniform1fv(self.program, location, count, ptr),
                .vec2 => c.glProgramUniform2fv(self.program, location, count, ptr),
                .vec3 => c.glProgramUniform3fv(self.program, location, count, ptr),
                .vec4 => c.glProgramUniform4fv(self.program, location, count, ptr),

                .mat2 => c.glProgramUniformMatrix2fv(self.program, location, count, transpose, ptr),
                .mat3 => c.glProgramUniformMatrix3fv(self.program, location, count, transpose, ptr),
                .mat4 => c.glProgramUniformMatrix4fv(self.program, location, count, transpose, ptr),
                
                .int => c.glProgramUniform1iv(self.program, location, count, ptr),
                .ivec2 => c.glProgramUniform2iv(self.program, location, count, ptr),
                .ivec3 => c.glProgramUniform3iv(self.program, location, count, ptr),
                .ivec4 => c.glProgramUniform4iv(self.program, location, count, ptr),

                .uint => c.glProgramUniform1uiv(self.program, location, count, ptr),
                .uivec2 => c.glProgramUniform2uiv(self.program, location, count, ptr),
                .uivec3 => c.glProgramUniform3uiv(self.program, location, count, ptr),
                .uivec4 => c.glProgramUniform4uiv(self.program, location, count, ptr),

            }
        }

        pub fn setMultiple(self: Self, value: anytype) void {
            const V = @TypeOf(value);
            switch (@typeInfo(V)) {
                .Struct => |str| {
                    inline for (str.fields) |field| {
                        if (comptime hasUniform(field.name)) {
                            self.set(field.name, @bitCast(Value(field.name), @field(value, field.name)));
                        }
                    }
                },
                else => @compileError("value must be a struct"),
            }
        }

    };
}

pub fn ProgramUniformValues(comptime uniforms: []const Uniform) type {

    const StructField = std.builtin.StructField;
    comptime {
        var fields: [uniforms.len]StructField = undefined;
        for (uniforms) |u, i| {
            const Type = u.uniform_type.Type();
            fields[i] = .{
                .name = u.name,
                .field_type = Type,
                .default_value = std.mem.zeroes(Type),
                .is_comptime = false,
                .alignment = @alignOf(Type),
            };
        }
        return @Type(.{ .Struct = .{
            .layout = .Auto,
            .fields = fields,
            .decls = &.{},
            .is_tuple = false,
        }});
    }

}
/// a primitive uniform declaration, a name-type pair
pub const Uniform = struct {
    name: []const u8,
    uniform_type: UniformType,
};

/// create a uniform declaration for a primitive glsl value (scalar, vector, or matrix)
pub fn uniform(comptime name: []const u8, comptime primitive: UniformType.Primitive) Uniform {
    return Uniform{
        .name = name,
        .uniform_type = .{
            .primitive = primitive,
        },
    };
}

/// create a uniform declaration for a glsl texture unit
pub fn uniformTextureUnit(comptime name: []const u8) Uniform {
    return uniform(name, .int);
}

/// create a uniform declaration for an array of a glsl value (scalar, vector, or matrix)
pub fn uniformArray(comptime name: []const u8, comptime primitive: UniformType.Primitive, comptime count: c_uint) Uniform {
    return Uniform{
        .name = name,
        .uniform_type = .{
            .primitive = primitive,
            .count = count
        },
    };
}


/// represent a primitive or array glsl uniform type
pub const UniformType = struct {
    /// base scalar, vector, or matrix type
    primitive: Primitive,
    /// null if primitive, length if array
    count: ?c_uint = null,

    const Self = @This();

    /// get the zig type used to represent this glsl type
    pub fn Type(comptime self: Self) type {
        const PrimitiveType = switch(self.primitive) {
            .float => f32,
            .vec2 => [2]f32,
            .vec3 => [3]f32,
            .vec4 => [4]f32,
            .mat2 => [2][2]f32,
            .mat3 => [3][3]f32,
            .mat4 => [4][4]f32,
            
            .int => i32,
            .ivec2 => [2]i32,
            .ivec3 => [3]i32,
            .ivec4 => [4]i32,
            
            .uint => u32,
            .uivec2 => [2]u32,
            .uivec3 => [3]u32,
            .uivec4 => [4]u32,
        };
        if (self.count) |count| {
            return [count]PrimitiveType;
        }
        else {
            return PrimitiveType;
        }
    }

    pub fn ValuePointer(comptime self: Self) type {
        return switch(self.primitive) {
            .float,
            .vec2,
            .vec3,
            .vec4,
            .mat2,
            .mat3,
            .mat4,
                => *const f32,
            
            .int,
            .ivec2,
            .ivec3,
            .ivec4,
                => *const i32,
            
            .uint,
            .uivec2,
            .uivec3,
            .uivec4,
                => *const u32,
        };
    }


    /// all supported glsl types
    pub const Primitive = enum(u8) {
        float,
        vec2,
        vec3,
        vec4,

        int,
        ivec2,
        ivec3,
        ivec4,
        
        uint,
        uivec2,
        uivec3,
        uivec4,
        
        mat2,
        mat3,
        mat4,
    };

};
