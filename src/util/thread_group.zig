const std = @import("std");

const AtomicQueue = @import("atomic_queue.zig").AtomicQueue;

const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const Semaphore = @import("semaphore.zig").Semaphore;

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

        pub fn init(self: *Self, allocator: Allocator, process_item_fn: ProcessItemFn, thread_count_factor: f32, queue_capacity: usize) !void {
            const cpu_count = try Thread.getCpuCount();
            const thread_count = std.math.max(@floatToInt(usize, @intToFloat(f32, cpu_count) * thread_count_factor), 1);
            self.* = Self {
                .item_queue = try Queue.init(allocator, queue_capacity),
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