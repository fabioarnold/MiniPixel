const snapshot_compression_enabled = true;

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const nvg = @import("nanovg");
const s2s = @import("s2s");
const gui = @import("gui");
const geometry = gui.geometry;
const Point = geometry.Point;
const Pointi = Point(i32);
const Pointu = Point(u32);
const Rect = geometry.Rect;
const Recti = Rect(i32);

const CanvasWidget = @import("CanvasWidget.zig");
const Bitmap = @import("bitmap.zig").Bitmap;
pub const BitmapType = @import("bitmap.zig").BitmapType;
const col = @import("color.zig");
const Color = col.Color;
const ColorLayer = col.ColorLayer;
const BlendMode = col.BlendMode;
const Image = @import("Image.zig");
const Clipboard = @import("Clipboard.zig");
const HistoryBuffer = @import("history.zig").Buffer;
const HistorySnapshot = @import("history.zig").Snapshot;

const Document = @This();

const Cel = struct {
    bitmap: ?Bitmap = null,

    pub fn deinit(self: *Cel, allocator: Allocator) void {
        if (self.bitmap) |bitmap| {
            bitmap.deinit(allocator);
            self.bitmap = null;
        }
    }
};

const Layer = struct {
    cels: ArrayListUnmanaged(Cel) = .{},

    visible: bool = true,
    locked: bool = false,
    linked: bool = false,

    pub fn init(allocator: Allocator, frame_count: u32) !Layer {
        var self = Layer{};
        try self.cels.appendNTimes(allocator, Cel{}, frame_count);
        return self;
    }

    pub fn deinit(self: *Layer, allocator: Allocator) void {
        for (self.cels.items) |*cel| {
            cel.deinit(allocator);
        }
        self.cels.deinit(allocator);
    }
};

pub const Selection = struct {
    rect: Recti,
    bitmap: Bitmap,
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

width: u32 = 16,
height: u32 = 16,
bitmap_type: BitmapType = .color,
layers: ArrayList(Layer),
colormap: []u8,
frame_count: u32 = 1,
frame_time: u32 = 100, // in ms

selected_layer: u32 = 0,
selected_frame: u32 = 0,
onion_skinning: bool = false,
playback_timer: gui.Timer,

texture: nvg.Image, // image for display using nvg
texture_palette: nvg.Image,
preview_bitmap: Bitmap, // preview brush and lines
last_preview: PrimitivePreview = .none,
need_texture_update: bool = false, // bitmap needs to be uploaded to gpu on next draw call
need_texture_recreation: bool = false,

selection: ?Selection = null,
copy_location: ?Pointi = null, // where the source was copied from
selection_texture: nvg.Image,
need_selection_texture_update: bool = false,
need_selection_texture_recreation: bool = false,

history: *HistoryBuffer,

foreground_color: [4]u8 = [_]u8{ 0, 0, 0, 0xff },
background_color: [4]u8 = [_]u8{ 0xff, 0xff, 0xff, 0xff },
foreground_index: u8 = 0,
background_index: u8 = 1,
blend_mode: BlendMode = .replace,

canvas: *CanvasWidget = undefined,

const Self = @This();

pub fn init(allocator: Allocator, vg: nvg) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .allocator = allocator,
        .playback_timer = gui.Timer{
            .on_elapsed_fn = onPlaybackTimerElapsed,
            .ctx = @ptrToInt(self),
        },
        .texture = undefined,
        .texture_palette = undefined,
        .selection_texture = undefined,
        .layers = ArrayList(Layer).init(allocator),
        .colormap = try allocator.alloc(u8, 4 * 256),
        .preview_bitmap = undefined,
        .history = try HistoryBuffer.init(allocator),
    };

    // Create initial layer
    try self.layers.append(try Layer.init(allocator, self.frame_count));
    try self.layers.append(try Layer.init(allocator, self.frame_count));
    try self.layers.append(try Layer.init(allocator, self.frame_count));

    self.preview_bitmap = try Bitmap.init(allocator, self.width, self.height, self.bitmap_type);
    self.preview_bitmap.clear();
    self.texture = self.preview_bitmap.createTexture(vg);
    self.texture_palette = vg.createImageRGBA(256, 1, .{ .nearest = true }, self.colormap);
    self.selection_texture = vg.createImageRGBA(0, 0, .{}, &.{}); // dummy
    try self.history.reset(self);

    return self;
}

fn deinitLayers(self: *Self) void {
    for (self.layers.items) |*layer| {
        layer.deinit(self.allocator);
    }
    self.layers.deinit();
}

pub fn deinit(self: *Self, vg: nvg) void {
    self.history.deinit();
    self.deinitLayers();
    self.preview_bitmap.deinit(self.allocator);
    self.allocator.free(self.colormap);
    vg.deleteImage(self.texture);
    vg.deleteImage(self.texture_palette);
    self.freeSelection();
    self.allocator.destroy(self);
}

pub fn createNew(self: *Self, width: u32, height: u32, bitmap_type: BitmapType) !void {
    self.deinitLayers();
    self.preview_bitmap.deinit(self.allocator);
    self.freeSelection();

    self.width = width;
    self.height = height;
    self.bitmap_type = bitmap_type;
    self.frame_count = 1;
    self.selected_frame = 0;
    self.selected_layer = 0;
    // Create initial layer
    self.layers = ArrayList(Layer).init(self.allocator);
    try self.layers.append(try Layer.init(self.allocator, self.frame_count));

    self.preview_bitmap = try Bitmap.init(self.allocator, self.width, self.height, self.bitmap_type);
    self.preview_bitmap.clear();
    self.need_texture_recreation = true;
    self.x = 0;
    self.y = 0;

    try self.history.reset(self);
}

// FIXME: this only handles files with a single frame and layer
pub fn load(self: *Self, file_path: []const u8) !void {
    const image = try Image.initFromFile(self.allocator, file_path);
    if (image.colormap) |colormap| {
        if (colormap.len != self.colormap.len) return error.UnexpectedColormapLen;
        self.allocator.free(self.colormap);
        self.colormap = colormap;
    }

    const bitmap = Bitmap.initFromImage(image);
    self.width = bitmap.getWidth();
    self.height = bitmap.getHeight();
    self.bitmap_type = bitmap.getType();
    self.frame_count = 1;
    self.selected_frame = 0;
    self.selected_layer = 0;
    self.deinitLayers();
    self.layers = ArrayList(Layer).init(self.allocator);
    const layer = try Layer.init(self.allocator, self.frame_count);
    layer.cels.items[0].bitmap = bitmap;
    try self.layers.append(layer);

    self.preview_bitmap.deinit(self.allocator);
    self.preview_bitmap = try bitmap.clone(self.allocator);
    self.need_texture_recreation = true;
    self.last_preview = .none;
    self.x = 0;
    self.y = 0;

    self.freeSelection();

    try self.history.reset(self);
}

// FIXME: this only handles files with a single frame and layer
pub fn save(self: *Self, file_path: []const u8) !void {
    const bitmap = try self.getOrCreateCurrentCelBitmap();
    var image = bitmap.toImage(self.allocator);
    if (self.getBitmapType() == .indexed) {
        image.colormap = col.trimBlackColorsRight(self.colormap);
    }
    try image.writeToFile(file_path);
}

const Snapshot = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    bitmap_type: BitmapType,
    frame_count: u32,
    frame_time: u32,
    selected_frame: u32,
    selected_layer: u32,
    layers: []Layer,
    colormap: []u8,
    selection: ?struct {
        rect: Recti,
        bitmap: Bitmap,
    },
};

pub fn serialize(self: Document) ![]u8 {
    var snapshot = Snapshot{
        .x = self.x,
        .y = self.y,
        .width = self.width,
        .height = self.height,
        .bitmap_type = self.bitmap_type,
        .frame_count = self.frame_count,
        .frame_time = self.frame_time,
        .selected_frame = self.selected_frame,
        .selected_layer = self.selected_layer,
        .layers = self.layers.items,
        .colormap = self.colormap,
        .selection = if (self.selection) |selection| .{
            .rect = selection.rect,
            .bitmap = selection.bitmap,
        } else null,
    };

    var output = ArrayList(u8).init(self.allocator);

    if (snapshot_compression_enabled) {
        var comp = try std.compress.deflate.compressor(self.allocator, output.writer(), .{ .level = .best_speed });
        defer comp.deinit();
        try s2s.serialize(comp.writer(), Snapshot, snapshot);
        try comp.close();
    } else {
        try s2s.serialize(output.writer(), Snapshot, snapshot);
    }

    return output.items;
}

pub fn deserialize(self: *Document, data: []u8) !void {
    var snapshot: Snapshot = undefined;
    var input = std.io.fixedBufferStream(data);

    if (snapshot_compression_enabled) {
        var decomp = try std.compress.deflate.decompressor(self.allocator, input.reader(), null);
        defer decomp.deinit();
        snapshot = try s2s.deserializeAlloc(decomp.reader(), Snapshot, self.allocator);
        _ = decomp.close();
    } else {
        snapshot = try s2s.deserializeAlloc(input.reader(), Snapshot, self.allocator);
    }

    self.width = self.width;
    self.height = self.height;
    self.frame_count = snapshot.frame_count;
    self.frame_time = snapshot.frame_time;
    self.bitmap_type = snapshot.bitmap_type;
    self.selected_frame = snapshot.selected_frame;
    self.selected_layer = snapshot.selected_layer;
    self.deinitLayers();
    // HACK: snapshot contains the wrong capacity
    for (snapshot.layers) |*layer| {
        layer.cels.capacity = layer.cels.items.len;
    }
    self.layers = ArrayList(Layer).fromOwnedSlice(self.allocator, snapshot.layers);
    self.allocator.free(self.colormap);
    self.colormap = snapshot.colormap;
    self.freeSelection();
    if (snapshot.selection) |selection| {
        self.selection = Selection{
            .rect = selection.rect,
            .bitmap = selection.bitmap,
        };
        self.need_selection_texture_recreation = true;
    }

    self.preview_bitmap.deinit(self.allocator);
    self.preview_bitmap = try Bitmap.init(self.allocator, self.width, self.height, self.bitmap_type);
    self.preview_bitmap.clear();
    self.need_texture_recreation = true;

    if (self.x != snapshot.x or self.y != snapshot.y) {
        const dx = snapshot.x - self.x;
        const dy = snapshot.y - self.y;
        self.x += dx;
        self.y += dy;
        self.canvas.translateByPixel(dx, dy);
    }
    self.last_preview = .full;
    self.clearPreview();
}

fn getCurrentCelBitmap(self: Self) ?Bitmap {
    return self.layers.items[self.selected_layer].cels.items[self.selected_frame].bitmap;
}

fn getOrCreateCurrentCelBitmap(self: Self) !Bitmap {
    const cel = &self.layers.items[self.selected_layer].cels.items[self.selected_frame];
    if (cel.bitmap) |bitmap| {
        return bitmap;
    }
    const bitmap = try Bitmap.init(self.allocator, self.width, self.height, self.bitmap_type);
    bitmap.clear();
    cel.bitmap = bitmap;
    return bitmap;
}

pub fn convertToTruecolor(self: *Self) !void {
    if (false) {
    for (self.bitmaps.items) |*bitmap| {
        switch (bitmap.*) {
            .color => return, // Nothing to do
            .indexed => |indexed_bitmap| {
                const color_bitmap = try indexed_bitmap.convertToTruecolor(self.allocator, self.colormap);
                bitmap.deinit(self.allocator);
                bitmap.* = .{ .color = color_bitmap };
            },
        }
    }

    if (self.selection) |*selection| {
        const selection_bitmap = try selection.bitmap.indexed.convertToTruecolor(self.allocator, self.colormap);
        selection.bitmap.deinit(self.allocator);
        selection.bitmap = .{ .color = selection_bitmap };
        self.need_selection_texture_recreation = true;
    }
    self.preview_bitmap.deinit(self.allocator);
    self.preview_bitmap = try self.getSelectedFrameBitmap().clone(self.allocator);
    self.need_texture_recreation = true;

    try self.history.pushFrame(self);
    }
    @panic("TODO");
}

pub fn canLosslesslyConvertToIndexed(self: Self) !bool {
    if (self.getBitmapType() == .color) {
        return true;
    }
    if (false) {
    switch (self.getSelectedFrameBitmap()) {
        .indexed => return true,
        .color => |color_bitmap| {
            if (self.selection) |selection| {
                if (!try selection.bitmap.color.canLosslesslyConvertToIndexed(self.allocator, self.colormap)) {
                    return false;
                }
            }
            return try color_bitmap.canLosslesslyConvertToIndexed(self.allocator, self.colormap);
        },
    }
    }
    @panic("TODO");
}

pub fn convertToIndexed(self: *Self) !void {
    if (false) {
    for (self.bitmaps.items) |*bitmap| {
        switch (bitmap.*) {
            .color => |color_bitmap| {
                const indexed_bitmap = try color_bitmap.convertToIndexed(self.allocator, self.colormap);
                bitmap.deinit(self.allocator);
                bitmap.* = .{ .indexed = indexed_bitmap };
            },
            .indexed => return, // Nothing to do
        }
    }

    if (self.selection) |*selection| {
        const selection_bitmap = try selection.bitmap.color.convertToIndexed(self.allocator, self.colormap);
        selection.bitmap.deinit(self.allocator);
        selection.bitmap = .{ .indexed = selection_bitmap };
        self.need_selection_texture_recreation = true;
    }
    self.preview_bitmap.deinit(self.allocator);
    self.preview_bitmap = try self.getSelectedFrameBitmap().clone(self.allocator);
    self.need_texture_recreation = true;

    try self.history.pushFrame(self);
    }
    @panic("TODO");
}

pub const PaletteUpdateMode = enum {
    replace,
    map,
};

pub fn applyPalette(self: *Self, palette: []u8, mode: PaletteUpdateMode) !void {
    if (mode == .map and self.getBitmapType() == .indexed) {
        var map: [256]u8 = undefined; // colormap -> palette
        for (map) |*m, i| {
            m.* = @truncate(u8, col.findNearest(palette, self.colormap[4 * i ..]));
        }
        if (false) {
        for (self.bitmaps.items) |bitmap| {
            switch (bitmap) {
                .indexed => |indexed_bitmap| {
                    for (indexed_bitmap.indices) |*c| {
                        c.* = map[c.*];
                    }
                },
                .color => {},
            }
        }
        self.last_preview = .full;
        self.clearPreview();
        }
        @panic("TODO");
    }

    std.mem.copy(u8, self.colormap, palette);
    self.need_texture_update = true;

    try self.history.pushFrame(self);
}

pub fn getWidth(self: Self) u32 {
    return self.width;
}

pub fn getHeight(self: Self) u32 {
    return self.height;
}

pub fn getBitmapType(self: Self) BitmapType {
    return self.bitmap_type;
}

pub fn getColorDepth(self: Self) u32 {
    return switch (self.getBitmapType()) {
        .color => 32,
        .indexed => 8,
    };
}

pub fn getLayerCount(self: Self) u32 {
    return @intCast(u32, self.layers.items.len);
}

pub fn getFrameCount(self: Self) u32 {
    return self.frame_count;
}

fn onPlaybackTimerElapsed(context: usize) void {
    var self = @intToPtr(*Self, context);
    if (self.selected_frame == self.frame_count - 1) {
        self.gotoFirstFrame();
    } else {
        self.gotoNextFrame();
    }
}

pub fn play(self: *Self) void {
    self.playback_timer.start(self.frame_time);
}

pub fn pause(self: *Self) void {
    self.playback_timer.stop();
}

pub fn gotoFrame(self: *Self, frame: u32) void {
    if (frame < self.frame_count and frame != self.selected_frame) {
        self.selected_frame = frame;
        self.last_preview = .full;
        self.clearPreview();
    }
}

pub fn selectLayer(self: *Self, layer: u32) void {
    if (layer < self.getLayerCount() and layer != self.selected_layer) {
        self.selected_layer = layer;
        self.last_preview = .full;
        self.clearPreview();
    }
}

pub fn setLayerVisible(self: *Self, layer: u32, visible: bool) void {
    self.layers.items[layer].visible = visible;
    self.last_preview = .full;
    self.clearPreview();
}

pub fn isLayerVisible(self: Self, layer: u32) bool {
    return self.layers.items[layer].visible;
}

pub fn setLayerLocked(self: *Self, layer: u32, locked: bool) void {
    self.layers.items[layer].locked = locked;
}

pub fn isLayerLocked(self: Self, layer: u32) bool {
    return self.layers.items[layer].locked;
}

pub fn setLayerLinked(self: *Self, layer: u32, linked: bool) void {
    self.layers.items[layer].linked = linked;
}

pub fn isLayerLinked(self: Self, layer: u32) bool {
    return self.layers.items[layer].linked;
}

pub fn gotoNextFrame(self: *Self) void {
    if (self.selected_frame < self.frame_count - 1) {
        self.gotoFrame(self.selected_frame + 1);
    }
}

pub fn gotoPrevFrame(self: *Self) void {
    if (self.selected_frame > 0) {
        self.gotoFrame(self.selected_frame - 1);
    }
}

pub fn gotoFirstFrame(self: *Self) void {
    self.gotoFrame(0);
}

pub fn gotoLastFrame(self: *Self) void {
    self.gotoFrame(self.frame_count - 1);
}

pub fn addFrame(self: *Self) !void {
    for (self.layers.items) |*layer| {
        try layer.cels.append(self.allocator, Cel{});
    }
    self.frame_count += 1;
    try self.history.pushFrame(self);
}

pub fn deleteFrame(self: *Self, frame_index: usize) !void {
    if (self.frame_count == 1) return;
    if (frame_index >= self.frame_count) return;
    for (self.layers.items) |*layer| {
        var cel = layer.cels.orderedRemove(frame_index);
        cel.deinit(self.allocator);
    }
    self.frame_count -= 1;
    if (self.selected_frame == self.frame_count) self.selected_frame -= 1;
    self.last_preview = .full;
    self.clearPreview();
    try self.history.pushFrame(self);
}

pub fn addLayer(self: *Self) !void {
    const layer = try Layer.init(self.allocator, self.frame_count);
    try self.layers.append(layer);
    try self.history.pushFrame(self);
}

pub fn deleteLayer(self: *Self, layer_index: usize) !void {
    if (self.getLayerCount() == 1) return;
    if (layer_index >= self.getLayerCount()) return;
    var layer = self.layers.orderedRemove(layer_index);
    layer.deinit(self.allocator);
    if (self.selected_layer == self.getLayerCount()) self.selected_layer -= 1;
    self.last_preview = .full;
    self.clearPreview();
    try self.history.pushFrame(self);
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
        if (self.getCurrentCelBitmap()) |bitmap| {
            switch (bitmap) {
                .color => |color_bitmap| color_bitmap.fill(self.background_color),
                .indexed => |indexed_bitmap| indexed_bitmap.fill(self.background_index),
            }
            self.last_preview = .full;
            self.clearPreview();
        }
    }

    try self.history.pushFrame(self);
}

pub fn copy(self: *Self) !void {
    if (self.selection) |*selection| {
        var image = selection.bitmap.toImage(self.allocator);
        if (self.getBitmapType() == .indexed) {
            image.colormap = col.trimBlackColorsRight(self.colormap);
        }
        try Clipboard.setImage(self.allocator, image);
        self.copy_location = Pointi{
            .x = selection.rect.x,
            .y = selection.rect.y,
        };
    } else {
        if (self.getCurrentCelBitmap()) |bitmap| {
            var image = bitmap.toImage(self.allocator);
            if (self.getBitmapType() == .indexed) {
                image.colormap = col.trimBlackColorsRight(self.colormap);
            }
            try Clipboard.setImage(self.allocator, image);
            self.copy_location = null;
        }
    }
}

pub fn paste(self: *Self) !void {
    const image = try Clipboard.getImage(self.allocator);
    errdefer self.allocator.free(image.pixels);
    defer {
        if (image.colormap) |colormap| {
            self.allocator.free(colormap);
        }
    }

    if (self.selection) |_| {
        try self.clearSelection();
    }

    var selection_rect = Recti.make(0, 0, @intCast(i32, image.width), @intCast(i32, image.height));
    if (self.copy_location) |copy_location| {
        selection_rect.x = copy_location.x;
        selection_rect.y = copy_location.y;
    } else {
        selection_rect.x = @intCast(i32, self.getWidth() / 2) - @intCast(i32, image.width / 2);
        selection_rect.y = @intCast(i32, self.getHeight() / 2) - @intCast(i32, image.height / 2);
    }

    var bitmap = Bitmap.initFromImage(image);
    if (bitmap.getType() != self.getBitmapType()) {
        const converted_bitmap: Bitmap = switch (bitmap) {
            .color => |color_bitmap| .{ .indexed = try color_bitmap.convertToIndexed(self.allocator, self.colormap) },
            .indexed => |indexed_bitmap| .{ .color = try indexed_bitmap.convertToTruecolor(self.allocator, image.colormap.?) },
        };
        bitmap.deinit(self.allocator);
        bitmap = converted_bitmap;
    }

    self.selection = Selection{
        .rect = selection_rect,
        .bitmap = bitmap,
    };
    self.need_selection_texture_recreation = true;

    try self.history.pushFrame(self);
}

pub fn crop(self: *Self, rect: Recti) !void {
    if (false) {
    if (rect.w <= 0 or rect.h <= 0) return error.InvalidCropRect;

    const width = @intCast(u32, rect.w);
    const height = @intCast(u32, rect.h);
    const new_bitmap = try Bitmap.init(self.getBitmapType(), self.allocator, width, height);
    //errdefer self.allocator.free(new_bitmap); // TODO: bad because tries for undo stuff at the bottom
    switch (new_bitmap) {
        .color => |color_bitmap| color_bitmap.fill(self.background_color),
        .indexed => |indexed_bitmap| indexed_bitmap.fill(self.background_index),
    }

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.getWidth()),
        .h = @intCast(i32, self.getHeight()),
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
        switch (self.bitmap) {
            .color => |color_bitmap| {
                while (y < h) : (y += 1) {
                    const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
                    const di = 4 * ((sy + y) * color_bitmap.width + sx);
                    // copy entire line
                    std.mem.copy(u8, new_bitmap.color.pixels[si .. si + 4 * w], color_bitmap.pixels[di .. di + 4 * w]);
                }
            },
            .indexed => |indexed_bitmap| {
                while (y < h) : (y += 1) {
                    const si = (y + oy) * @intCast(u32, rect.w) + ox;
                    const di = (sy + y) * indexed_bitmap.width + sx;
                    // copy entire line
                    std.mem.copy(u8, new_bitmap.indexed.indices[si .. si + w], indexed_bitmap.indices[di .. di + w]);
                }
            },
        }
    }

    self.bitmap.deinit(self.allocator);
    self.bitmap = new_bitmap;
    self.preview_bitmap.deinit(self.allocator);
    self.preview_bitmap = try self.bitmap.clone(self.allocator);

    self.need_texture_recreation = true;

    self.x += rect.x;
    self.y += rect.y;
    self.canvas.translateByPixel(rect.x, rect.y);

    try self.history.pushFrame(self);
    }
    @panic("TODO");
}

pub fn clearSelection(self: *Self) !void {
    const selection = self.selection orelse return;
    const rect = selection.rect;
    const bitmap = selection.bitmap;

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.getWidth()),
        .h = @intCast(i32, self.getHeight()),
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
        switch (try self.getOrCreateCurrentCelBitmap()) {
            .color => |color_bitmap| {
                while (y < h) : (y += 1) {
                    const si = 4 * ((y + oy) * @intCast(u32, rect.w) + ox);
                    const di = 4 * ((sy + y) * color_bitmap.width + sx);
                    switch (self.blend_mode) {
                        .alpha => {
                            var x: u32 = 0;
                            while (x < w) : (x += 1) {
                                const src = bitmap.color.pixels[si + 4 * x .. si + 4 * x + 4];
                                const dst = color_bitmap.pixels[di + 4 * x .. di + 4 * x + 4];
                                const out = col.blend(src, dst);
                                std.mem.copy(u8, dst, &out);
                            }
                        },
                        .replace => std.mem.copy(u8, color_bitmap.pixels[di .. di + 4 * w], bitmap.color.pixels[si .. si + 4 * w]),
                    }
                }
            },
            .indexed => |indexed_bitmap| {
                while (y < h) : (y += 1) {
                    const si = (y + oy) * @intCast(u32, rect.w) + ox;
                    const di = (sy + y) * indexed_bitmap.width + sx;
                    std.mem.copy(u8, indexed_bitmap.indices[di .. di + w], bitmap.indexed.indices[si .. si + w]);
                }
            },
        }
        self.last_preview = .full; // TODO: just a rect?
        self.clearPreview();
    }

    self.freeSelection();

    try self.history.pushFrame(self);
}

pub fn makeSelection(self: *Self, rect: Recti) !void {
    std.debug.assert(rect.w > 0 and rect.h > 0);

    const intersection = rect.intersection(.{
        .x = 0,
        .y = 0,
        .w = @intCast(i32, self.getWidth()),
        .h = @intCast(i32, self.getHeight()),
    });
    if (intersection.w <= 0 or intersection.h <= 0) return;

    const sx = @intCast(u32, intersection.x);
    const sy = @intCast(u32, intersection.y);
    const w = @intCast(u32, intersection.w);
    const h = @intCast(u32, intersection.h);
    const bitmap = try Bitmap.init(self.allocator, w, h, self.getBitmapType());

    // move pixels
    var y: u32 = 0;
    switch (try self.getOrCreateCurrentCelBitmap()) {
        .color => |color_bitmap| {
            while (y < h) : (y += 1) {
                const di = 4 * (y * w);
                const si = 4 * ((sy + y) * color_bitmap.width + sx);
                std.mem.copy(u8, bitmap.color.pixels[di .. di + 4 * w], color_bitmap.pixels[si .. si + 4 * w]);
                const dst_line = color_bitmap.pixels[si .. si + 4 * w];
                var i: usize = 0;
                while (i < dst_line.len) : (i += 1) {
                    dst_line[i] = self.background_color[i % 4];
                }
            }
        },
        .indexed => |indexed_bitmap| {
            while (y < h) : (y += 1) {
                const di = y * w;
                const si = (sy + y) * indexed_bitmap.width + sx;
                std.mem.copy(u8, bitmap.indexed.indices[di .. di + w], indexed_bitmap.indices[si .. si + w]);
                const dst_line = indexed_bitmap.indices[si .. si + w];
                std.mem.set(u8, dst_line, self.background_index);
            }
        },
    }

    var selection = Selection{
        .rect = intersection,
        .bitmap = bitmap,
    };
    self.freeSelection(); // clean up previous selection
    self.selection = selection;
    self.need_selection_texture_recreation = true;

    self.last_preview = .full; // TODO: just a rect?
    self.clearPreview();

    try self.history.pushFrame(self);
}

pub fn movedSelection(self: *Self) !void {
    try self.history.pushFrame(self);
}

pub fn deleteSelection(self: *Self) !void {
    self.freeSelection();

    try self.history.pushFrame(self);
}

pub fn freeSelection(self: *Self) void {
    if (self.selection) |selection| {
        selection.bitmap.deinit(self.allocator);
        self.selection = null;
    }
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
            success = preview_indexed_bitmap.setIndex(x, y, self.foreground_index);
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
        .indexed => |preview_indexed_bitmap| {
            preview_indexed_bitmap.drawLine(x0, y0, x1, y1, self.foreground_index, true);
        },
    }
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
}

pub fn clearPreview(self: *Self) void {
    switch (self.last_preview) {
        .none => return,
        .brush => |brush| {
            if (self.getCurrentCelBitmap()) |bitmap| {
                switch (bitmap) {
                    .color => |color_bitmap| color_bitmap.copyPixelUnchecked(self.preview_bitmap.color, brush.x, brush.y),
                    .indexed => |indexed_bitmap| indexed_bitmap.copyIndexUnchecked(self.preview_bitmap.indexed, brush.x, brush.y),
                }
            } else {
                self.preview_bitmap.clearPixelUnchecked(brush.x, brush.y);
            }
        },
        .line => |line| {
            if (self.getCurrentCelBitmap()) |bitmap| {
                switch (bitmap) {
                    .color => |color_bitmap| color_bitmap.copyLine(self.preview_bitmap.color, line.x0, line.y0, line.x1, line.y1),
                    .indexed => |indexed_bitmap| indexed_bitmap.copyLine(self.preview_bitmap.indexed, line.x0, line.y0, line.x1, line.y1),
                }
            } else {
                self.preview_bitmap.clearLine(line.x0, line.y0, line.x1, line.y1);
            }
        },
        .full => {
            if (self.getCurrentCelBitmap()) |bitmap| {
                switch (bitmap) {
                    .color => |color_bitmap| std.mem.copy(u8, self.preview_bitmap.color.pixels, color_bitmap.pixels),
                    .indexed => |indexed_bitmap| std.mem.copy(u8, self.preview_bitmap.indexed.indices, indexed_bitmap.indices),
                }
            } else {
                self.preview_bitmap.clear();
            }
        },
    }
    self.last_preview = .none;
    self.need_texture_update = true;
}

pub fn fill(self: *Self, color_layer: ColorLayer) !void {
    const color = if (color_layer == .foreground) self.foreground_color else self.background_color;
    const index = if (color_layer == .foreground) self.foreground_index else self.background_index;
    if (self.selection) |selection| {
        switch (selection.bitmap) {
            .color => |color_bitmap| color_bitmap.fill(color),
            .indexed => |indexed_bitmap| indexed_bitmap.fill(index),
        }
        self.need_selection_texture_update = true;
    } else {
        const bitmap = try self.getOrCreateCurrentCelBitmap();
        switch (bitmap) {
            .color => |color_bitmap| color_bitmap.fill(color),
            .indexed => |indexed_bitmap| indexed_bitmap.fill(index),
        }
        self.last_preview = .full;
        self.clearPreview();
        try self.history.pushFrame(self);
    }
}

pub fn mirrorHorizontally(self: *Self) !void {
    if (self.selection) |*selection| {
        selection.bitmap.mirrorHorizontally();
        self.need_selection_texture_update = true;
    } else {
        if (self.getCurrentCelBitmap()) |bitmap| {
            bitmap.mirrorHorizontally();
            self.last_preview = .full;
            self.clearPreview();
            try self.history.pushFrame(self);
        }
    }
}

pub fn mirrorVertically(self: *Self) !void {
    if (self.selection) |*selection| {
        selection.bitmap.mirrorVertically();
        self.need_selection_texture_update = true;
    } else {
        if (self.getCurrentCelBitmap()) |bitmap| {
            bitmap.mirrorVertically();
            self.last_preview = .full;
            self.clearPreview();
            try self.history.pushFrame(self);
        }
    }
}

pub fn rotate(self: *Self, clockwise: bool) !void {
    if (self.selection) |*selection| {
        try selection.bitmap.rotate(self.allocator, clockwise);
        std.mem.swap(i32, &selection.rect.w, &selection.rect.h);
        const d = @divTrunc(selection.rect.w - selection.rect.h, 2);
        if (d != 0) {
            selection.rect.x -= d;
            selection.rect.y += d;
            self.need_selection_texture_recreation = true;
        } else {
            self.need_selection_texture_update = true;
        }
    } else {
        if (false) {
        try self.bitmaps.items[0].rotate(self.allocator, clockwise);
        const d = @divTrunc(@intCast(i32, self.getHeight()) - @intCast(i32, self.getWidth()), 2);
        if (d != 0) {
            self.x -= d;
            self.y += d;
            self.canvas.translateByPixel(d, -d);
            self.need_texture_recreation = true;
        }
        self.last_preview = .full;
        self.clearPreview();
        try self.history.pushFrame(self);
        }
        @panic("TODO");
    }
}

pub fn beginStroke(self: *Self, x: i32, y: i32) !void {
    if (x < 0 or y < 0) return;
    const ux = @intCast(u32, x);
    const uy = @intCast(u32, y);
    if (ux >= self.width or uy >= self.height) return;

    const bitmap = try self.getOrCreateCurrentCelBitmap();
    switch (bitmap) {
        .color => |color_bitmap| {
            switch (self.blend_mode) {
                .alpha => color_bitmap.blendPixelUnchecked(ux, uy, self.foreground_color),
                .replace => color_bitmap.setPixelUnchecked(ux, uy, self.foreground_color),
            }
        },
        .indexed => |indexed_bitmap| {
            indexed_bitmap.setIndexUnchecked(ux, uy, self.foreground_index);
        },
    }
    self.last_preview = PrimitivePreview{ .brush = .{ .x = ux, .y = uy } };
    self.clearPreview();
}

pub fn stroke(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32) !void {
    const bitmap = try self.getOrCreateCurrentCelBitmap();
    switch (bitmap) {
        .color => |color_bitmap| {
            switch (self.blend_mode) {
                .alpha => color_bitmap.blendLine(x0, y0, x1, y1, self.foreground_color, true),
                .replace => color_bitmap.drawLine(x0, y0, x1, y1, self.foreground_color, true),
            }
        },
        .indexed => |indexed_bitmap| {
            indexed_bitmap.drawLine(x0, y0, x1, y1, self.foreground_index, true);
        },
    }
    self.last_preview = PrimitivePreview{ .line = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 } };
    self.clearPreview();
}

pub fn endStroke(self: *Self) !void {
    try self.history.pushFrame(self);
}

pub fn pick(self: *Self, x: i32, y: i32) void {
    if (self.getCurrentCelBitmap()) |bitmap| {
        switch (bitmap) {
            .color => |color_bitmap| {
                if (color_bitmap.getPixel(x, y)) |color| {
                    self.foreground_color = color;
                }
            },
            .indexed => |indexed_bitmap| {
                if (indexed_bitmap.getIndex(x, y)) |index| {
                    self.foreground_index = index;
                    const color = self.colormap[4 * @as(usize, self.foreground_index) ..][0..4];
                    std.mem.copy(u8, &self.foreground_color, color);
                }
            },
        }
    }
    // TODO: set colors to transparent when there's no cell?
}

pub fn getColorAt(self: *Self, x: i32, y: i32) ?[4]u8 {
    if (self.getCurrentCelBitmap()) |bitmap| {
        switch (bitmap) {
            .color => |color_bitmap| return color_bitmap.getPixel(x, y),
            .indexed => |indexed_bitmap| {
                if (indexed_bitmap.getIndex(x, y)) |index| {
                    const c = self.colormap[4 * @as(usize, index) ..];
                    return [4]u8{ c[0], c[1], c[2], c[3] };
                }
            },
        }
    }
    return null;
}

pub fn floodFill(self: *Self, x: i32, y: i32) !void {
    // TODO: we could optimize this by just filling the cel if it was empty
    const bitmap = try self.getOrCreateCurrentCelBitmap();
    switch (bitmap) {
        .color => |*color_bitmap| {
            switch (self.blend_mode) {
                .alpha => {
                    if (color_bitmap.getPixel(x, y)) |dst| {
                        const blended = col.blend(self.foreground_color[0..], dst[0..]);
                        try color_bitmap.floodFill(self.allocator, x, y, blended);
                    }
                },
                .replace => try color_bitmap.floodFill(self.allocator, x, y, self.foreground_color),
            }
        },
        .indexed => |*indexed_bitmap| try indexed_bitmap.floodFill(self.allocator, x, y, self.foreground_index),
    }
    self.last_preview = .full;
    self.clearPreview();
    try self.history.pushFrame(self);
}

pub fn draw(self: *Self, vg: nvg) void {
    if (self.need_texture_recreation) {
        vg.deleteImage(self.texture);
        self.texture = self.preview_bitmap.createTexture(vg);
        self.need_texture_recreation = false;
        vg.updateImage(self.texture_palette, self.colormap);
        self.need_texture_update = false;
    } else if (self.need_texture_update) {
        switch (self.preview_bitmap) {
            .color => |color_preview_bitmap| {
                vg.updateImage(self.texture, color_preview_bitmap.pixels);
            },
            .indexed => |indexed_preview_bitmap| {
                vg.updateImage(self.texture, indexed_preview_bitmap.indices);
                vg.updateImage(self.texture_palette, self.colormap);
            },
        }
        self.need_texture_update = false;
    }
    const width = @intToFloat(f32, self.getWidth());
    const height = @intToFloat(f32, self.getHeight());
    vg.beginPath();
    vg.rect(0, 0, width, height);
    const pattern = switch (self.getBitmapType()) {
        .color => vg.imagePattern(0, 0, width, height, 0, self.texture, 1),
        .indexed => vg.indexedImagePattern(0, 0, width, height, 0, self.texture, self.texture_palette, 1),
    };
    vg.fillPaint(pattern);
    vg.fill();
}

pub fn drawSelection(self: *Self, vg: nvg) void {
    if (self.selection) |*selection| {
        if (self.need_selection_texture_recreation) {
            vg.deleteImage(self.selection_texture);
            self.selection_texture = selection.bitmap.createTexture(vg);
            self.need_selection_texture_recreation = false;
            self.need_selection_texture_update = false;
        } else if (self.need_selection_texture_update) {
            switch (selection.bitmap) {
                .color => |color_bitmap| vg.updateImage(self.selection_texture, color_bitmap.pixels),
                .indexed => |indexed_bitmap| vg.updateImage(self.selection_texture, indexed_bitmap.indices),
            }
            self.need_selection_texture_update = false;
        }
        const rect = Rect(f32).make(
            @intToFloat(f32, selection.rect.x),
            @intToFloat(f32, selection.rect.y),
            @intToFloat(f32, selection.rect.w),
            @intToFloat(f32, selection.rect.h),
        );
        vg.beginPath();
        vg.rect(rect.x, rect.y, rect.w, rect.h);
        const pattern = switch (self.getBitmapType()) {
            .color => vg.imagePattern(rect.x, rect.y, rect.w, rect.h, 0, self.selection_texture, 1),
            .indexed => vg.indexedImagePattern(rect.x, rect.y, rect.w, rect.h, 0, self.selection_texture, self.texture_palette, 1),
        };
        vg.fillPaint(pattern);
        vg.fill();
    }
}
