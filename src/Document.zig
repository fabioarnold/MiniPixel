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

const CanvasWidget = @import("CanvasWidget.zig");
const Bitmap = @import("Bitmap.zig");
const col = @import("color.zig");
const Color = col.Color;
const Image = @import("Image.zig");
const Clipboard = @import("Clipboard.zig");
const HistoryBuffer = @import("history.zig").Buffer;
const HistorySnapshot = @import("history.zig").Snapshot;

const Document = @This();

pub const Selection = struct {
    rect: Recti,
    bitmap: Bitmap,
    texture: nvg.Image,
};

const PrimitiveTag = enum {
    brush,
    line,
    none,
};
const PrimitivePreview = union(PrimitiveTag) {
    brush: struct {
        x: u32,
        y: u32,
    },
    line: struct {
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
    },
    none: void,
};

allocator: Allocator,

// For tracking offset after cropping operation
x: i32 = 0,
y: i32 = 0,

texture: nvg.Image, // image for display using nvg
bitmap: Bitmap,
preview_bitmap: Bitmap, // preview brush and lines
last_preview: PrimitivePreview = .none,
dirty: bool = false, // bitmap needs to be uploaded to gpu on next draw call

selection: ?Selection = null,
copy_location: ?Pointi = null, // where the source was copied from

history: *HistoryBuffer,
foreground_color: [4]u8 = [_]u8{ 0, 0, 0, 0xff },
background_color: [4]u8 = [_]u8{ 0xff, 0xff, 0xff, 0xff },

canvas: *CanvasWidget = undefined,

const Self = @This();

pub fn init(allocator: Allocator) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .allocator = allocator,
        .texture = undefined,
        .bitmap = undefined,
        .preview_bitmap = undefined,
        .history = try HistoryBuffer.init(allocator),
    };

    self.bitmap = try Bitmap.init(allocator, 32, 32);
    self.bitmap.fill(self.background_color);
    self.preview_bitmap = try self.bitmap.clone();
    self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);
    try self.history.reset(self);

    return self;
}

pub fn deinit(self: *Self) void {
    self.history.deinit();
    self.bitmap.deinit();
    self.preview_bitmap.deinit();
    nvg.deleteImage(self.texture);
    self.freeSelection();
    self.allocator.destroy(self);
}

pub fn createNew(self: *Self, width: u32, height: u32) !void {
    self.bitmap.deinit();
    self.bitmap = try Bitmap.init(self.allocator, width, height);
    self.x = 0;
    self.y = 0;
    self.bitmap.fill(self.background_color);
    self.preview_bitmap.deinit();
    self.preview_bitmap = try self.bitmap.clone();

    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);

    self.freeSelection();
    try self.history.reset(self);
}

fn imageConvertIndexedToRgba(allocator: Allocator, indexed_image: Image) !Image {
    const image = try Image.initEmptyRgba(allocator, indexed_image.width, indexed_image.height);
    const colormap = indexed_image.colormap.?;
    const pixel_count = indexed_image.width * indexed_image.height;
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        const index = @intCast(usize, indexed_image.pixels[i]);
        const pixel = colormap[4 * index .. 4 * index + 4];
        image.pixels[4 * i + 0] = pixel[0];
        image.pixels[4 * i + 1] = pixel[1];
        image.pixels[4 * i + 2] = pixel[2];
        image.pixels[4 * i + 3] = pixel[3];
    }

    return image;
}

pub fn load(self: *Self, file_path: []const u8) !void {
    var image = try Image.initFromFile(self.allocator, file_path);

    // TODO: support editing indexed images
    if (image.colormap != null) {
        const rgba_image = try imageConvertIndexedToRgba(self.allocator, image);
        image.deinit();
        image = rgba_image;
    }

    self.bitmap.deinit();
    self.bitmap = Bitmap{
        .allocator = self.allocator,
        .width = image.width,
        .height = image.height,
        .pixels = image.pixels,
    };
    self.x = 0;
    self.y = 0;
    self.preview_bitmap.deinit();
    self.preview_bitmap = try self.bitmap.clone();

    // resolution might have changed so recreate image
    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);

    self.freeSelection();
    try self.history.reset(self);
}

pub fn save(self: *Self, file_path: []const u8) !void {
    var image = Image{
        .width = self.bitmap.width,
        .height = self.bitmap.height,
        .pixels = self.bitmap.pixels,
        .allocator = self.allocator,
    };
    try image.writeToFile(file_path);

    //if (c.stbi_write_png(file_path.ptr, @intCast(c_int, self.width), @intCast(c_int, self.height), 4, self.bitmap.ptr, 0) == 0) return error.Fail;
}

pub fn restoreFromSnapshot(self: *Self, allocator: Allocator, snapshot: HistorySnapshot) !void {
    if (self.bitmap.width != snapshot.bitmap.width or self.bitmap.height != snapshot.bitmap.height) {
        self.bitmap.width = snapshot.bitmap.width;
        self.bitmap.height = snapshot.bitmap.height;
        self.bitmap.pixels = try allocator.realloc(self.bitmap.pixels, snapshot.bitmap.pixels.len);
        self.preview_bitmap.width = snapshot.bitmap.width;
        self.preview_bitmap.height = snapshot.bitmap.height;
        self.preview_bitmap.pixels = try allocator.realloc(self.preview_bitmap.pixels, snapshot.bitmap.pixels.len);

        // recreate texture
        nvg.deleteImage(self.texture);
        self.texture = nvg.createImageRgba(snapshot.bitmap.width, snapshot.bitmap.height, .{ .nearest = true }, snapshot.bitmap.pixels);
    }
    std.mem.copy(u8, self.bitmap.pixels, snapshot.bitmap.pixels);
    if (self.x != snapshot.x or self.y != snapshot.y) {
        const dx = snapshot.x - self.x;
        const dy = snapshot.y - self.y;
        self.x = snapshot.x;
        self.y = snapshot.y;
        self.canvas.translateByPixel(dx, dy);
    }
    self.last_preview = .none;
    self.clearPreview();
}

pub fn canUndo(self: Self) bool {
    return self.history.canUndo();
}

pub fn undo(self: *Self) !void {
    try self.history.undo(self.allocator, self);
}

pub fn canRedo(self: Self) bool {
    return self.history.canRedo();
}

pub fn redo(self: *Self) !void {
    try self.history.redo(self.allocator, self);
}

pub fn cut(self: *Self) !void {
    try self.copy();

    if (self.selection != null) {
        self.freeSelection();
    } else {
        self.bitmap.fill(self.background_color);
        self.last_preview = .none;
        self.clearPreview();

        try self.history.pushFrame(self);
    }
}

pub fn copy(self: *Self) !void {
    if (self.selection) |selection| {
        try Clipboard.setImage(self.allocator, Image{
            .width = @intCast(u32, selection.rect.w),
            .height = @intCast(u32, selection.rect.h),
            .pixels = selection.bitmap.pixels,
            .allocator = self.allocator,
        });
        self.copy_location = Pointi{
            .x = selection.rect.x,
            .y = selection.rect.y,
        };
    } else {
        try Clipboard.setImage(self.allocator, Image{
            .width = self.bitmap.width,
            .height = self.bitmap.height,
            .pixels = self.bitmap.pixels,
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

        const x = @intCast(i32, self.bitmap.width / 2) - @intCast(i32, image.width / 2);
        const y = @intCast(i32, self.bitmap.height / 2) - @intCast(i32, image.height / 2);
        var selection_rect = Recti.make(x, y, @intCast(i32, image.width), @intCast(i32, image.height));

        if (self.copy_location) |copy_location| {
            selection_rect.x = copy_location.x;
            selection_rect.y = copy_location.y;
        }

        self.selection = Selection{
            .rect = selection_rect,
            .bitmap = Bitmap{
                .allocator = self.allocator,
                .width = image.width,
                .height = image.height,
                .pixels = image.pixels,
            },
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
    const new_bitmap = try Bitmap.init(self.allocator, width, height);
    //errdefer self.allocator.free(new_bitmap); // TODO: bad because tries for undo stuff at the bottom
    new_bitmap.fill(self.background_color);

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.bitmap.width),
        .h = @intCast(i32, self.bitmap.height),
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
            const di = 4 * ((sy + y) * self.bitmap.width + sx);
            // copy entire line
            std.mem.copy(u8, new_bitmap.pixels[si .. si + 4 * w], self.bitmap.pixels[di .. di + 4 * w]);
        }
    }

    self.bitmap.deinit();
    self.bitmap = new_bitmap;
    self.preview_bitmap.deinit();
    self.preview_bitmap = try self.bitmap.clone();

    nvg.deleteImage(self.texture);
    self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);

    self.x += rect.x;
    self.y += rect.y;
    self.canvas.translateByPixel(rect.x, rect.y);

    try self.history.pushFrame(self);
}

pub fn clearSelection(self: *Self) !void {
    if (self.selection) |selection| {
        const rect = selection.rect;
        const bitmap = selection.bitmap;

        const intersection = rect.intersection(.{
            .x = 0,
            .y = 0,
            .w = @intCast(i32, self.bitmap.width),
            .h = @intCast(i32, self.bitmap.height),
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
                const di = 4 * ((sy + y) * self.bitmap.width + sx);
                // copy entire line
                // std.mem.copy(u8, self.bitmap[di .. di + 4 * w], bitmap[si .. si + 4 * w]);

                // blend each pixel
                var x: u32 = 0;
                while (x < w) : (x += 1) {
                    const src = bitmap.pixels[si + 4 * x .. si + 4 * x + 4];
                    const dst = self.bitmap.pixels[di + 4 * x .. di + 4 * x + 4];
                    const out = col.blend(src, dst);
                    std.mem.copy(u8, dst, &out);
                }
            }
            self.clearPreview();
        }

        self.freeSelection();

        try self.history.pushFrame(self);
    }
}

pub fn makeSelection(self: *Self, rect: Recti) !void {
    std.debug.assert(rect.w > 0 and rect.h > 0);

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.bitmap.width),
        .h = @intCast(i32, self.bitmap.height),
    });
    if (intersection.w > 0 and intersection.h > 0) {
        const w = @intCast(u32, intersection.w);
        const h = @intCast(u32, intersection.h);
        const bitmap = try Bitmap.init(self.allocator, w, h);

        // move pixels
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            const di = 4 * (y * w);
            const sx = @intCast(u32, intersection.x);
            const sy = @intCast(u32, intersection.y);
            const si = 4 * ((sy + y) * self.bitmap.width + sx);
            std.mem.copy(u8, bitmap.pixels[di .. di + 4 * w], self.bitmap.pixels[si .. si + 4 * w]);
            const dst_line = self.bitmap.pixels[si .. si + 4 * w];
            var i: usize = 0;
            while (i < dst_line.len) : (i += 1) {
                dst_line[i] = self.background_color[i % 4];
            }
        }
        self.clearPreview();

        var selection = Selection{
            .rect = intersection,
            .bitmap = bitmap,
            .texture = nvg.createImageRgba(w, h, .{ .nearest = true }, bitmap.pixels),
        };
        self.freeSelection(); // clean up previous selection
        self.selection = selection;
    }
}

pub fn freeSelection(self: *Self) void {
    if (self.selection) |selection| {
        selection.bitmap.deinit();
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

pub fn previewBrush(self: *Self, x: i32, y: i32) void {
    self.clearPreview();
    if (self.preview_bitmap.setPixel(x, y, self.foreground_color)) {
        self.last_preview = PrimitivePreview{ .brush = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) } };
    }
}

pub fn previewStroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    self.clearPreview();
    self.preview_bitmap.drawLine(x0, y0, x1, y1, self.foreground_color);
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
}

pub fn clearPreview(self: *Self) void {
    switch (self.last_preview) {
        .brush => |brush| {
            self.bitmap.copyPixelUnchecked(self.preview_bitmap, brush.x, brush.y);
        },
        .line => |line| {
            self.bitmap.copyLine(self.preview_bitmap, line.x0, line.y0, line.x1, line.y1);
        },
        else => std.mem.copy(u8, self.preview_bitmap.pixels, self.bitmap.pixels),
    }
    self.last_preview = .none;
    self.dirty = true;
}

pub fn fill(self: *Self, color: [4]u8) !void {
    if (self.selection) |*selection| {
        selection.bitmap.fill(color);
        nvg.updateImage(selection.texture, selection.bitmap.pixels);
    } else {
        self.bitmap.fill(color);
        self.last_preview = .none;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn mirrorHorizontally(self: *Self) !void {
    if (self.selection) |*selection| {
        selection.bitmap.mirrorHorizontally();
        nvg.updateImage(selection.texture, selection.bitmap.pixels);
    } else {
        self.bitmap.mirrorHorizontally();
        self.last_preview = .none;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn mirrorVertically(self: *Self) !void {
    if (self.selection) |*selection| {
        try selection.bitmap.mirrorVertically();
        nvg.updateImage(selection.texture, selection.bitmap.pixels);
    } else {
        try self.bitmap.mirrorVertically();
        self.last_preview = .none;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn rotateCw(self: *Self) !void {
    if (self.selection) |*selection| {
        try selection.bitmap.rotateCw();
        selection.rect.w = @intCast(i32, selection.bitmap.width);
        selection.rect.h = @intCast(i32, selection.bitmap.height);
        const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
        selection.rect.x -= d;
        selection.rect.y += d;
        nvg.deleteImage(selection.texture);
        selection.texture = nvg.createImageRgba(
            selection.bitmap.width,
            selection.bitmap.height,
            .{ .nearest = true },
            selection.bitmap.pixels,
        );
    } else {
        try self.bitmap.rotateCw();
        if (self.bitmap.width != self.bitmap.height) {
            const d = @divTrunc(@intCast(i32, self.bitmap.height) - @intCast(i32, self.bitmap.width), 2);
            self.x -= d;
            self.y += d;
            self.canvas.translateByPixel(d, -d);
            nvg.deleteImage(self.texture);
            self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);
        }
        self.last_preview = .none;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn rotateCcw(self: *Self) !void {
    if (self.selection) |*selection| {
        try selection.bitmap.rotateCcw();
        selection.rect.w = @intCast(i32, selection.bitmap.width);
        selection.rect.h = @intCast(i32, selection.bitmap.height);
        const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
        selection.rect.x -= d;
        selection.rect.y += d;
        nvg.deleteImage(selection.texture);
        selection.texture = nvg.createImageRgba(
            selection.bitmap.width,
            selection.bitmap.height,
            .{ .nearest = true },
            selection.bitmap.pixels,
        );
    } else {
        try self.bitmap.rotateCcw();
        if (self.bitmap.width != self.bitmap.height) {
            const d = @divTrunc(@intCast(i32, self.bitmap.height) - @intCast(i32, self.bitmap.width), 2);
            self.x -= d;
            self.y += d;
            self.canvas.translateByPixel(d, -d);
            nvg.deleteImage(self.texture);
            self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);
        }
        self.last_preview = .none;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn beginStroke(self: *Self, x: i32, y: i32) void {
    if (self.bitmap.setPixel(x, y, self.foreground_color)) {
        self.last_preview = PrimitivePreview{ .brush = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) } };
        self.clearPreview();
    }
}

pub fn stroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    self.bitmap.drawLine(x0, y0, x1, y1, self.foreground_color);
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
    self.clearPreview();
}

pub fn endStroke(self: *Self) !void {
    try self.history.pushFrame(self);
}

pub fn pickColor(self: *Self, x: i32, y: i32) ?[4]u8 {
    return self.bitmap.getPixel(x, y);
}

pub fn floodFill(self: *Self, x: i32, y: i32) !void {
    try self.bitmap.floodFill(x, y, self.foreground_color);
    self.last_preview = .none;
    self.clearPreview();
    try self.history.pushFrame(self);
}

pub fn draw(self: *Self) void {
    if (self.dirty) {
        nvg.updateImage(self.texture, self.preview_bitmap.pixels);
        self.dirty = false;
    }
    nvg.beginPath();
    nvg.rect(0, 0, @intToFloat(f32, self.bitmap.width), @intToFloat(f32, self.bitmap.height));
    nvg.fillPaint(nvg.imagePattern(0, 0, @intToFloat(f32, self.bitmap.width), @intToFloat(f32, self.bitmap.height), 0, self.texture, 1));
    nvg.fill();
}
