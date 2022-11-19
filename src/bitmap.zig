const std = @import("std");
const Allocator = std.mem.Allocator;

const nvg = @import("nanovg");

const ColorBitmap = @import("ColorBitmap.zig");
const IndexedBitmap = @import("IndexedBitmap.zig");
const Image = @import("Image.zig");

pub const BitmapType = enum(u8) {
    color,
    indexed,
};

pub const Bitmap = union(BitmapType) {
    color: ColorBitmap,
    indexed: IndexedBitmap,

    pub fn init(bitmap_type: BitmapType, allocator: Allocator, width: u32, height: u32) !Bitmap {
        return switch (bitmap_type) {
            .color => .{ .color = try ColorBitmap.init(allocator, width, height) },
            .indexed => .{ .indexed = try IndexedBitmap.init(allocator, width, height) },
        };
    }

    pub fn initFromImage(image: Image) Bitmap {
        return if (image.colormap != null) .{ .indexed = IndexedBitmap{
            .width = image.width,
            .height = image.height,
            .indices = image.pixels,
        } } else .{ .color = ColorBitmap{
            .width = image.width,
            .height = image.height,
            .pixels = image.pixels,
        } };
    }

    pub fn deinit(self: Bitmap, allocator: Allocator) void {
        switch (self) {
            .color => |color_bitmap| color_bitmap.deinit(allocator),
            .indexed => |indexed_bitmap| indexed_bitmap.deinit(allocator),
        }
    }

    pub fn clone(self: Bitmap, allocator: Allocator) !Bitmap {
        return switch (self) {
            .color => |color_bitmap| Bitmap{ .color = try color_bitmap.clone(allocator) },
            .indexed => |indexed_bitmap| Bitmap{ .indexed = try indexed_bitmap.clone(allocator) },
        };
    }

    pub fn getWidth(self: Bitmap) u32 {
        return switch (self) {
            .color => |color_bitmap| color_bitmap.width,
            .indexed => |indexed_bitmap| indexed_bitmap.width,
        };
    }

    pub fn getHeight(self: Bitmap) u32 {
        return switch (self) {
            .color => |color_bitmap| color_bitmap.height,
            .indexed => |indexed_bitmap| indexed_bitmap.height,
        };
    }

    pub fn createTexture(self: Bitmap, vg: nvg) nvg.Image {
        return switch (self) {
            .color => |color_bitmap| nvg.createImageRGBA(
                vg,
                color_bitmap.width,
                color_bitmap.height,
                .{ .nearest = true },
                color_bitmap.pixels,
            ),
            .indexed => |indexed_bitmap| nvg.createImageAlpha(
                vg,
                indexed_bitmap.width,
                indexed_bitmap.height,
                .{ .nearest = true },
                indexed_bitmap.indices,
            ),
        };
    }

    pub fn toImage(self: Bitmap, allocator: Allocator) Image {
        return switch (self) {
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
            },
        };
    }

    pub fn mirrorHorizontally(self: Bitmap) void {
        switch (self) {
            .color => |color_bitmap| color_bitmap.mirrorHorizontally(),
            .indexed => |indexed_bitmap| indexed_bitmap.mirrorHorizontally(),
        }
    }

    pub fn mirrorVertically(self: Bitmap) void {
        switch (self) {
            .color => |color_bitmap| color_bitmap.mirrorVertically(),
            .indexed => |indexed_bitmap| indexed_bitmap.mirrorVertically(),
        }
    }

    pub fn rotate(self: *Bitmap, allocator: Allocator, clockwise: bool) !void {
        try switch (self.*) {
            .color => |*color_bitmap| color_bitmap.rotate(allocator, clockwise),
            .indexed => |*indexed_bitmap| indexed_bitmap.rotate(allocator, clockwise),
        };
    }
};