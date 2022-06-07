const std = @import("std");
const builtin = @import("builtin");

const StackTrace = std.builtin.StackTrace;
const debug = std.debug;
const Allocator = std.mem.Allocator;


pub const TrackingAllocator = struct {
    backing: Allocator,
    info_map: InfoMap,
    mutex: std.Thread.Mutex,

    const trace_depth: usize = 16;

    const InfoMap = std.AutoHashMapUnmanaged(usize, AllocationInfo);

    const Self = @This();

    pub fn init(backing_allocator: Allocator) Self {
        return Self {
            .backing = backing_allocator,
            .info_map = .{},
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Self) bool {
        defer self.info_map.clearAndFree(self.backing);
        if (self.info_map.size > 0) {
            var iter = self.info_map.valueIterator();
            while (iter.next()) |info| {
                std.log.err("leaked {d} bytes", .{info.size});
                debug.dumpStackTrace(info.trace);
                info.deinit(self.backing);
            }
            return true;
        }
        else {
            return false;
        }
    }

    pub fn allocator(self: *Self) Allocator {
        return Allocator.init(
            self,
            allocFn,
            resizeFn,
            freeFn,
        );
    }

    fn allocFn(self: *Self, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Allocator.Error![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const slice = try self.backing.rawAlloc(len, ptr_align, len_align, ret_addr);
        const ret = if (ret_addr == 0) @returnAddress() else ret_addr;
        self.addInfo(slice, ret);
        return slice;
    }

    fn resizeFn(self: *Self, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.backing.rawResize(buf, buf_align, new_len, len_align, ret_addr)) |len| {
            if (self.info_map.getPtr(@ptrToInt(buf.ptr))) |info| {
                info.size = len;
            }
            return len;
        }
        else {
            return null;
        }
    }

    fn freeFn(self: *Self, buf: []u8, buf_align: u29, ret_addr: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.removeInfo(buf);
        self.backing.rawFree(buf, buf_align, ret_addr);
    }

    fn addInfo(self: *Self, slice: []u8, ret_addr: usize) void {
        var info = AllocationInfo.init(self.backing, slice, ret_addr);
        self.info_map.put(self.backing, info.address, info) catch @panic("could not add to allocation info map");
    }

    fn removeInfo(self: *Self, slice: []u8) void {
        if (self.info_map.fetchRemove(@ptrToInt(slice.ptr))) |kv| {
            kv.value.deinit(self.backing);
        }
    }


};


const AllocationInfo = struct {
    address: usize,
    size: usize,
    trace: StackTrace,

    const Self = @This();

    pub fn init(allocator: Allocator, slice: []u8, ret_addr: usize) Self {
        var trace = StackTrace {
            .index = 0,
            .instruction_addresses = 
                allocator.alloc(usize, TrackingAllocator.trace_depth)
                catch @panic("could not allocate memory for allocation info"),
        };
        debug.captureStackTrace(ret_addr, &trace);
        return Self {
            .address = @ptrToInt(slice.ptr),
            .size = slice.len,
            .trace = trace,
        };
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        allocator.free(self.trace.instruction_addresses);
    }
}; 