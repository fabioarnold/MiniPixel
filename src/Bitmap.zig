const std = @import("std");
const Allocator = std.mem.Allocator;

const col = @import("color.zig");
const Color = col.Color;

allocator: Allocator,

width: u32,
height: u32,
pixels: []u8,

const Self = @This();
const Bitmap = @This();

pub fn init(allocator: Allocator, width: u32, height: u32) !Self {
    var self = Self{
        .allocator = allocator,
        .width = width,
        .height = height,
        .pixels = undefined,
    };
    self.pixels = try allocator.alloc(u8, self.width * self.height * @sizeOf(Color));

    return self;
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.pixels);
}

pub fn clone(self: Self) !Self {
    return Self{
        .allocator = self.allocator,
        .width = self.width,
        .height = self.height,
        .pixels = try self.allocator.dupe(u8, self.pixels),
    };
}

pub fn eql(self: Self, bitmap: Bitmap) bool {
    return self.width == bitmap.width and
        self.width == bitmap.width and
        std.mem.eql(u8, self.pixels, bitmap.pixels);
}

pub fn setPixel(self: Self, x: i32, y: i32, color: Color) bool {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            self.setPixelUnchecked(ux, uy, color);
            return true;
        }
    }
    return false;
}

pub fn setPixelUnchecked(self: Self, x: u32, y: u32, color: Color) void {
    std.debug.assert(x < self.width);
    const i = (y * self.width + x) * @sizeOf(Color);
    self.pixels[i + 0] = color[0];
    self.pixels[i + 1] = color[1];
    self.pixels[i + 2] = color[2];
    self.pixels[i + 3] = color[3];
}

pub fn getPixel(self: Self, x: i32, y: i32) ?Color {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            return self.getPixelUnchecked(ux, uy);
        }
    }
    return null;
}

pub fn getPixelUnchecked(self: Self, x: u32, y: u32) Color {
    std.debug.assert(x < self.width);
    const i = (y * self.width + x) * 4;
    return Color{
        self.pixels[i + 0],
        self.pixels[i + 1],
        self.pixels[i + 2],
        self.pixels[i + 3],
    };
}

pub fn copyPixelUnchecked(self: Self, dst: Bitmap, x: u32, y: u32) void {
    const src_color = self.getPixelUnchecked(x, y);
    dst.setPixelUnchecked(x, y, src_color);
}

pub fn drawLine(self: Self, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    var x = x0;
    var y = y0;
    while (true) {
        if (!self.setPixel(x, y, color)) break;
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

pub fn copyLine(self: Self, dst: Bitmap, x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    var x = x0;
    var y = y0;
    while (true) {
        if (self.getPixel(x, y)) |src_color| {
            dst.setPixelUnchecked(@intCast(u32, x), @intCast(u32, y), src_color);
        } else break;
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
    std.mem.set(u8, self.pixels, 0);
}

pub fn fill(self: Self, color: Color) void {
    var i: usize = 0;
    while (i < self.pixels.len) : (i += 1) {
        self.pixels[i] = color[i % 4];
    }
}

pub fn floodFill(self: *Self, x: i32, y: i32, color: Color) !void {
    const old_color = self.getPixel(x, y) orelse return;
    if (col.eql(old_color, color)) return;

    const start_coords = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) };
    self.setPixelUnchecked(start_coords.x, start_coords.y, color);

    var stack = std.ArrayList(struct { x: u32, y: u32 }).init(self.allocator);
    try stack.ensureTotalCapacity(self.width * self.height / 2);
    defer stack.deinit();
    try stack.append(start_coords);

    while (stack.items.len > 0) {
        const coords = stack.pop();
        if (coords.y > 0) {
            const new_coords = .{ .x = coords.x, .y = coords.y - 1 };
            if (col.eql(self.getPixelUnchecked(new_coords.x, new_coords.y), old_color)) {
                self.setPixelUnchecked(new_coords.x, new_coords.y, color);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.y < self.height - 1) {
            const new_coords = .{ .x = coords.x, .y = coords.y + 1 };
            if (col.eql(self.getPixelUnchecked(new_coords.x, new_coords.y), old_color)) {
                self.setPixelUnchecked(new_coords.x, new_coords.y, color);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.x > 0) {
            const new_coords = .{ .x = coords.x - 1, .y = coords.y };
            if (col.eql(self.getPixelUnchecked(new_coords.x, new_coords.y), old_color)) {
                self.setPixelUnchecked(new_coords.x, new_coords.y, color);
                stack.appendAssumeCapacity(new_coords);
            }
        }
        if (coords.x < self.width - 1) {
            const new_coords = .{ .x = coords.x + 1, .y = coords.y };
            if (col.eql(self.getPixelUnchecked(new_coords.x, new_coords.y), old_color)) {
                self.setPixelUnchecked(new_coords.x, new_coords.y, color);
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
            const color0 = self.getPixelUnchecked(x0, y);
            const color1 = self.getPixelUnchecked(x1, y);
            self.setPixelUnchecked(x0, y, color1);
            self.setPixelUnchecked(x1, y, color0);
            x0 += 1;
            x1 -= 1;
        }
    }
}

pub fn mirrorVertically(self: Self) !void {
    const pitch = 4 * self.width;
    var tmp = try self.allocator.alloc(u8, pitch);
    defer self.allocator.free(tmp);
    var y0: u32 = 0;
    var y1: u32 = self.height - 1;
    while (y0 < y1) {
        const line0 = self.pixels[y0 * pitch .. (y0 + 1) * pitch];
        const line1 = self.pixels[y1 * pitch .. (y1 + 1) * pitch];
        std.mem.copy(u8, tmp, line0);
        std.mem.copy(u8, line0, line1);
        std.mem.copy(u8, line1, tmp);
        y0 += 1;
        y1 -= 1;
    }
}

pub fn rotateCw(self: *Self) !void {
    const tmp_bitmap = try self.clone();
    defer tmp_bitmap.deinit();
    std.mem.swap(u32, &self.width, &self.height);
    var y: u32 = 0;
    while (y < self.width) : (y += 1) {
        var x: u32 = 0;
        while (x < self.height) : (x += 1) {
            const color = tmp_bitmap.getPixelUnchecked(x, y);
            self.setPixelUnchecked(self.width - 1 - y, x, color);
        }
    }
}

pub fn rotateCcw(self: *Self) !void {
    const tmp_bitmap = try self.clone();
    defer tmp_bitmap.deinit();
    std.mem.swap(u32, &self.width, &self.height);
    var y: u32 = 0;
    while (y < self.width) : (y += 1) {
        var x: u32 = 0;
        while (x < self.height) : (x += 1) {
            const color = tmp_bitmap.getPixelUnchecked(x, y);
            self.setPixelUnchecked(y, self.height - 1 - x, color);
        }
    }
}
