const std = @import("std");
const builtin = @import("builtin");

const Pool = @import("pool.zig").Pool;
const os = std.os;
const mem = std.mem;

const Allocator = mem.Allocator;

const cache_line_length = switch (builtin.cpu.arch) {
    .x86_64, .aarch64, .powerpc64 => 128,
    .arm, .mips, .mips64, .riscv64 => 32,
    .s390x => 256,
    else => 64,
};

pub const AtomicQueue = LinkedListAtomicQueue;

/// naive locking linked list queue
pub fn LinkedListAtomicQueue(comptime T: type) type {
    return struct {

        allocator: Allocator,
        mutex: std.Thread.Mutex = .{},
        head: ?*Node = null,
        tail: ?*Node = null,
        node_pool: NodePool = undefined,

        const NodePool = Pool(Node);

        const Node = struct {
            next: ?*Node = null,
            item: T,
        };

        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            var self = Self {
                .allocator = allocator,
            };
            try self.node_pool.init(allocator, 0);
            return self;
        }

        pub fn deinit(self: *Self) void {
            while (self.dequeue()) |_| {}
            self.node_pool.deinit();
        }

        pub fn enqueue(self: *Self, item: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const node = try self.node_pool.checkOutOrAlloc();
            node.* = .{
                .item = item,
            };
            if (self.tail) |tail| {
                tail.next = node;
            }
            self.tail = node;
            if (self.head == null) {
                self.head = node;
            }
        }

        pub fn dequeue(self: *Self) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.head) |node| {
                const item = node.item;
                self.head = node.next;
                if (node.next == null) {
                    self.tail = null;
                }
                self.node_pool.checkIn(node);
                return item;
            }
            else {
                return null;
            }
        }
    };
}

// multi-producer, multi-consumer atomic queue.
// original implementation by @lithdew, modificated by sam lovelace

// THIS ONE DOESNT WORK
pub fn DynamicAtomicQueue(comptime T: type) type {

    return struct {

        allocator: Allocator,
        fixed_queue: FixedQueue,
        mutex: ?std.Thread.Mutex = null,

        const FixedQueue = FixedAtomicQueue(T);

        const Self = @This();

        const grow_factor: f32 = 1.5;

        pub fn init(allocator: Allocator, _: usize) !Self {
            const initial_capacity: usize = 64;
            var self = Self {
                .allocator = allocator,
                .fixed_queue = try FixedQueue.init(allocator, initial_capacity),
            };
            return self;
        }

        pub fn deinit(self: *Self, _: Allocator) void {
            self.fixed_queue.deinit(self.allocator);
        }

        pub fn enqueue(self: *Self, item: T) !void {
            if (self.mutex) |*mutex| mutex.lock();
            defer if (self.mutex) |*mutex| mutex.unlock();

            if (self.fixed_queue.enqueue(item)) {

            }
            else |_| {
                const new_capacity = @floatToInt(usize, @intToFloat(f32, self.fixed_queue.capacity) * grow_factor);
                var new_fixed_queue = try FixedQueue.init(self.allocator, new_capacity);
                self.mutex = .{};
                self.mutex.?.lock();
                defer self.mutex = null;
                defer self.mutex.?.unlock();
                while (self.fixed_queue.dequeue()) |existing_item| {
                    new_fixed_queue.enqueue(existing_item) catch { @panic(" new queue too small for some reason"); };
                }
                self.fixed_queue.deinit(self.allocator);
                self.fixed_queue = new_fixed_queue;
                self.fixed_queue.enqueue(item) catch { @panic(" new queue too small for some reason"); };
            }
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.mutex) |*mutex| mutex.lock();
            defer if (self.mutex) |*mutex| mutex.unlock();
            return self.fixed_queue.dequeue();
        }
    };

}

// multi-producer, multi-consumer atomic queue.
// original implementation by @lithdew, modificated by sam lovelace
pub fn FixedAtomicQueue(comptime T: type) type {
    return struct {

        capacity: usize,
        entries: []Entry align(cache_line_length),
        enqueue_pos: usize align(cache_line_length),
        dequeue_pos: usize align(cache_line_length),

        const Self = @This();

        pub const Entry = struct {
            sequence: usize align(cache_line_length),
            item: T,
        };

        pub fn init(allocator: Allocator, capacity: usize) !Self {
            const entries = try allocator.alloc(Entry, capacity);
            for (entries) |*entry, i| {
                entry.sequence = i;
            }

            var self = Self{
                .capacity = capacity,
                .entries = entries,
                .enqueue_pos = 0,
                .dequeue_pos = 0,
            };
            return self;
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.entries);
        }

        pub fn count(self: *Self) usize {
            const tail = @atomicLoad(usize, &self.dequeue_pos, .Monotonic);
            const head = @atomicLoad(usize, &self.enqueue_pos, .Monotonic);
            return (tail -% head) % self.capacity;
        }

        pub fn enqueue(self: *Self, item: T) !void {
            var entry: *Entry = undefined;
            var pos = @atomicLoad(usize, &self.enqueue_pos, .Monotonic);
            while (true) : (os.sched_yield() catch {}) {
                entry = &self.entries[pos % self.capacity];

                const seq = @atomicLoad(usize, &entry.sequence, .Acquire);
                const diff = @intCast(isize, seq) -% @intCast(isize, pos);
                if (diff == 0) {
                    pos = @cmpxchgWeak(usize, &self.enqueue_pos, pos, pos +% 1, .Monotonic, .Monotonic) orelse {
                        entry.item = item;
                        @atomicStore(usize, &entry.sequence, pos +% 1, .Release);
                        return;
                    };
                } else if (diff < 0) {
                    return error.full;
                } else {
                    pos = @atomicLoad(usize, &self.enqueue_pos, .Monotonic);
                }
            }
        }

        pub fn dequeue(self: *Self) ?T {
            var entry: *Entry = undefined;
            var pos = @atomicLoad(usize, &self.dequeue_pos, .Monotonic);
            while (true) : (os.sched_yield() catch {}) {
                entry = &self.entries[pos % self.capacity];

                const seq = @atomicLoad(usize, &entry.sequence, .Acquire);
                const diff = @intCast(isize, seq) -% @intCast(isize, pos +% 1);
                if (diff == 0) {
                    pos = @cmpxchgWeak(usize, &self.dequeue_pos, pos, pos +% 1, .Monotonic, .Monotonic) orelse {
                        const item = entry.item;
                        @atomicStore(usize, &entry.sequence, pos +% (self.capacity - 1) +% 1, .Release);
                        return item;
                    };
                } else if (diff < 0) {
                    return null;
                } else {
                    pos = @atomicLoad(usize, &self.dequeue_pos, .Monotonic);
                }
            }
        }

    };
}


test "mpmc queue" {
    std.testing.log_level = .debug;
    var queue = try AtomicQueue(i32).init(&std.testing.allocator_instance.allocator, 48);
    defer queue.deinit();
    const prod = try std.Thread.spawn(&queue, testProducer);
    const cons = try std.Thread.spawn(&queue, testConsumer);
    prod.wait();
    cons.wait();
}

const count = 512;

fn testProducer(q: *AtomicQueue(i32)) !void {
    var i: i32 = 0;
    while (i < count) : (i += 1) {
        std.time.sleep(10_000_000);
        if (q.enqueue(i)) {
            std.log.debug("produced {d}", .{i});
        }
        else |_| {
            std.log.debug("could not produce {d}", .{i});
        }
    }
}

fn testConsumer(q: *AtomicQueue(i32)) !void {
    // std.time.sleep(100_000_000);
    var n: i32 = 0;
    while(n < count) {
        while (q.dequeue()) |i| {
            n += 1;
            std.log.debug("consumed {d}", .{i});
        }
    }
}