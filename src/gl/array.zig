const c = @import("c");
const buffer = @import("buffer.zig");

const std = @import("std");
const builtin = std.builtin;
const meta = std.meta;

/// a vertex array
/// `BufferBinds` is a struct where every field is of type `BufferBind()`
/// `IndexElement` is a zig integer type for the index buffer, usually u32 or u16, must be supported by gl
/// vertex buffers can be bound to the array via the `buffer_binds` field by accessing the field for the buffer's bind
/// ex: `array.buffer_binds.positions.bind(positions_buffer);`
/// if using multiple vertex buffers, make sure their bind configs ensure no overlap in indices
pub fn Array(comptime BufferBinds_: type, comptime index_element_: buffer.IndexElement) type {

    return struct {

        handle: c_uint,
        buffer_binds: BufferBinds,

        pub const index_element = index_element_;
        pub const IndexBuffer = buffer.IndexBuffer(index_element);
        pub const BufferBinds = BufferBinds_;

        const Self = @This();

        pub fn init() Self {
            var self: Self = undefined;
            c.glCreateVertexArrays(1, &self.handle);
            if (@typeInfo(BufferBinds) != .Struct) {
                @compileError("BufferBinds must be a struct, not " ++ @typeName(BufferBinds));
            }
            inline for (meta.fields(BufferBinds)) |field| {
                const Bind = field.field_type;
                @field(self.buffer_binds, field.name) = Bind.init(self.handle);
                const Attributes = Bind.Attributes;
                const config = Bind.config;
                comptime var attribute_index = config.attribute_start;
                inline for (meta.fields(Attributes)) |attribute_field| {
                    const attribute = comptime AttributeType.fromType(attribute_field.field_type);
                    c.glEnableVertexArrayAttrib(self.handle, attribute_index);
                    const offset = @offsetOf(Attributes, attribute_field.name);
                    switch (attribute.primitive) {
                        .half, .float => c.glVertexArrayAttribFormat(self.handle, attribute_index, attribute.len, @enumToInt(attribute.primitive), 0, offset),
                        .double => c.glVertexArrayAttribLFormat(self.handle, attribute_index, attribute.len, @enumToInt(attribute.primitive), offset),
                        else => c.glVertexArrayAttribIFormat(self.handle, attribute_index, attribute.len, @enumToInt(attribute.primitive), offset),
                    }
                    c.glVertexArrayAttribBinding(self.handle, attribute_index, config.bind_index);
                    attribute_index += 1;
                }
                if (config.divisor > 0) {
                    c.glVertexArrayBindingDivisor(self.handle, config.bind_index, config.divisor);
                }
            }
            return self;
        }

        pub fn deinit(self: Self) void {
            c.glDeleteVertexArrays(1, &self.handle);
        }

        pub fn bindIndexBuffer(self: Self, index_buffer: IndexBuffer) void {
            c.glVertexArrayElementBuffer(self.handle, index_buffer.handle);
        }

        pub fn bind(self: Self) void {
            c.glBindVertexArray(self.handle);
        }

    };

}


pub fn unbindArray() void {
    c.glBindVertexArray(0);
}

pub const BufferBindConfig = struct {
    bind_index: c_uint = 0,
    attribute_start: c_uint = 0,
    divisor: c_uint = 0,
};

/// a bindpoint of a vertex array for one of its vertex buffers
/// `Attributes` is a struct where every field has a type matching `AttributeType`
/// `config` specifies:
/// - the bind index in the vertex array for this bindpoint
/// - the index of the first attribute in the layout
/// - the instancing divisor (0 by default)
/// attributes will be given layout indicies in ascending order as they are defined in `Attributes`,
/// startomg with `config.attribute_start`
pub fn BufferBind(comptime Attributes_: type, comptime config_: BufferBindConfig) type {
    return struct {
        array: c_uint,


        pub const config = config_;
        pub const Attributes = Attributes_;
        pub const Buffer = buffer.VertexBuffer(Attributes);

        const Self = @This();

        fn init(array: c_uint) Self {
            const self: Self = .{
                .array = array,
            };
            return self;
        }

        pub fn bindBuffer(self: Self, buf: Buffer) void {
            const offset = 0;
            c.glVertexArrayVertexBuffer(self.array, config.bind_index, buf.handle, offset, @sizeOf(Attributes));
        }

    };
}

/// pair of a gl primitive type enum and length (1-4 inc.)
/// attribute types are defined in zig as
/// `prim` or `[n]prim`, where prim is a numerical primitive gl supports and n is between 1 and 4 inclusive
/// ex: `float = f32`
/// ex: `vec3i = [3]i32`
/// TODO: support larger attributes like matrices
pub const AttributeType = struct {
    primitive: Primitive,
    len: usize,

    /// mapping between zig types and gl enum values for supported vertex attribute primitives
    pub const Primitive = enum(c_uint) {
        byte = c.GL_BYTE,
        ubyte = c.GL_UNSIGNED_BYTE,
        short = c.GL_SHORT,
        ushort = c.GL_UNSIGNED_SHORT,
        int = c.GL_INT,
        uint = c.GL_UNSIGNED_INT,
        half = c.GL_HALF_FLOAT,
        float = c.GL_FLOAT,
        double = c.GL_DOUBLE,

        pub fn ToType(comptime self: Primitive) type {
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

        pub fn fromType(comptime T: type) Primitive {
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

    pub fn fromType(comptime Attribute: type) Self {
        switch (@typeInfo(Attribute)) {
            .Int, .Float => {
                return Self {
                    .primitive = Primitive.fromType(Attribute),
                    .len = 1,
                };
            },
            .Array => |array| {
                const len = array.len;
                switch (len) {
                    1, 2, 3, 4 => {
                        return Self {
                            .primitive = Primitive.fromType(array.child),
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
