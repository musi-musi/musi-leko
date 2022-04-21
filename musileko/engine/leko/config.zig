const std = @import("std");
const engine = @import("../.zig");
const util = engine.util;

pub const config = struct {
    pub const chunk_width_bits: u32 = 5;
    pub const chunk_width: u32 = 1 << chunk_width_bits;


    pub const volume_manager = struct {

        pub const load_radius: u32 = 4; // hard code for now
        pub const load_group_config = util.ThreadGroupConfig {
            .thread_count = .{
                .cpu_factor = 0.5,
            },
        };
    };
};
