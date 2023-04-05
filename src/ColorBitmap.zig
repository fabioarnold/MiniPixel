const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const col = @import("color.zig");
const Color = col.Color;
const IndexedBitmap = @import("IndexedBitmap.zig");

width: u32,
height: u32,
pixels: []u8,

const ColorBitmap = @This();

pub fn init(allocator: Allocator, width: u32, height: u32) !ColorBitmap {
    var self = ColorBitmap{
        .width = width,
        .height = height,
        .pixels = undefined,
    };
    self.pixels = try allocator.alloc(u8, self.width * self.height * @sizeOf(Color));

    return self;
}

pub fn deinit(self: ColorBitmap, allocator: Allocator) void {
    allocator.free(self.pixels);
}

pub fn clone(self: ColorBitmap, allocator: Allocator) !ColorBitmap {
    return ColorBitmap{
        .width = self.width,
        .height = self.height,
        .pixels = try allocator.dupe(u8, self.pixels),
    };
}

pub fn eql(self: ColorBitmap, bitmap: ColorBitmap) bool {
    return self.width == bitmap.width and
        self.width == bitmap.width and
        std.mem.eql(u8, self.pixels, bitmap.pixels);
}

pub fn canLosslesslyConvertToIndexed(self: ColorBitmap, allocator: Allocator, colormap: []const u8) !bool {
    var color_set = std.AutoHashMap(Color, void).init(allocator);
    defer color_set.deinit();
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const color = colormap[4 * i ..][0..4].*;
        try color_set.put(color, {});
    }
    const pixel_count = self.width * self.height;
    i = 0;
    while (i < pixel_count) : (i += 1) {
        const color = self.pixels[4 * i ..][0..4].*;
        if (!color_set.contains(color)) return false;
    }
    return true;
}

pub fn convertToIndexed(self: ColorBitmap, allocator: Allocator, colormap: []const u8) !IndexedBitmap {
    const indexed_bitmap = try IndexedBitmap.init(allocator, self.width, self.height);
    const pixel_count = indexed_bitmap.width * indexed_bitmap.height;
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        indexed_bitmap.indices[i] = @truncate(u8, col.findNearest(colormap, self.pixels[4 * i ..][0..4].*));
    }
    return indexed_bitmap;
}

pub fn setPixel(self: ColorBitmap, x: i32, y: i32, color: Color) bool {
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

pub fn blendPixel(self: ColorBitmap, x: i32, y: i32, color: Color) bool {
    if (self.getPixel(x, y)) |dst| {
        const blended = col.blend(color, dst);
        self.setPixelUnchecked(@intCast(u32, x), @intCast(u32, y), blended);
        return true;
    }
    return false;
}

pub fn setPixelUnchecked(self: ColorBitmap, x: u32, y: u32, color: Color) void {
    @setRuntimeSafety(false);
    std.debug.assert(x < self.width);
    self.pixels[4 * (y * self.width + x) ..][0..4].* = color;
}

pub fn blendPixelUnchecked(self: ColorBitmap, x: u32, y: u32, color: Color) void {
    const dst = self.getPixelUnchecked(x, y);
    const blended = col.blend(color, dst);
    self.setPixelUnchecked(x, y, blended);
}

pub fn getPixel(self: ColorBitmap, x: i32, y: i32) ?Color {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            return self.getPixelUnchecked(ux, uy);
        }
    }
    return null;
}

pub fn getPixelUnchecked(self: ColorBitmap, x: u32, y: u32) Color {
    @setRuntimeSafety(false);
    std.debug.assert(x < self.width);
    return self.pixels[4 * (y * self.width + x) ..][0..4].*;
}

pub fn copyPixelToUnchecked(self: ColorBitmap, dst: ColorBitmap, x: u32, y: u32) void {
    const src_color = self.getPixelUnchecked(x, y);
    dst.setPixelUnchecked(x, y, src_color);
}

pub fn copyRegion(self: ColorBitmap, dst: ColorBitmap, src_rect: Rectu, dst: Pointu) void {
    
}

pub fn drawLine(self: ColorBitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: Color, skip_first: bool) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    if (!skip_first) {
        _ = self.setPixel(x0, y0, color);
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
        _ = self.setPixel(x, y, color);
    }
}

pub fn blendLine(self: ColorBitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: Color, skip_first: bool) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    if (!skip_first) {
        _ = self.blendPixel(x0, y0, color);
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
        _ = self.blendPixel(x, y, color);
    }
}

pub fn copyLineTo(self: ColorBitmap, dst: ColorBitmap, x0: i32, y0: i32, x1: i32, y1: i32) void {
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

pub fn clear(self: ColorBitmap) void {
    std.mem.set(u8, self.pixels, 0);
}

pub fn fill(self: ColorBitmap, color: Color) void {
    var i: usize = 0;
    while (i < self.pixels.len) : (i += 1) {
        self.pixels[i] = color[i % 4];
    }
}

pub fn floodFill(self: ColorBitmap, allocator: Allocator, x: i32, y: i32, color: Color) !void {
    const old_color = self.getPixel(x, y) orelse return;
    if (col.eql(old_color, color)) return;

    const start_coords = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) };
    self.setPixelUnchecked(start_coords.x, start_coords.y, color);

    var stack = std.ArrayList(struct { x: u32, y: u32 }).init(allocator);
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

pub fn mirrorHorizontally(self: ColorBitmap) void {
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

pub fn mirrorVertically(self: ColorBitmap) void {
    var y0: u32 = 0;
    var y1: u32 = self.height - 1;
    while (y0 < y1) {
        var x: u32 = 0;
        while (x < self.width) : (x += 1) {
            const color0 = self.getPixelUnchecked(x, y0);
            const color1 = self.getPixelUnchecked(x, y1);
            self.setPixelUnchecked(x, y0, color1);
            self.setPixelUnchecked(x, y1, color0);
        }
        y0 += 1;
        y1 -= 1;
    }
}

pub fn rotate(self: *ColorBitmap, allocator: Allocator, clockwise: bool) !void {
    const tmp_bitmap = try self.clone(allocator);
    defer tmp_bitmap.deinit(allocator);
    std.mem.swap(u32, &self.width, &self.height);
    var y: u32 = 0;
    while (y < self.width) : (y += 1) {
        var x: u32 = 0;
        while (x < self.height) : (x += 1) {
            const color = tmp_bitmap.getPixelUnchecked(x, y);
            if (clockwise) {
                self.setPixelUnchecked(self.width - 1 - y, x, color);
            } else {
                self.setPixelUnchecked(y, self.height - 1 - x, color);
            }
        }
    }
}

test "rotate" {
    const initial = ColorBitmap{
        .width = 2,
        .height = 3,
        .pixels = try testing.allocator.dupe(u8, &[_]u8{
            0x01, 0x02, 0x03, 0x04, 0x11, 0x12, 0x13, 0x14,
            0x21, 0x22, 0x23, 0x24, 0x31, 0x32, 0x33, 0x34,
            0x41, 0x42, 0x43, 0x44, 0x51, 0x52, 0x53, 0x54,
        }),
    };
    defer initial.deinit(testing.allocator);

    const rotated = ColorBitmap{
        .width = 3,
        .height = 2,
        .pixels = try testing.allocator.dupe(u8, &[_]u8{
            0x41, 0x42, 0x43, 0x44, 0x21, 0x22, 0x23, 0x24, 0x01, 0x02, 0x03, 0x04,
            0x51, 0x52, 0x53, 0x54, 0x31, 0x32, 0x33, 0x34, 0x11, 0x12, 0x13, 0x14,
        }),
    };
    defer rotated.deinit(testing.allocator);

    var bmp = try initial.clone(testing.allocator);
    defer bmp.deinit(testing.allocator);

    try bmp.rotate(testing.allocator, true);
    try testing.expect(bmp.eql(rotated));
    try bmp.rotate(testing.allocator, false);
    try testing.expect(bmp.eql(initial));
}
