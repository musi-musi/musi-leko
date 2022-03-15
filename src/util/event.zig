const std = @import("std");

pub fn Event(comptime Data_: type) type {
    return struct {

        listener_head: ?*Listener = null,
        listener_tail: ?*Listener = null,

        pub const Data = Data_;

        pub const Listener = struct {

            callback_fn: CallbackFn,
            next: ?*Listener = null,

            pub const CallbackFn = fn(*Listener, Data) anyerror!void;

            pub fn init(callback_fn: CallbackFn) Listener {
                return .{
                    .callback_fn = callback_fn,
                };
            }

        };

        const Self = @This();

        pub fn addListener(self: *Self, listener: *Listener) void {
            if (self.listener_tail) |tail| {
                tail.*.next = listener;
                self.listener_tail = listener;
            }
            else {
                self.listener_head = listener;
                self.listener_tail = listener;
            }
        }

        pub fn dispatch(self: *Self, data: Data) !void {
            var node: ?*Listener = self.listener_head;
            while (node) |listener| : (node = listener.next) {
                try listener.callback_fn(listener, data);
            }
        }

    };
}