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
const ColorBitmap = @import("Bitmap.zig");
const IndexedBitmap = @import("IndexedBitmap.zig");
const col = @import("color.zig");
const Color = col.Color;
const BlendMode = col.BlendMode;
const Image = @import("Image.zig");
const Clipboard = @import("Clipboard.zig");
const HistoryBuffer = @import("history.zig").Buffer;
const HistorySnapshot = @import("history.zig").Snapshot;

const Document = @This();

const BitmapType = enum(u8) {
    color,
    indexed,
};
const Bitmap = union(BitmapType) {
    color: ColorBitmap,
    indexed: IndexedBitmap,

    fn deinit(self: Bitmap) void {
        switch (self) {
            .color => |color_bitmap| color_bitmap.deinit(),
            .indexed => |indexed_bitmap| indexed_bitmap.deinit(),
        }
    }

    fn clone(self: Bitmap) !Bitmap {
        return switch (self) {
            .color => |color_bitmap| Bitmap{ .color = try color_bitmap.clone() },
            .indexed => |indexed_bitmap| Bitmap{ .indexed = try indexed_bitmap.clone() },
        };
    }

    fn toImage(self: *Bitmap, allocator: Allocator) Image {
        return switch (self.*) {
            .color => |color_bitmap| Image{
                .allocator = allocator,
                .width = color_bitmap.width,
                .height = color_bitmap.height,
                .pixels = color_bitmap.pixels,
            },
            .indexed => |*indexed_bitmap| Image{
                .allocator = allocator,
                .width = indexed_bitmap.width,
                .height = indexed_bitmap.height,
                .pixels = indexed_bitmap.indices,
                .colormap = indexed_bitmap.colormap,
            },
        };
    }

    fn mirrorHorizontally(self: Bitmap) void {
        switch (self) {
            .color => |color_bitmap| color_bitmap.mirrorHorizontally(),
            .indexed => |indexed_bitmap| indexed_bitmap.mirrorHorizontally(),
        }
    }

    fn mirrorVertically(self: Bitmap) !void {
        try switch (self) {
            .color => |color_bitmap| color_bitmap.mirrorVertically(),
            .indexed => |indexed_bitmap| indexed_bitmap.mirrorVertically(),
        };
    }
};

pub const Selection = struct {
    rect: Recti,
    bitmap: Bitmap,
    texture: nvg.Image,
};

const PrimitiveTag = enum {
    none,
    brush,
    line,
    full,
};
const PrimitivePreview = union(PrimitiveTag) {
    none: void,
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
    full: void,
};

allocator: Allocator,

// For tracking offset after cropping operation
x: i32 = 0,
y: i32 = 0,

texture: nvg.Image, // image for display using nvg
texture_palette: ?nvg.Image = null,
bitmap: Bitmap,
preview_bitmap: Bitmap, // preview brush and lines
last_preview: PrimitivePreview = .none,
dirty: bool = false, // bitmap needs to be uploaded to gpu on next draw call

selection: ?Selection = null,
copy_location: ?Pointi = null, // where the source was copied from

history: *HistoryBuffer,
foreground_color: [4]u8 = [_]u8{ 0, 0, 0, 0xff },
background_color: [4]u8 = [_]u8{ 0xff, 0xff, 0xff, 0xff },
blend_mode: BlendMode = .replace,

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

    self.bitmap = .{ .color = try ColorBitmap.init(allocator, 32, 32) };
    self.bitmap.color.fill(self.background_color);
    self.preview_bitmap = try self.bitmap.clone();
    self.texture = nvg.createImageRgba(self.bitmap.color.width, self.bitmap.color.height, .{ .nearest = true }, self.bitmap.color.pixels);
    try self.history.reset(self);

    return self;
}

pub fn deinit(self: *Self) void {
    self.history.deinit();
    self.bitmap.deinit();
    self.preview_bitmap.deinit();
    nvg.deleteImage(self.texture);
    if (self.texture_palette) |texture_palette| {
        nvg.deleteImage(texture_palette);
        self.texture_palette = null;
    }
    self.freeSelection();
    self.allocator.destroy(self);
}

pub fn createNew(self: *Self, width: u32, height: u32, bitmap_type: BitmapType) !void {
    self.bitmap.deinit();
    self.preview_bitmap.deinit();
    nvg.deleteImage(self.texture);
    if (self.texture_palette) |texture_palette| {
        nvg.deleteImage(texture_palette);
        self.texture_palette = null;
    }
    self.freeSelection();

    switch (bitmap_type) {
        .color => {
            self.bitmap = .{ .color = try ColorBitmap.init(self.allocator, width, height) };
            self.bitmap.color.fill(self.background_color);
            self.texture = nvg.createImageRgba(width, height, .{ .nearest = true }, self.bitmap.color.pixels);
        },
        .indexed => {
            self.bitmap = .{ .indexed = try IndexedBitmap.init(self.allocator, width, height) };
            self.bitmap.indexed.fill(0); // TODO: background index?
            // TODO: textures
        },
    }
    self.preview_bitmap = try self.bitmap.clone();
    self.x = 0;
    self.y = 0;

    try self.history.reset(self);
}

pub fn load(self: *Self, file_path: []const u8) !void {
    var image = try Image.initFromFile(self.allocator, file_path);

    self.bitmap.deinit();
    self.preview_bitmap.deinit();
    nvg.deleteImage(self.texture);
    if (self.texture_palette) |texture_palette| {
        nvg.deleteImage(texture_palette);
        self.texture_palette = null;
    }
    self.freeSelection();

    if (image.colormap) |colormap| {
        self.bitmap = .{ .indexed = IndexedBitmap{
            .allocator = self.allocator,
            .width = image.width,
            .height = image.height,
            .indices = image.pixels,
            .colormap = colormap,
        } };
        self.texture = nvg.createImageAlpha(image.width, image.height, .{ .nearest = true }, image.pixels);
        self.texture_palette = nvg.createImageRgba(256, 1, .{ .nearest = true }, colormap);
    } else {
        self.bitmap = .{ .color = ColorBitmap{
            .allocator = self.allocator,
            .width = image.width,
            .height = image.height,
            .pixels = image.pixels,
        } };
        self.texture = nvg.createImageRgba(image.width, image.height, .{ .nearest = true }, image.pixels);
    }

    self.preview_bitmap = try self.bitmap.clone();
    self.x = 0;
    self.y = 0;

    try self.history.reset(self);
}

pub fn save(self: *Self, file_path: []const u8) !void {
    const image = self.bitmap.toImage(self.allocator);
    try image.writeToFile(file_path);
}

pub fn createSnapshot(self: Document) ![]u8 {
    const allocator = self.allocator;
    var output = ArrayList(u8).init(allocator);

    var comp = try std.compress.deflate.compressor(self.allocator, output.writer(), .{});
    defer comp.deinit();
    var writer = comp.writer();

    try writer.writeIntNative(i32, self.x);
    try writer.writeIntNative(i32, self.y);
    switch (self.bitmap) {
        .color => |color_bitmap| {
            try writer.writeIntNative(u8, @enumToInt(BitmapType.color));
            try writer.writeIntNative(u32, color_bitmap.width);
            try writer.writeIntNative(u32, color_bitmap.height);
            _ = try writer.write(color_bitmap.pixels);
        },
        .indexed => |indexed_bitmap| {
            try writer.writeIntNative(u8, @enumToInt(BitmapType.indexed));
            try writer.writeIntNative(u32, indexed_bitmap.width);
            try writer.writeIntNative(u32, indexed_bitmap.height);
            _ = try writer.write(indexed_bitmap.indices);
            _ = try writer.write(indexed_bitmap.colormap);
        },
    }
    // TODO: serialize selection
    try comp.close();

    return output.items;
}

pub fn restoreFromSnapshot(self: *Document, snapshot: []u8) !void {
    _ = self;
    _ = snapshot;
    @panic("TODO");
    // var input = std.io.fixedBufferStream(snapshot);
    // var decomp = try std.compress.deflate.decompressor(self.allocator, input.reader(), null);
    // defer decomp.deinit();

    // var reader = decomp.reader();
    // const x = try reader.readIntNative(i32);
    // const y = try reader.readIntNative(i32);
    // const width = try reader.readIntNative(u32);
    // const height = try reader.readIntNative(u32);
    // if (self.bitmap.width != width or self.bitmap.height != height) {
    //     self.bitmap.width = width;
    //     self.bitmap.height = height;
    //     self.bitmap.pixels = try self.allocator.realloc(self.bitmap.pixels, 4 * width * height);
    //     self.preview_bitmap.width = width;
    //     self.preview_bitmap.height = height;
    //     self.preview_bitmap.pixels = try self.allocator.realloc(self.preview_bitmap.pixels, 4 * width * height);
    //     _ = try reader.readAll(self.bitmap.pixels);

    //     // recreate texture
    //     nvg.deleteImage(self.texture);
    //     self.texture = nvg.createImageRgba(width, height, .{ .nearest = true }, self.bitmap.pixels);
    // } else {
    //     _ = try reader.readAll(self.bitmap.pixels);
    // }
    // _ = decomp.close();

    // if (self.x != x or self.y != y) {
    //     const dx = x - self.x;
    //     const dy = y - self.y;
    //     self.x = x;
    //     self.y = y;
    //     self.canvas.translateByPixel(dx, dy);
    // }
    // self.last_preview = .full;
    // self.clearPreview();

    // self.freeSelection();
}

pub fn getWidth(self: Self) u32 {
    return switch (self.bitmap) {
        .color => |color_bitmap| color_bitmap.width,
        .indexed => |indexed_bitmap| indexed_bitmap.width,
    };
}

pub fn getHeight(self: Self) u32 {
    return switch (self.bitmap) {
        .color => |color_bitmap| color_bitmap.height,
        .indexed => |indexed_bitmap| indexed_bitmap.height,
    };
}

pub fn getColorDepth(self: Self) u32 {
    return switch (self.bitmap) {
        .color => 32,
        .indexed => 8,
    };
}

pub fn canUndo(self: Self) bool {
    return self.history.canUndo();
}

pub fn undo(self: *Self) !void {
    try self.history.undo(self);
}

pub fn canRedo(self: Self) bool {
    return self.history.canRedo();
}

pub fn redo(self: *Self) !void {
    try self.history.redo(self);
}

pub fn cut(self: *Self) !void {
    try self.copy();

    if (self.selection != null) {
        self.freeSelection();
    } else {
        switch (self.bitmap) {
            .color => |color_bitmap| color_bitmap.fill(self.background_color),
            .indexed => |indexed_bitmap| indexed_bitmap.fill(0), // TODO: background index?
        }
        self.last_preview = .full;
        self.clearPreview();
    }

    try self.history.pushFrame(self);
}

pub fn copy(self: *Self) !void {
    if (self.selection) |*selection| {
        try Clipboard.setImage(self.allocator, selection.bitmap.toImage(self.allocator));
        self.copy_location = Pointi{
            .x = selection.rect.x,
            .y = selection.rect.y,
        };
    } else {
        try Clipboard.setImage(self.allocator, self.bitmap.toImage(self.allocator));
        self.copy_location = null;
    }
}

pub fn paste(self: *Self) !void {
    _ = self;
    @panic("TODO");
    // const image = try Clipboard.getImage(self.allocator);
    // errdefer self.allocator.free(image.pixels);

    // if (self.selection) |_| {
    //     try self.clearSelection();
    // }

    // const x = @intCast(i32, self.bitmap.width / 2) - @intCast(i32, image.width / 2);
    // const y = @intCast(i32, self.bitmap.height / 2) - @intCast(i32, image.height / 2);
    // var selection_rect = Recti.make(x, y, @intCast(i32, image.width), @intCast(i32, image.height));

    // if (self.copy_location) |copy_location| {
    //     selection_rect.x = copy_location.x;
    //     selection_rect.y = copy_location.y;
    // }

    // self.selection = Selection{
    //     .rect = selection_rect,
    //     .bitmap = Bitmap{
    //         .allocator = self.allocator,
    //         .width = image.width,
    //         .height = image.height,
    //         .pixels = image.pixels,
    //     },
    //     .texture = nvg.createImageRgba(
    //         image.width,
    //         image.height,
    //         .{ .nearest = true },
    //         image.pixels,
    //     ),
    // };
}

pub fn crop(self: *Self, rect: Recti) !void {
    _ = self;
    _ = rect;
    @panic("TODO");
    // if (rect.w < 1 or rect.h < 1) return error.InvalidCropRect;
    // const width = @intCast(u32, rect.w);
    // const height = @intCast(u32, rect.h);
    // const new_bitmap = try Bitmap.init(self.allocator, width, height);
    // //errdefer self.allocator.free(new_bitmap); // TODO: bad because tries for undo stuff at the bottom
    // new_bitmap.fill(self.background_color);

    // const intersection = rect.intersection(.{
    //     .x = 0,
    //     .y = 0,
    //     .w = @intCast(i32, self.bitmap.width),
    //     .h = @intCast(i32, self.bitmap.height),
    // });
    // if (intersection.w > 0 and intersection.h > 0) {
    //     const ox = if (rect.x < 0) @intCast(u32, -rect.x) else 0;
    //     const oy = if (rect.y < 0) @intCast(u32, -rect.y) else 0;
    //     const sx = @intCast(u32, intersection.x);
    //     const sy = @intCast(u32, intersection.y);
    //     const w = @intCast(u32, intersection.w);
    //     const h = @intCast(u32, intersection.h);
    //     // blit to source
    //     var y: u32 = 0;
    //     while (y < h) : (y += 1) {
    //         const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
    //         const di = 4 * ((sy + y) * self.bitmap.width + sx);
    //         // copy entire line
    //         std.mem.copy(u8, new_bitmap.pixels[si .. si + 4 * w], self.bitmap.pixels[di .. di + 4 * w]);
    //     }
    // }

    // self.bitmap.deinit();
    // self.bitmap = new_bitmap;
    // self.preview_bitmap.deinit();
    // self.preview_bitmap = try self.bitmap.clone();

    // nvg.deleteImage(self.texture);
    // self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);

    // self.x += rect.x;
    // self.y += rect.y;
    // self.canvas.translateByPixel(rect.x, rect.y);

    // try self.history.pushFrame(self);
}

pub fn clearSelection(self: *Self) !void {
    _ = self;
    @panic("TODO");
    // if (self.selection) |selection| {
    //     const rect = selection.rect;
    //     const bitmap = selection.bitmap;

    //     const intersection = rect.intersection(.{
    //         .x = 0,
    //         .y = 0,
    //         .w = @intCast(i32, self.bitmap.width),
    //         .h = @intCast(i32, self.bitmap.height),
    //     });
    //     if (intersection.w > 0 and intersection.h > 0) {
    //         const ox = if (rect.x < 0) @intCast(u32, -rect.x) else 0;
    //         const oy = if (rect.y < 0) @intCast(u32, -rect.y) else 0;
    //         const sx = @intCast(u32, intersection.x);
    //         const sy = @intCast(u32, intersection.y);
    //         const w = @intCast(u32, intersection.w);
    //         const h = @intCast(u32, intersection.h);
    //         // blit to source
    //         var y: u32 = 0;
    //         while (y < h) : (y += 1) {
    //             const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
    //             const di = 4 * ((sy + y) * self.bitmap.width + sx);
    //             switch (self.blend_mode) {
    //                 .alpha => {
    //                     var x: u32 = 0;
    //                     while (x < w) : (x += 1) {
    //                         const src = bitmap.pixels[si + 4 * x .. si + 4 * x + 4];
    //                         const dst = self.bitmap.pixels[di + 4 * x .. di + 4 * x + 4];
    //                         const out = col.blend(src, dst);
    //                         std.mem.copy(u8, dst, &out);
    //                     }
    //                 },
    //                 .replace => std.mem.copy(u8, self.bitmap.pixels[di .. di + 4 * w], bitmap.pixels[si .. si + 4 * w]),
    //             }
    //         }
    //         self.last_preview = .full; // TODO: just a rect?
    //         self.clearPreview();
    //     }

    //     self.freeSelection();

    //     try self.history.pushFrame(self);
    // }
}

pub fn makeSelection(self: *Self, rect: Recti) !void {
    _ = self;
    _ = rect;
    @panic("TODO");
    // std.debug.assert(rect.w > 0 and rect.h > 0);

    // const intersection = rect.intersection(.{
    //     .x = 0,
    //     .y = 0,
    //     .w = @intCast(i32, self.bitmap.width),
    //     .h = @intCast(i32, self.bitmap.height),
    // });
    // if (intersection.w > 0 and intersection.h > 0) {
    //     const w = @intCast(u32, intersection.w);
    //     const h = @intCast(u32, intersection.h);
    //     const bitmap = try Bitmap.init(self.allocator, w, h);

    //     // move pixels
    //     var y: u32 = 0;
    //     while (y < h) : (y += 1) {
    //         const di = 4 * (y * w);
    //         const sx = @intCast(u32, intersection.x);
    //         const sy = @intCast(u32, intersection.y);
    //         const si = 4 * ((sy + y) * self.bitmap.width + sx);
    //         std.mem.copy(u8, bitmap.pixels[di .. di + 4 * w], self.bitmap.pixels[si .. si + 4 * w]);
    //         const dst_line = self.bitmap.pixels[si .. si + 4 * w];
    //         var i: usize = 0;
    //         while (i < dst_line.len) : (i += 1) {
    //             dst_line[i] = self.background_color[i % 4];
    //         }
    //     }
    //     self.last_preview = .full; // TODO: just a rect?
    //     self.clearPreview();

    //     var selection = Selection{
    //         .rect = intersection,
    //         .bitmap = bitmap,
    //         .texture = nvg.createImageRgba(w, h, .{ .nearest = true }, bitmap.pixels),
    //     };
    //     self.freeSelection(); // clean up previous selection
    //     self.selection = selection;
    // }
}

pub fn deleteSelection(self: *Self) !void {
    self.freeSelection();

    try self.history.pushFrame(self);
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
    var success = false;
    switch (self.preview_bitmap) {
        .color => |preview_color_bitmap| {
            success = switch (self.blend_mode) {
                .alpha => preview_color_bitmap.blendPixel(x, y, self.foreground_color),
                .replace => preview_color_bitmap.setPixel(x, y, self.foreground_color),
            };
        },
        .indexed => |preview_indexed_bitmap| {
            success = preview_indexed_bitmap.setIndex(x, y, 0); // TODO: foreground_index
        },
    }
    if (success) {
        self.last_preview = PrimitivePreview{ .brush = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) } };
    }
}

pub fn previewStroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    self.clearPreview();
    switch (self.preview_bitmap) {
        .color => |preview_color_bitmap| {
            switch (self.blend_mode) {
                .alpha => preview_color_bitmap.blendLine(x0, y0, x1, y1, self.foreground_color, true),
                .replace => preview_color_bitmap.drawLine(x0, y0, x1, y1, self.foreground_color, true),
            }
        },
        .indexed => @panic("TODO"),
    }
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
}

pub fn clearPreview(self: *Self) void {
    switch (self.last_preview) {
        .none => {},
        .brush => |brush| {
            switch (self.bitmap) {
                .color => |color_bitmap| color_bitmap.copyPixelUnchecked(self.preview_bitmap.color, brush.x, brush.y),
                .indexed => |indexed_bitmap| indexed_bitmap.copyIndexUnchecked(self.preview_bitmap.indexed, brush.x, brush.y),
            }
        },
        .line => |line| {
            switch (self.bitmap) {
                .color => |color_bitmap| color_bitmap.copyLine(self.preview_bitmap.color, line.x0, line.y0, line.x1, line.y1),
                .indexed => |indexed_bitmap| indexed_bitmap.copyLine(self.preview_bitmap.indexed, line.x0, line.y0, line.x1, line.y1),
            }
        },
        .full => switch (self.bitmap) {
            .color => |color_bitmap| std.mem.copy(u8, self.preview_bitmap.color.pixels, color_bitmap.pixels),
            .indexed => |indexed_bitmap| std.mem.copy(u8, self.preview_bitmap.indexed.indices, indexed_bitmap.indices),
        },
    }
    self.last_preview = .none;
    self.dirty = true;
}

pub fn fill(self: *Self, color: [4]u8) !void {
    _ = self;
    _ = color;
    @panic("TODO");
    // if (self.selection) |*selection| {
    //     selection.bitmap.fill(color);
    //     nvg.updateImage(selection.texture, selection.bitmap.pixels);
    // } else {
    //     self.bitmap.fill(color);
    //     self.last_preview = .full;
    //     self.clearPreview();
    //     try self.history.pushFrame(self);
    // }
}

pub fn mirrorHorizontally(self: *Self) !void {
    if (self.selection) |*selection| {
        selection.bitmap.mirrorHorizontally();
        @panic("TODO");
        // nvg.updateImage(selection.texture, selection.bitmap.pixels);
    } else {
        self.bitmap.mirrorHorizontally();
        self.last_preview = .full;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn mirrorVertically(self: *Self) !void {
    if (self.selection) |*selection| {
        try selection.bitmap.mirrorVertically();
        @panic("TODO");
        // nvg.updateImage(selection.texture, selection.bitmap.pixels);
    } else {
        try self.bitmap.mirrorVertically();
        self.last_preview = .full;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn rotateCw(self: *Self) !void {
    _ = self;
    @panic("TODO");
    // if (self.selection) |*selection| {
    //     try selection.bitmap.rotateCw();
    //     selection.rect.w = @intCast(i32, selection.bitmap.width);
    //     selection.rect.h = @intCast(i32, selection.bitmap.height);
    //     const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
    //     selection.rect.x -= d;
    //     selection.rect.y += d;
    //     nvg.deleteImage(selection.texture);
    //     selection.texture = nvg.createImageRgba(
    //         selection.bitmap.width,
    //         selection.bitmap.height,
    //         .{ .nearest = true },
    //         selection.bitmap.pixels,
    //     );
    // } else {
    //     try self.bitmap.rotateCw();
    //     if (self.bitmap.width != self.bitmap.height) {
    //         const d = @divTrunc(@intCast(i32, self.bitmap.height) - @intCast(i32, self.bitmap.width), 2);
    //         self.x -= d;
    //         self.y += d;
    //         self.canvas.translateByPixel(d, -d);
    //         nvg.deleteImage(self.texture);
    //         self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);
    //     }
    //     self.last_preview = .full;
    //     self.clearPreview();
    //     try self.history.pushFrame(self);
    // }
}

pub fn rotateCcw(self: *Self) !void {
    _ = self;
    @panic("TODO");
    // if (self.selection) |*selection| {
    //     try selection.bitmap.rotateCcw();
    //     selection.rect.w = @intCast(i32, selection.bitmap.width);
    //     selection.rect.h = @intCast(i32, selection.bitmap.height);
    //     const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
    //     selection.rect.x -= d;
    //     selection.rect.y += d;
    //     nvg.deleteImage(selection.texture);
    //     selection.texture = nvg.createImageRgba(
    //         selection.bitmap.width,
    //         selection.bitmap.height,
    //         .{ .nearest = true },
    //         selection.bitmap.pixels,
    //     );
    // } else {
    //     try self.bitmap.rotateCcw();
    //     if (self.bitmap.width != self.bitmap.height) {
    //         const d = @divTrunc(@intCast(i32, self.bitmap.height) - @intCast(i32, self.bitmap.width), 2);
    //         self.x -= d;
    //         self.y += d;
    //         self.canvas.translateByPixel(d, -d);
    //         nvg.deleteImage(self.texture);
    //         self.texture = nvg.createImageRgba(self.bitmap.width, self.bitmap.height, .{ .nearest = true }, self.bitmap.pixels);
    //     }
    //     self.last_preview = .full;
    //     self.clearPreview();
    //     try self.history.pushFrame(self);
    // }
}

pub fn beginStroke(self: *Self, x: i32, y: i32) void {
    var success = false;
    switch (self.bitmap) {
        .color => |color_bitmap| {
            success = switch (self.blend_mode) {
                .alpha => color_bitmap.blendPixel(x, y, self.foreground_color),
                .replace => color_bitmap.setPixel(x, y, self.foreground_color),
            };
        },
        .indexed => @panic("TODO"),
    }
    if (success) {
        self.last_preview = PrimitivePreview{ .brush = .{ .x = @intCast(u32, x), .y = @intCast(u32, y) } };
        self.clearPreview();
    }
}

pub fn stroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) void {
    switch (self.bitmap) {
        .color => |color_bitmap| {
            switch (self.blend_mode) {
                .alpha => color_bitmap.blendLine(x0, y0, x1, y1, self.foreground_color, true),
                .replace => color_bitmap.drawLine(x0, y0, x1, y1, self.foreground_color, true),
            }
        },
        .indexed => @panic("TODO"),
    }
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
    self.clearPreview();
}

pub fn endStroke(self: *Self) !void {
    try self.history.pushFrame(self);
}

pub fn pickColor(self: *Self, x: i32, y: i32) ?[4]u8 {
    return switch (self.bitmap) {
        .color => |color_bitmap| color_bitmap.getPixel(x, y),
        .indexed => @panic("TODO"),
    };
}

pub fn floodFill(self: *Self, x: i32, y: i32) !void {
    switch (self.bitmap) {
        .color => |*color_bitmap| {
            switch (self.blend_mode) {
                .alpha => {
                    if (color_bitmap.getPixel(x, y)) |dst| {
                        const blended = col.blend(self.foreground_color[0..], dst[0..]);
                        try color_bitmap.floodFill(x, y, blended);
                    }
                },
                .replace => try color_bitmap.floodFill(x, y, self.foreground_color),
            }
        },
        .indexed => @panic("TODO"),
    }
    self.last_preview = .full;
    self.clearPreview();
    try self.history.pushFrame(self);
}

pub fn draw(self: *Self) void {
    if (self.dirty) {
        switch (self.preview_bitmap) {
            .color => |color_preview_bitmap| {
                nvg.updateImage(self.texture, color_preview_bitmap.pixels);
            },
            .indexed => |indexed_preview_bitmap| {
                nvg.updateImage(self.texture, indexed_preview_bitmap.indices);
                nvg.updateImage(self.texture_palette.?, self.bitmap.indexed.colormap);
            },
        }
        self.dirty = false;
    }
    const width = @intToFloat(f32, self.getWidth());
    const height = @intToFloat(f32, self.getHeight());
    nvg.beginPath();
    nvg.rect(0, 0, width, height);
    const pattern = switch (self.bitmap) {
        .color => nvg.imagePattern(0, 0, width, height, 0, self.texture, 1),
        .indexed => nvg.indexedImagePattern(0, 0, width, height, 0, self.texture, self.texture_palette.?, 1),
    };
    nvg.fillPaint(pattern);
    nvg.fill();
}
