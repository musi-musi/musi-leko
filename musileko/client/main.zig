const std = @import("std");

const client = @import(".zig");
const musileko = @import("../.zig");

const nm = musileko.nm;

const window = client.window;
const rendering = client.rendering;
const gui = client.gui;
const session = musileko.engine.session;

const session_renderer = rendering.session_renderer;

pub const log_level: std.log.Level = .debug;

pub fn main() !void {

    try window.init(.{});
    defer window.deinit();
    
    window.setVsyncMode(.disabled);

    try gui.init();
    defer gui.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    try session.init(allocator);
    defer session.deinit();

    try session_renderer.init(allocator);
    defer session_renderer.deinit();

    window.setMouseMode(.hidden_raw);
    while (window.update()) {
        if (window.keyWasPressed(.escape)) {
            window.close();
        }
        else {
            if (window.keyWasPressed(.f_4)) {
                window.setDisplayMode(switch (window.displayMode()) {
                    .windowed => .borderless,
                    .borderless => .windowed,
                });
            }
            try session.update();
        
            session_renderer.render();
            gui.newFrame();
            gui.showStats();
            // gui.showDemo();
            session_renderer.materialEditorWindow();
            gui.render();
        }
    }
}