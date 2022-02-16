pub const hello_triangle = @import("hello_triangle.zig");

pub fn init() !hello_triangle.HelloTriangle {
    return hello_triangle.HelloTriangle.init();
}