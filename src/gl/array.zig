const c = @import("../c.zig");
const buffer = @import("buffer.zig");

const std = @import("std");
const builtin = std.builtin;
const meta = std.meta;

pub fn Array(comptime BufferBinds_: type, comptime IndexElement_: type) type {

    return struct {

        handle: c_int,
        buffer_binds: BufferBinds,

        pub const IndexElement = IndexElement_;
        pub const BufferBinds = BufferBinds_;

        const Self = @This();

        pub fn init() Self {
            var self = undefined;
            c.glCreateVertexArrays(1, &self.handle);
            inline for (std.meta.fields(BufferBinds)) |field| {
                const Bind = field.field_type;
                @field(self.buffer_binds, field.name) = Bind.init(self.handle);
                const Attributes = Bind.Attributes;
                const config = Bind.Attributes;
                comptime var attribute_index = config.attribute_start;
                inline for (std.meta.fields(Attributes)) |attribute_field| {
                    const attribute = comptime Attribute.fromType(attribute_field.field_type);
                    c.glEnableVertexArrayAttrib(self.handle, attribute_index);
                    const offset = @offsetOf(Attributes, attribute_field.name);
                    switch (attribute.primitive) {
                        .half, .float => c.glVertexArrayAttribFormat(self.handle, attribute_index, attribute.len, attribute.primitive, 0, offset),
                        .double => c.glVertexArrayAttribLFormat(self.handle, attribute_index, attribute.len, attribute.primitive, offset),
                        else => c.glVertexArrayAttribIFormat(self.handle, attribute_index, attribute.len, attribute.primitive, offset),
                    }
                    c.glVertexArrayAttribBinding(self.handle, attribute_index, config.binding_index);
                    attribute_index += 1;
                }
                if (config.divisor > 0) {
                    c.glVertexArrayBindingDivisor(self.handle, config.binding_index, config.divisor);
                }
            }
            return self;
        }

        pub fn deinit(self: Self) void {
            c.glDeleteVertexArrays(1, &self.handle);
        }

    };


}

pub const BufferBindConfig = struct {
    bind_index: c_uint,
    attribute_start: c_uint,
    divisor: c_uint = 0,
};

pub fn BufferBind(comptime Attributes_: type, comptime config_: BufferBindConfig) type {
    return struct {
        array: c_int,


        pub const config = config_;
        pub const Attributes = Attributes_;
        pub const Buffer = buffer.VertexBuffer(Attributes);

        const Self = @This();

        fn init(array: c_int) Self {
            const self: Self = .{
                .array = array,
            };
            return self;
        }

        pub fn bindBuffer(self: Self, buffer: Buffer) void {
            const offset = 0;
            c.glVertexArrayVertexBuffer(self.array, config.bind_index, buffer.handle, offset, @sizeOf(Attributes));
        }



    };
}

pub const Attribute = struct {
    primitive: Type,
    len: usize,

    pub const Type = enum(c_uint) {
        byte = GL_BYTE,
        ubyte = GL_UNSIGNED_BYTE,
        short = GL_SHORT,
        ushort = GL_UNSIGNED_SHORT,
        int = GL_INT,
        uint = GL_UNSIGNED_INT,
        half = GL_HALF_FLOAT,
        float = GL_FLOAT,
        double = GL_DOUBLE,

        pub fn ToType(comptime self: Type) type {
            return switch (self) {
                .byte => i8,
                .ubyte => u8,
                .short => i16,
                .ushort => u16,
                .int => i32,
                .uint => u32,
                .half => f16,
                .float => f32,
                .double => f64,
            };
        }

        pub fn fromType(comptime T: type) Type {
            return switch (T) {
                i8 => .byte,
                u8 => .ubyte,
                i16 => .short,
                u16 => .ushort,
                i32 => .int,
                u32 => .uint,
                f16 => .half,
                f32 => .float,
                f64 => .double,
                else => @compileError("unsupported attrib primitive " ++ @typeName(T)),
            };
        }

    };

    const Self = @This();

    pub fn init(comptime Element: type) Self {
        switch (@typeInfo(Element)) {
            .Int, .Float => {
                return Self {
                    .primitive = Type.fromType(Element),
                    .len = 1,
                };
            },
            .Array => |array| {
                const len = array.len;
                switch (len) {
                    1, 2, 3, 4 => {
                        return Self {
                            .primitive = Type.fromType(array.child),
                            .len = len
                        };
                    },
                    else => @compileError("only vectors up to 4d are supported"),
                }
            },
            else => @compileError("only primitives or vectors of primitives (arrays 1-4 long) supported"),
        }
    }

};
