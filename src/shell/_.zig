const shell = @import("shell.zig");
const window = @import("window.zig");

pub const Window = window.Window;
pub const Shell = shell.Shell;

const c = @import("c");


pub const init = Shell.init;