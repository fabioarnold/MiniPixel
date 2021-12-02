const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui");
const geometry = gui.geometry;
const Point = geometry.Point;
const Pointi = Point(i32);
const Pointu = Point(u32);
const Rect = geometry.Rect;
const Recti = Rect(i32);

const Image = @import("Image.zig");
const Clipboard = @import("Clipboard.zig");

const Document = @This();

pub const Selection = struct {
    rect: Recti,
    bitmap: []u8,
    texture: nvg.Image,
};

const UndoStep = union(enum) {
    document: struct {
        width: u32,
        height: u32,
        bitmap: []u8,
    },

    fn make(allocator: *Allocator, document: *Document) !UndoStep {
        return UndoStep{ .document = .{
            .width = document.width,
            .height = document.height,
            .bitmap = try allocator.dupe(u8, document.bitmap),
        } };
    }

    fn deinit(self: UndoStep, allocator: *Allocator) void {
        switch (self) {
            .document => |d| allocator.free(d.bitmap),
        }
    }

    fn hasChanges(self: UndoStep, document: *Document) bool {
        return switch (self) {
            .document => |d| d.width != document.width or
                d.width != document.width or
                !std.mem.eql(u8, d.bitmap, document.bitmap),
        };
    }

    fn undo(self: UndoStep, allocator: *Allocator, document: *Document) !void {
        switch (self) {
            .document => |d| {
                if (document.width != d.width or document.height != d.height) {
                    document.bitmap = try allocator.realloc(document.bitmap, d.bitmap.len);
                    document.preview_bitmap = try allocator.realloc(document.preview_bitmap, d.bitmap.len);

                    // recreate texture
                    nvg.deleteImage(document.texture);
                    document.texture = nvg.createImageRgba(d.width, d.height, .{ .nearest = true }, d.bitmap);
                }
                std.mem.copy(u8, document.bitmap, d.bitmap);
                document.width = d.width;
                document.height = d.height;
            },
        }
    }

    fn redo(self: UndoStep, allocator: *Allocator, document: *Document) !void {
        try self.undo(allocator, document);
    }
};

const UndoSystem = struct {
    allocator: *Allocator,
    stack: ArrayList(UndoStep),
    index: usize = 0,

    undo_listener_address: usize = 0, // TODO: this is pretty hacky
    onUndoChangedFn: ?fn (*Document) void = null,

    fn init(allocator: *Allocator) !*UndoSystem {
        var self = try allocator.create(UndoSystem);
        self.* = UndoSystem{
            .allocator = allocator,
            .stack = ArrayList(UndoStep).init(allocator),
        };
        return self;
    }

    fn deinit(self: *UndoSystem) void {
        for (self.stack.items) |step| {
            step.deinit(self.allocator);
        }
        self.stack.deinit();
        self.allocator.destroy(self);
    }

    fn clearAndFreeStack(self: *UndoSystem) void {
        for (self.stack.items) |step| {
            step.deinit(self.allocator);
        }
        self.stack.shrinkRetainingCapacity(0);
        self.index = 0;
    }

    fn reset(self: *UndoSystem, document: *Document) !void {
        self.clearAndFreeStack();
        try self.stack.append(try UndoStep.make(self.allocator, document));
        self.notifyChanged(document);
    }

    fn notifyChanged(self: UndoSystem, document: *Document) void {
        if (self.onUndoChangedFn) |onUndoChanged| onUndoChanged(document);
    }

    fn canUndo(self: UndoSystem) bool {
        return self.index > 0;
    }

    fn undo(self: *UndoSystem, allocator: *Allocator, document: *Document) !void {
        if (!self.canUndo()) return;
        self.index -= 1;
        const step = self.stack.items[self.index];
        try step.undo(allocator, document);
        document.clearPreview();
        self.notifyChanged(document);
    }

    fn canRedo(self: UndoSystem) bool {
        return self.index + 1 < self.stack.items.len;
    }

    fn redo(self: *UndoSystem, allocator: *Allocator, document: *Document) !void {
        if (!self.canRedo()) return;
        self.index += 1;
        const step = self.stack.items[self.index];
        try step.redo(allocator, document);
        document.clearPreview();
        self.notifyChanged(document);
    }

    fn pushFrame(self: *UndoSystem, document: *Document) !void { // TODO: handle error cases
        // do comparison
        const top = self.stack.items[self.index];
        if (!top.hasChanges(document)) return;

        // create new step
        self.index += 1;
        for (self.stack.items[self.index..self.stack.items.len]) |step| {
            step.deinit(self.allocator);
        }
        self.stack.shrinkRetainingCapacity(self.index);
        try self.stack.append(try UndoStep.make(self.allocator, document));
        self.notifyChanged(document);
    }
};

allocator: *Allocator,

width: u32 = 32,
height: u32 = 32,

texture: nvg.Image, // image for display using nvg
bitmap: []u8,
preview_bitmap: []u8, // preview brush and lines
colormap: ?[]u8 = null, // if this is set bitmap is an indexmap into this colormap
dirty: bool = false, // bitmap needs to be uploaded to gpu on next draw call

selection: ?Selection = null,
copy_location: ?Pointi = null, // where the source was copied from

undo_system: *UndoSystem,
foreground_color: [4]u8 = [_]u8{ 0, 0, 0, 0xff },
background_color: [4]u8 = [_]u8{ 0xff, 0xff, 0xff, 0xff },

const Self = @This();

pub fn init(allocator: *Allocator) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .allocator = allocator,
        .texture = undefined,
        .bitmap = undefined,
        .preview_bitmap = undefined,
        .undo_system = try UndoSystem.init(allocator),
    };

    self.bitmap = try self.allocator.alloc(u8, 4 * self.width * self.height);
    var i: usize = 0;
    while (i < self.bitmap.len) : (i += 1) {
        self.bitmap[i] = self.background_color[i % 4];
    }
    self.preview_bitmap = try self.allocator.alloc(u8, 4 * self.width * self.height);
    std.mem.copy(u8, self.preview_bitmap, self.bitmap);
    self.texture = nvg.createImageRgba(self.width, self.height, .{ .nearest = true }, self.bitmap);
    try self.undo_system.reset(self);

    return self;
}

pub fn deinit(self: *Self) void {
    self.undo_system.deinit();
    self.allocator.free(self.bitmap);
    self.allocator.free(self.preview_bitmap);
    nvg.deleteImage(self.texture);
    self.freeSelection();
    self.allocator.destroy(self);
}

pub fn createNew(self: *Self, width: u32, height: u32) !void {
    const new_bitmap = try self.allocator.alloc(u8, 4 * width * height);
    self.allocator.free(self.bitmap);
    self.bitmap = new_bitmap;
    self.width = width;
    self.height = height;
    var i: usize = 0;
    while (i < self.bitmap.len) : (i += 1) {
        self.bitmap[i] = self.background_color[i % 4];
    }
    self.allocator.free(self.preview_bitmap);
    self.preview_bitmap = try self.allocator.dupe(u8, self.bitmap);

    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.width, self.height, .{ .nearest = true }, self.bitmap);

    self.freeSelection();
    try self.undo_system.reset(self);
}

pub fn load(self: *Self, file_path: []const u8) !void {
    const image = try Image.initFromFile(self.allocator, file_path);
    std.debug.assert(image.colormap == null); // TODO: handle palette
    self.allocator.free(self.bitmap);
    self.bitmap = image.pixels;
    self.width = image.width;
    self.height = image.height;
    self.allocator.free(self.preview_bitmap);
    self.preview_bitmap = try self.allocator.dupe(u8, self.bitmap);

    // resolution might have change so recreate image
    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.width, self.height, .{ .nearest = true }, self.bitmap);

    self.freeSelection();
    try self.undo_system.reset(self);
}

pub fn save(self: *Self, file_path: []const u8) !void {
    var image = Image{
        .width = self.width,
        .height = self.height,
        .pixels = self.bitmap,
        .allocator = self.allocator,
    };
    try image.writeToFile(file_path);

    //if (c.stbi_write_png(file_path.ptr, @intCast(c_int, self.width), @intCast(c_int, self.height), 4, self.bitmap.ptr, 0) == 0) return error.Fail;
}

pub fn canUndo(self: Self) bool {
    return self.undo_system.canUndo();
}

pub fn undo(self: *Self) !void {
    try self.undo_system.undo(self.allocator, self);
}

pub fn canRedo(self: Self) bool {
    return self.undo_system.canRedo();
}

pub fn redo(self: *Self) !void {
    try self.undo_system.redo(self.allocator, self);
}

pub fn cut(self: *Self) !void {
    try self.copy();

    if (self.selection != null) {
        self.freeSelection();
    } else {
        // clear image
        std.mem.set(u8, self.bitmap, 0);
        self.clearPreview();
    }
}

pub fn copy(self: *Self) !void {
    if (self.selection) |selection| {
        try Clipboard.setImage(self.allocator, Image{
            .width = @intCast(u32, selection.rect.w),
            .height = @intCast(u32, selection.rect.h),
            .pixels = selection.bitmap,
            .allocator = self.allocator,
        });
        self.copy_location = Pointi{
            .x = selection.rect.x,
            .y = selection.rect.y,
        };
    } else {
        try Clipboard.setImage(self.allocator, Image{
            .width = self.width,
            .height = self.height,
            .pixels = self.bitmap,
            .allocator = self.allocator,
        });
        self.copy_location = null;
    }
}

pub fn paste(self: *Self) !void {
    if (try Clipboard.getImage(self.allocator)) |image| {
        errdefer self.allocator.free(image.pixels);

        if (self.selection) |_| {
            try self.clearSelection();
        }

        const x = @intCast(i32, self.width / 2) - @intCast(i32, image.width / 2);
        const y = @intCast(i32, self.height / 2) - @intCast(i32, image.height / 2);
        var selection_rect = Recti.make(x, y, @intCast(i32, image.width), @intCast(i32, image.height));

        if (self.copy_location) |copy_location| {
            selection_rect.x = copy_location.x;
            selection_rect.y = copy_location.y;
        }

        self.selection = Selection{
            .rect = selection_rect,
            .bitmap = image.pixels,
            .texture = nvg.createImageRgba(
                image.width,
                image.height,
                .{ .nearest = true },
                image.pixels,
            ),
        };
    }
}

pub fn crop(self: *Self, rect: Recti) !void {
    if (rect.w < 1 or rect.h < 1) return error.InvalidCropRect;
    const width = @intCast(u32, rect.w);
    const height = @intCast(u32, rect.h);
    const new_bitmap = try self.allocator.alloc(u8, 4 * width * height);
    //errdefer self.allocator.free(new_bitmap); // TODO: bad because tries for undo stuff at the bottom
    std.mem.set(u8, new_bitmap, 0xff); // TODO: custom background

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.width),
        .h = @intCast(i32, self.height),
    });
    if (intersection.w > 0 and intersection.h > 0) {
        const ox = if (rect.x < 0) @intCast(u32, -rect.x) else 0;
        const oy = if (rect.y < 0) @intCast(u32, -rect.y) else 0;
        const sx = @intCast(u32, intersection.x);
        const sy = @intCast(u32, intersection.y);
        const w = @intCast(u32, intersection.w);
        const h = @intCast(u32, intersection.h);
        // blit to source
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
            const di = 4 * ((sy + y) * self.width + sx);
            // copy entire line
            std.mem.copy(u8, new_bitmap[si .. si + 4 * w], self.bitmap[di .. di + 4 * w]);
        }
    }

    self.allocator.free(self.bitmap);
    self.bitmap = new_bitmap;
    self.width = width;
    self.height = height;
    self.allocator.free(self.preview_bitmap);
    self.preview_bitmap = try self.allocator.dupe(u8, self.bitmap);

    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.width, self.height, .{ .nearest = true }, self.bitmap);

    // TODO: undo stuff handle new dimensions
    try self.undo_system.pushFrame(self);
}

fn mul8(a: u8, b: u8) u8 {
    return @truncate(u8, (@as(u16, a) * @as(u16, b)) / 0xff);
}
fn div8(a: u8, b: u8) u8 {
    return @truncate(u8, @divTrunc(@as(u16, a) * 0xff, @as(u16, b)));
}
// blend color a over b (Porter Duff)
// a_out = a_a + a_b * (1 - a_a)
// c_out = (c_a * a_a + c_b * a_b * (1 - a_a)) / a_out
fn blendColor(a: []u8, b: []u8) [4]u8 {
    var out: [4]u8 = [_]u8{0} ** 4;
    const fac = mul8(b[3], 0xff - a[3]);
    out[3] = a[3] + fac;
    if (out[3] > 0) {
        out[0] = div8(mul8(a[0], a[3]) + mul8(b[0], fac), out[3]);
        out[1] = div8(mul8(a[1], a[3]) + mul8(b[1], fac), out[3]);
        out[2] = div8(mul8(a[2], a[3]) + mul8(b[2], fac), out[3]);
    }
    return out;
}

pub fn clearSelection(self: *Self) !void {
    if (self.selection) |selection| {
        const rect = selection.rect;
        const bitmap = selection.bitmap;

        const intersection = rect.intersection(.{
            .x = 0,
            .y = 0,
            .w = @intCast(i32, self.width),
            .h = @intCast(i32, self.height),
        });
        if (intersection.w > 0 and intersection.h > 0) {
            const ox = if (rect.x < 0) @intCast(u32, -rect.x) else 0;
            const oy = if (rect.y < 0) @intCast(u32, -rect.y) else 0;
            const sx = @intCast(u32, intersection.x);
            const sy = @intCast(u32, intersection.y);
            const w = @intCast(u32, intersection.w);
            const h = @intCast(u32, intersection.h);
            // blit to source
            var y: u32 = 0;
            while (y < h) : (y += 1) {
                const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
                const di = 4 * ((sy + y) * self.width + sx);
                // copy entire line
                // std.mem.copy(u8, self.bitmap[di .. di + 4 * w], bitmap[si .. si + 4 * w]);

                // blend each pixel
                var x: u32 = 0;
                while (x < w) : (x += 1) {
                    const src = bitmap[si + 4 * x .. si + 4 * x + 4];
                    const dst = self.bitmap[di + 4 * x .. di + 4 * x + 4];
                    const out = blendColor(src, dst);
                    std.mem.copy(u8, dst, out[0..]);
                }
            }
            self.clearPreview();
        }

        self.freeSelection();

        try self.undo_system.pushFrame(self);
    }
}

pub fn makeSelection(self: *Self, rect: Recti) !void {
    std.debug.assert(self.colormap == null); // TODO

    std.debug.assert(rect.w > 0 and rect.h > 0);

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.width),
        .h = @intCast(i32, self.height),
    });
    if (intersection.w > 0 and intersection.h > 0) {
        const w = @intCast(u32, intersection.w);
        const h = @intCast(u32, intersection.h);
        const bitmap = try self.allocator.alloc(u8, 4 * w * h); // RGBA

        // move pixels
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            const di = 4 * (y * w);
            const sx = @intCast(u32, intersection.x);
            const sy = @intCast(u32, intersection.y);
            const si = 4 * ((sy + y) * self.width + sx);
            std.mem.copy(u8, bitmap[di .. di + 4 * w], self.bitmap[si .. si + 4 * w]);
            const dst_line = self.bitmap[si .. si + 4 * w];
            var i: usize = 0;
            while (i < dst_line.len) : (i += 1) {
                dst_line[i] = self.background_color[i % 4];
            }
        }
        self.clearPreview();

        var selection = Selection{
            .rect = intersection,
            .bitmap = bitmap,
            .texture = nvg.createImageRgba(w, h, .{ .nearest = true }, bitmap),
        };
        self.freeSelection(); // clean up previous selection
        self.selection = selection;
    }
}

pub fn freeSelection(self: *Self) void {
    if (self.selection) |selection| {
        self.allocator.free(selection.bitmap);
        nvg.deleteImage(selection.texture);
        self.selection = null;
    }
}

pub fn setForegroundColorRgba(self: *Self, color: [4]u8) void {
    self.foreground_color = color;
}

pub fn setBackgroundColorRgba(self: *Self, color: [4]u8) void {
    self.background_color = color;
}

fn setPixel(bitmap: []u8, w: u32, h: u32, x: i32, y: i32, color: [4]u8) void {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < w and uy < h) {
            setPixelUnchecked(bitmap, w, ux, uy, color);
        }
    }
}

fn setPixelUnchecked(bitmap: []u8, w: u32, x: u32, y: u32, color: [4]u8) void {
    std.debug.assert(x < w);
    const i = (y * w + x) * 4;
    bitmap[i + 0] = color[0];
    bitmap[i + 1] = color[1];
    bitmap[i + 2] = color[2];
    bitmap[i + 3] = color[3];
}

fn getPixel(self: Self, x: i32, y: i32) ?[4]u8 {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(u32, x);
        const uy = @intCast(u32, y);
        if (ux < self.width and uy < self.height) {
            return getPixelUnchecked(self.bitmap, self.width, ux, uy);
        }
    }
    return null;
}

fn getPixelUnchecked(bitmap: []u8, w: u32, x: u32, y: u32) [4]u8 {
    std.debug.assert(x < w);
    const i = (y * w + x) * 4;
    return [_]u8{
        bitmap[i + 0],
        bitmap[i + 1],
        bitmap[i + 2],
        bitmap[i + 3],
    };
}

fn drawLine(bitmap: []u8, w: u32, h: u32, x0: i32, y0: i32, x1: i32, y1: i32, color: [4]u8) void {
    const dx = std.math.absInt(x1 - x0) catch unreachable;
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy = -(std.math.absInt(y1 - y0) catch unreachable);
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    var x = x0;
    var y = y0;
    while (true) {
        setPixel(bitmap, w, h, x, y, color);
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

pub fn previewBrush(self: *Self, x: i32, y: i32) void {
    self.clearPreview();
    setPixel(self.preview_bitmap, self.width, self.height, x, y, self.foreground_color);
}

pub fn previewStroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    self.clearPreview();
    drawLine(self.preview_bitmap, self.width, self.height, x0, y0, x1, y1, self.foreground_color);
}

pub fn clearPreview(self: *Self) void {
    std.mem.copy(u8, self.preview_bitmap, self.bitmap);
    self.dirty = true;
}

pub fn fill(self: *Self, color: [4]u8) !void {
    if (self.selection) |*selection| {
        const w = @intCast(u32, selection.rect.w);
        const h = @intCast(u32, selection.rect.h);
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            var x: u32 = 0;
            while (x < w) : (x += 1) {
                setPixelUnchecked(selection.bitmap, w, x, y, color);
            }
        }
        nvg.updateImage(selection.texture, selection.bitmap);
    } else {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                setPixelUnchecked(self.bitmap, self.width, x, y, color);
            }
        }
        self.clearPreview();
        try self.undo_system.pushFrame(self);
    }
}

pub fn mirrorHorizontally(self: *Self) !void {
    if (self.selection) |*selection| {
        const w = @intCast(u32, selection.rect.w);
        const h = @intCast(u32, selection.rect.h);
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            var x0: u32 = 0;
            var x1: u32 = w - 1;
            while (x0 < x1) {
                const color0 = getPixelUnchecked(selection.bitmap, w, x0, y);
                const color1 = getPixelUnchecked(selection.bitmap, w, x1, y);
                setPixelUnchecked(selection.bitmap, w, x0, y, color1);
                setPixelUnchecked(selection.bitmap, w, x1, y, color0);
                x0 += 1;
                x1 -= 1;
            }
        }
        nvg.updateImage(selection.texture, selection.bitmap);
    } else {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x0: u32 = 0;
            var x1: u32 = self.width - 1;
            while (x0 < x1) {
                const color0 = getPixelUnchecked(self.bitmap, self.width, x0, y);
                const color1 = getPixelUnchecked(self.bitmap, self.width, x1, y);
                setPixelUnchecked(self.bitmap, self.width, x0, y, color1);
                setPixelUnchecked(self.bitmap, self.width, x1, y, color0);
                x0 += 1;
                x1 -= 1;
            }
        }
        self.clearPreview();
        try self.undo_system.pushFrame(self);
    }
}

pub fn mirrorVertically(self: *Self) !void {
    var w: u32 = undefined;
    var h: u32 = undefined;
    var bitmap: []u8 = undefined;
    if (self.selection) |*selection| {
        w = @intCast(u32, selection.rect.w);
        h = @intCast(u32, selection.rect.h);
        bitmap = selection.bitmap;
    } else {
        w = self.width;
        h = self.height;
        bitmap = self.bitmap;
    }
    const pitch = 4 * w;
    var tmp = try self.allocator.alloc(u8, pitch);
    defer self.allocator.free(tmp);
    var y0: u32 = 0;
    var y1: u32 = h - 1;
    while (y0 < y1) {
        const line0 = bitmap[y0 * pitch .. (y0 + 1) * pitch];
        const line1 = bitmap[y1 * pitch .. (y1 + 1) * pitch];
        std.mem.copy(u8, tmp, line0);
        std.mem.copy(u8, line0, line1);
        std.mem.copy(u8, line1, tmp);
        y0 += 1;
        y1 -= 1;
    }
    if (self.selection) |*selection| {
        nvg.updateImage(selection.texture, selection.bitmap);
    } else {
        self.clearPreview();
        try self.undo_system.pushFrame(self);
    }
}

pub fn rotateCw(self: *Self) !void {
    var w: u32 = undefined;
    var h: u32 = undefined;
    var bitmap: []u8 = undefined;
    if (self.selection) |*selection| {
        w = @intCast(u32, selection.rect.w);
        h = @intCast(u32, selection.rect.h);
        bitmap = selection.bitmap;
    } else {
        w = self.width;
        h = self.height;
        bitmap = self.bitmap;
    }

    const tmp_bitmap = try self.allocator.dupe(u8, bitmap);
    var y: u32 = 0;
    while (y < h) : (y += 1) {
        var x: u32 = 0;
        while (x < w) : (x += 1) {
            const color = getPixelUnchecked(tmp_bitmap, w, x, y);
            setPixelUnchecked(bitmap, h, h - 1 - y, x, color);
        }
    }
    self.allocator.free(tmp_bitmap);

    if (self.selection) |*selection| {
        const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
        selection.rect.x += d;
        selection.rect.y -= d;
        std.mem.swap(i32, &selection.rect.w, &selection.rect.h);
        nvg.deleteImage(selection.texture);
        selection.texture = nvg.createImageRgba(h, w, .{ .nearest = true }, selection.bitmap);
    } else {
        std.mem.swap(u32, &self.width, &self.height);
        self.clearPreview();
        try self.undo_system.pushFrame(self);
    }
}

pub fn rotateCcw(self: *Self) !void {
    var w: u32 = undefined;
    var h: u32 = undefined;
    var bitmap: []u8 = undefined;
    if (self.selection) |*selection| {
        w = @intCast(u32, selection.rect.w);
        h = @intCast(u32, selection.rect.h);
        bitmap = selection.bitmap;
    } else {
        w = self.width;
        h = self.height;
        bitmap = self.bitmap;
    }

    const tmp_bitmap = try self.allocator.dupe(u8, bitmap);
    var y: u32 = 0;
    while (y < h) : (y += 1) {
        var x: u32 = 0;
        while (x < w) : (x += 1) {
            const color = getPixelUnchecked(tmp_bitmap, w, x, y);
            setPixelUnchecked(bitmap, h, y, w - 1 - x, color);
        }
    }
    self.allocator.free(tmp_bitmap);

    if (self.selection) |*selection| {
        const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
        selection.rect.x += d;
        selection.rect.y -= d;
        std.mem.swap(i32, &selection.rect.w, &selection.rect.h);
        nvg.deleteImage(selection.texture);
        selection.texture = nvg.createImageRgba(h, w, .{ .nearest = true }, selection.bitmap);
    } else {
        std.mem.swap(u32, &self.width, &self.height);
        self.clearPreview();
        try self.undo_system.pushFrame(self);
    }
}

pub fn floodFill(self: *Self, x: i32, y: i32) !void {
    const old_color = self.pickColor(x, y) orelse return;
    if (std.mem.eql(u8, old_color[0..], self.foreground_color[0..])) return;

    const bitmap = self.bitmap;

    var stack = std.ArrayList(struct { x: i32, y: i32 }).init(self.allocator);
    defer stack.deinit();

    try stack.append(.{ .x = x, .y = y });
    while (stack.items.len > 0) {
        const coords = stack.pop();
        if (self.getPixel(coords.x, coords.y)) |color| {
            if (std.mem.eql(u8, color[0..], old_color[0..])) {
                setPixelUnchecked(
                    bitmap,
                    self.width,
                    @intCast(u32, coords.x),
                    @intCast(u32, coords.y),
                    self.foreground_color,
                );
                try stack.append(.{ .x = coords.x, .y = coords.y - 1 });
                try stack.append(.{ .x = coords.x, .y = coords.y + 1 });
                try stack.append(.{ .x = coords.x - 1, .y = coords.y });
                try stack.append(.{ .x = coords.x + 1, .y = coords.y });
            }
        }
    }
    self.clearPreview();
    try self.undo_system.pushFrame(self);
}

pub fn beginStroke(self: *Self, x: i32, y: i32) void {
    setPixel(self.bitmap, self.width, self.height, x, y, self.foreground_color);
    self.clearPreview();
}

pub fn stroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    drawLine(self.bitmap, self.width, self.height, x0, y0, x1, y1, self.foreground_color);
    self.clearPreview();
}

pub fn endStroke(self: *Self) !void {
    try self.undo_system.pushFrame(self);
}

pub fn pickColor(self: *Self, x: i32, y: i32) ?[4]u8 {
    return self.getPixel(x, y);
}

pub fn draw(self: *Self) void {
    if (self.dirty) {
        nvg.updateImage(self.texture, self.preview_bitmap);
        self.dirty = false;
    }
    nvg.beginPath();
    nvg.rect(0, 0, @intToFloat(f32, self.width), @intToFloat(f32, self.height));
    nvg.fillPaint(nvg.imagePattern(0, 0, @intToFloat(f32, self.width), @intToFloat(f32, self.height), 0, self.texture, 1));
    nvg.fill();
}
