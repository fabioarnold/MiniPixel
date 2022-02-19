const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

allocator: Allocator,

width: u32,
height: u32,
indices: []u8,
colormap: []u8,

const Self = @This();
const IndexedBitmap = @This();

pub fn init(allocator: Allocator, width: u32, height: u32) !Self {
    var self = Self{
        .allocator = allocator,
        .width = width,
        .height = height,
        .indices = undefined,
        .colormap = undefined,
    };
    self.indices = try allocator.alloc(u8, self.width * self.height);
    self.colormap = try allocator.alloc(u8, 256 * 4);

    return self;
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.indices);
    self.allocator.free(self.colormap);
}

pub fn clone(self: Self) !Self {
    return Self{
        .allocator = self.allocator,
        .width = self.width,
        .height = self.height,
        .indices = try self.allocator.dupe(u8, self.indices),
        .colormap = try self.allocator.dupe(u8, self.colormap),
    };
}

pub fn eql(self: Self, bitmap: IndexedBitmap) bool {
    return self.width == bitmap.width and
        self.width == bitmap.width and
        std.mem.eql(u8, self.indices, bitmap.indices);
}

pub fn setIndex(self: Self, x: i32, y: i32, index: u8) bool {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            self.setIndexUnchecked(ux, uy, index);
            return true;
        }
    }
    return false;
}

pub fn setIndexUnchecked(self: Self, x: u32, y: u32, index: u8) void {
    std.debug.assert(x < self.width);
    const i = y * self.width + x;
    self.indices[i] = index;
}

pub fn getIndex(self: Self, x: i32, y: i32) ?u8 {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            return self.getIndexUnchecked(ux, uy);
        }
    }
    return null;
}

pub fn getIndexUnchecked(self: Self, x: u32, y: u32) u8 {
    std.debug.assert(x < self.width);
    const i = y * self.width + x;
    return self.indices[i];
}

pub fn copyIndexUnchecked(self: Self, dst: IndexedBitmap, x: u32, y: u32) void {
    const src_index = self.getIndexUnchecked(x, y);
    dst.setIndexUnchecked(x, y, src_index);
}

pub fn drawLine(self: Self, x0: i32, y0: i32, x1: i32, y1: i32, index: u8, skip_first: bool) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    if (!skip_first) {
        _ = self.setIndex(x0, y0, index);
    }

    var x = x0;
    var y = y0;
    while (x != x1 or y != y1) {
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y += sy;
        }
        _ = self.setIndex(x, y, index);
    }
}

pub fn copyLine(self: Self, dst: IndexedBitmap, x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    var x = x0;
    var y = y0;
    while (true) {
        if (self.getIndex(x, y)) |src_index| {
            dst.setIndexUnchecked(@intCast(u32, x), @intCast(u32, y), src_index);
        }
        if (x == x1 and y == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y += sy;
        }
    }
}

pub fn clear(self: Self) void {
    std.mem.set(u8, self.indices, 0);
}

pub fn fill(self: Self, index: u8) void {
    std.mem.set(u8, self.indices, index);
}

pub fn floodFill(self: *Self, x: i32, y: i32, index: u8) !void {
    const old_index = self.getIndex(x, y) orelse return;
    if (old_index == index) return;

    const start_coords = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) };
    self.setIndexUnchecked(start_coords.x, start_coords.y, index);

    var stack = std.ArrayList(struct { x: u32, y: u32 }).init(self.allocator);
    try stack.ensureTotalCapacity(self.width * self.height / 2);
    defer stack.deinit();
    try stack.append(start_coords);

    while (stack.items.len > 0) {
        const coords = stack.pop();
        if (coords.y > 0) {
            const new_coords = .{ .x = coords.x, .y = coords.y - 1 };
            if (self.getIndexUnchecked(new_coords.x, new_coords.y) == old_index) {
                self.setIndexUnchecked(new_coords.x, new_coords.y, index);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.y < self.height - 1) {
            const new_coords = .{ .x = coords.x, .y = coords.y + 1 };
            if (self.getIndexUnchecked(new_coords.x, new_coords.y) == old_index) {
                self.setIndexUnchecked(new_coords.x, new_coords.y, index);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.x > 0) {
            const new_coords = .{ .x = coords.x - 1, .y = coords.y };
            if (self.getIndexUnchecked(new_coords.x, new_coords.y) == old_index) {
                self.setIndexUnchecked(new_coords.x, new_coords.y, index);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.x < self.width - 1) {
            const new_coords = .{ .x = coords.x + 1, .y = coords.y };
            if (self.getIndexUnchecked(new_coords.x, new_coords.y) == old_index) {
                self.setIndexUnchecked(new_coords.x, new_coords.y, index);
                stack.appendAssumeCapacity(new_coords);
            }
        }
    }
}

pub fn mirrorHorizontally(self: Self) void {
    var y: u32 = 0;
    while (y < self.height) : (y += 1) {
        var x0: u32 = 0;
        var x1: u32 = self.width - 1;
        while (x0 < x1) {
            const index0 = self.getIndexUnchecked(x0, y);
            const index1 = self.getIndexUnchecked(x1, y);
            self.setIndexUnchecked(x0, y, index1);
            self.setIndexUnchecked(x1, y, index0);
            x0 += 1;
            x1 -= 1;
        }
    }
}

pub fn mirrorVertically(self: Self) !void {
    var tmp = try self.allocator.alloc(u8, self.width);
    defer self.allocator.free(tmp);
    var y0: u32 = 0;
    var y1: u32 = self.height - 1;
    while (y0 < y1) {
        const line0 = self.indices[y0 * self.width .. (y0 + 1) * self.width];
        const line1 = self.indices[y1 * self.width .. (y1 + 1) * self.width];
        std.mem.copy(u8, tmp, line0);
        std.mem.copy(u8, line0, line1);
        std.mem.copy(u8, line1, tmp);
        y0 += 1;
        y1 -= 1;
    }
}

pub fn rotate(self: *Self, clockwise: bool) !void {
    const tmp_bitmap = try self.clone();
    defer tmp_bitmap.deinit();
    std.mem.swap(u32, &self.width, &self.height);
    var y: u32 = 0;
    while (y < self.width) : (y += 1) {
        var x: u32 = 0;
        while (x < self.height) : (x += 1) {
            const index = tmp_bitmap.getIndexUnchecked(x, y);
            if (clockwise) {
                self.setIndexUnchecked(self.width - 1 - y, x, index);
            } else {
                self.setIndexUnchecked(y, self.height - 1 - x, index);
            }
        }
    }
}
