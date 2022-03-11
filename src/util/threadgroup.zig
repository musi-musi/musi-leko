const std = @import("std");

const AtomicQueue = @import("atomicqueue.zig").AtomicQueue;

const Thread = std.Thread;
const ResetEvent = Thread.ResetEvent;
const Allocator = std.mem.Allocator;

pub fn ThreadGroup(comptime Item_: type) type {
    return struct {

        item_queue: Queue,
        threads: []Thread,
        process_item_fn: ProcessItemFn,
        is_joining: bool = false,

        pub const Item = Item_;
        pub const Queue = AtomicQueue(Item);
        
        pub const ProcessItemFn = fn(*Self, Item, usize) anyerror!void;


        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator, process_item_fn: ProcessItemFn, thread_count_factor: f32, queue_capacity: usize) !void {
            const cpu_count = try Thread.getCpuCount();
            const thread_count = @floatToInt(usize, @intToFloat(f32, cpu_count) * thread_count_factor);
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
            for (self.threads) |thread| {
                thread.join();
            }
        }

        pub fn submitItem(self: *Self, item: Item) !void {
            if (!self.is_joining) {
                try self.item_queue.enqueue(item);
            }
        }

        fn threadMain(self: *Self, thread_index: usize) !void {
            while (true) {
                while (!self.is_joining and self.item_queue.count() == 0) {
                    std.os.sched_yield() catch { std.atomic.spinLoopHint(); };
                }
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