const c = @import("../c.zig");

pub const Target = enum(c_uint) {
    vertex = c.GL_ARRAY_BUFFER,
    index = c.GL_ELEMENT_ARRAY_BUFFER,
};

pub const Usage = enum(c_uint) {
    stream_draw = c.GL_STREAM_DRAW,
    stream_read = c.GL_STREAM_READ,
    stream_copy = c.GL_STREAM_COPY,
    static_draw = c.GL_STATIC_DRAW,
    static_read = c.GL_STATIC_READ,
    static_copy = c.GL_STATIC_COPY,
    dynamic_draw = c.GL_DYNAMIC_DRAW,
    dynamic_read = c.GL_DYNAMIC_READ,
    dynamic_copy = c.GL_DYNAMIC_COPY,
};

pub fn VertexBuffer(comptime ElementT: type) type {
    return Buffer(.vertex, ElementT);
}

pub fn IndexBuffer(comptime ElementT: type) type {
    return Buffer(.index, ElementT);
}

pub const IndexBuffer8 = IndexBuffer(u8);
pub const IndexBuffer16 = IndexBuffer(u16);
pub const IndexBuffer32 = IndexBuffer(u32);

pub fn Buffer(comptime target: Target, comptime ElementT: type) type {
    return struct {
        /// 
        handle: c_int,

        pub const Element = ElementT;
        pub const Target = target;

        const Self = @This();

        /// create a new buffer on the gpu
        pub fn init() Self {
            var handle: c_int = undefined;
            c.glCreateBuffers(1, &handle);
            return Self { .handle = handle };
        }

        /// delete this buffer
        pub fn deinit(self: Self) void {
            c.glDeleteBuffers(1, &self.handle);
        }

        /// allocate `size` bytes and declare usage
        /// old data is discarded, if it exists
        pub fn alloc(self: Self, size: usize, usage: Usage) void {
            c.glNamedBufferData(self.handle, @intCast(c_longlong, size * @sizeOf(Element)), c.NULL, @enumToInt(usage));
        }

        /// upload data, allocating enough bytes to store it, and declare usage
        /// old data is discarded, if it exists
        pub fn data(self: Self, data_slice: []const Element, usage: Usage) void {
            const ptr = @ptrCast(*const c_void, data_slice.ptr);
            const size = @intCast(c_longlong, @sizeOf(Element) * data_slice.len);
            c.glNamedBufferData(self.handle, size, ptr, @enumToInt(usage));
        }

        /// replace a slice of data in the buffer. no reallocation will occur
        pub fn subData(self: Self, data_slice: []const Element, offset: usize) void {
            const ptr = @ptrCast(*const c_void, data_slice.ptr);
            const size = @intCast(c_longlong, @sizeOf(Element) * data_slice.len);
            c.glNamedBufferSubData(self.handle, offset, size, ptr);
        }

        /// replace all data in the buffer
        pub fn update(self: Self, data_slice: []const Element) void {
            self.subdata(data_slice, 0);
        }
    };
}