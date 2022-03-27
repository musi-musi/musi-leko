const std = @import("std");

const AtomicQueue = @import("atomic_queue.zig").AtomicQueue;

const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const Semaphore = @import("semaphore.zig").Semaphore;

pub const ThreadGroupConfig = struct {
    
    thread_count: ThreadCount = .{ .cpu_factor = 0.75 },

    pub const ThreadCount = union(enum) {
        /// determine thread count as a fraction of cpu cores
        cpu_factor: f32,
        /// use a specific number of threads
        count: usize,
    };

};

pub fn ThreadGroup(comptime Item_: type) type {
    return struct {

        item_queue: Queue,
        threads: []Thread,
        process_item_fn: ProcessItemFn,
        is_joining: bool = false,
        semaphore: Semaphore = .{},

        pub const Item = Item_;
        pub const Queue = AtomicQueue(Item);
        
        pub const ProcessItemFn = fn(*Self, Item, usize) anyerror!void;

        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator, config: ThreadGroupConfig, process_item_fn: ProcessItemFn) !void {
            var thread_count: usize = 0;
            switch (config.thread_count) {
                .cpu_factor => |factor| {
                    const cpu_count = try Thread.getCpuCount();
                    thread_count = @floatToInt(usize, @intToFloat(f32, cpu_count) * factor);
                },
                .count => |count| {
                    thread_count = count;
                },
            }
            thread_count = std.math.max(1, thread_count);
            self.* = Self {
                .item_queue = try Queue.init(allocator),
                .threads = try allocator.alloc(Thread, thread_count),
                .process_item_fn = process_item_fn,
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.threads);
        }

        pub fn spawn(self: *Self, spawn_config: Thread.SpawnConfig) !void {
            for (self.threads) |*thread, i| {
                thread.* = try Thread.spawn(spawn_config, threadMain, .{self, i});
            }
        }

        pub fn join(self: *Self) void {
            self.is_joining = true;
            self.semaphore.postMulti(self.threads.len);
            for (self.threads) |thread| {
                thread.join();
            }
        }

        pub fn submitItem(self: *Self, item: Item) !void {
            const items = [1]Item{ item};
            try self.submitItems(&items);
        }

        pub fn submitItems(self: *Self, items: []const Item) !void {
            if (!self.is_joining) {
                for (items) |item| {
                    try self.item_queue.enqueue(item);
                }
                self.semaphore.postMulti(items.len);
            }
        }

        fn threadMain(self: *Self, thread_index: usize) !void {
            while (true) {
                self.semaphore.wait();
                if (self.is_joining) {
                    return;
                }
                if (self.item_queue.dequeue()) |item| {
                    try self.process_item_fn(self, item, thread_index);
                }
            }
        }

    };
}