const std = @import("std");

const Allocator = std.mem.Allocator;

pub const PoolConfig = struct {
    slab_size: usize = 128,
};

pub fn Pool(comptime Item: type, comptime config: PoolConfig) type {
    return InitPool(Item, undefined, config);
}

pub fn InitPool(comptime Item_: type, comptime initial_value_: Item_, comptime config_: PoolConfig) type {
    if (config_.slab_size == 0) {
        @compileError("slab_size must be larger than 0");
    }
    return struct {
        allocator: Allocator,
        inactive_head: ?*Node = null,
        slabs: SlabList,

        const Node = struct {
            is_checked_out: bool = false,
            item: Item = initial_value,
            next: ?*Node = null,
        };

        const Slab = [slab_size]Node;

        const SlabList = std.ArrayListUnmanaged(*Slab);

        pub const Item = Item_;
        pub const config = config_;
        pub const slab_size = config.slab_size;
        pub const initial_value = initial_value_;

        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator, initial_capacity: usize) !void {
            const initial_slab_count = try std.math.divCeil(usize, initial_capacity, slab_size);
            self.* = .{
                .allocator = allocator,
                .slabs = .{},
            };
            var i: usize = 0;
            while (i < initial_slab_count) : (i += 1) {
                try self.createSlab();
            }
        }

        pub fn deinit(self: *Self) void {
            for (self.slabs.items) |slab| {
                self.allocator.destroy(slab);
            }
            self.slabs.deinit(self.allocator);
            self.inactive_head = null;
        }

        pub fn isEmpty(self: Self) bool {
            return self.inactive_head == null;
        }

        pub fn checkOutOrAlloc(self: *Self) !*Item {
            if (self.checkOut()) |item| {
                return item;
            }
            else {
                try self.createSlab();
                return self.checkOut().?;
            }
        }

        pub fn checkOut(self: *Self) ?*Item {
            if (self.inactive_head) |node| {
                self.inactive_head = node.next;
                node.next = null;
                node.is_checked_out = true;
                return &node.item;
            }
            else {
                return null;
            }
        }

        fn createSlab(self: *Self) !void {
            var slab = try self.allocator.create(Slab);
            try self.slabs.append(self.allocator, slab);
            for (slab) |*node| {
                node.* = .{};
                self.prependInactive(node);
            }
        }

        fn prependInactive(self: *Self, node: *Node) void {
            node.next = self.inactive_head;
            self.inactive_head = node;
        }

        pub fn checkIn(self: *Self, item: *Item) void {
            var node = @fieldParentPtr(Node, "item", item);
            if (node.is_checked_out) {
                node.is_checked_out = false;
                self.prependInactive(node);
            }
        }

    };
}