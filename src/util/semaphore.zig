const std = @import("std");


pub const Semaphore = struct {

    mutex: Mutex = .{},
    cond: Condition = .{},
    /// It is OK to initialize this field to any value.
    permits: usize = 0,

    const Self = @This();
    const Mutex = std.Thread.Mutex;
    const Condition = std.Thread.Condition;

    pub fn wait(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.permits == 0)
            self.cond.wait(&self.mutex);

        self.permits -= 1;
        if (self.permits > 0)
            self.cond.signal();
    }

    pub fn post(self: *Self) void {
        self.postMulti(1);
    }

    pub fn postMulti(self: *Self, count: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.permits += count;
        self.cond.signal();
    }

};