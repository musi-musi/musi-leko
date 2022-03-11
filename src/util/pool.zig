const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Pool(comptime Item_: type) type {
    return struct {
        allocator: Allocator,
        inactive_head: ?*Node = null,

        const Node = struct {
            is_checked_out: bool = false,
            item: Item = undefined,
            next: ?*Node = null,
        };

        pub const Item = Item_;

        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator, initial_capacity: usize) !void {
            self.* = .{
                .allocator = allocator,
            };
            var i: usize = 0;
            while (i < initial_capacity) : (i += 1) {
                var node = try allocator.create(Node);
                node.* = .{};
                node.next = self.inactive_head;
                self.inactive_head = node.next;
            }
        }

        pub fn deinit(self: *Self) void {
            var next = self.inactive_head;
            while (next) |node| {
                next = node.next;
                self.allocator.destroy(node);
            }
            self.inactive_head = null;
        }

        pub fn checkOut(self: *Self) !*Item {
            if (self.inactive_head) |node| {
                self.inactive_head = node.next;
                node.next = null;
                node.is_checked_out = true;
                return &node.item;
            }
            else {
                const node = try self.allocator.create(Node);
                node.* = .{};
                node.is_checked_out = true;
                return &node.item;
            }
        }

        pub fn checkIn(self: *Self, item: *Item) void {
            var node = @fieldParentPtr(Node, "item", item);
            if (node.is_checked_out) {
                node.next = self.inactive_head;
                self.inactive_head = node;
                node.is_checked_out = false;
            }
        }

    };
}