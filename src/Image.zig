const std = @import("std");
const Allocator = std.mem.Allocator;

const col = @import("color.zig");

const Image = @This();

const colormap_len = 0x100;

width: u32,
height: u32,
pixels: []u8,
colormap: ?[]u8 = null,
allocator: Allocator,

pub fn initEmptyRgba(allocator: Allocator, width: u32, height: u32) !Image {
    const self = Image{
        .width = width,
        .height = height,
        .pixels = try allocator.alloc(u8, 4 * width * height),
        .allocator = allocator,
    };
    std.mem.set(u8, self.pixels, 0);
    return self;
}

pub fn initFromFile(allocator: Allocator, file_path: []const u8) !Image {
    var image_width: u32 = undefined;
    var image_height: u32 = undefined;
    var colormap_entries: u32 = undefined;
    const c_file_path = try std.cstr.addNullByte(allocator, file_path);
    defer allocator.free(c_file_path);
    var err = readPngFileInfo(c_file_path.ptr, &image_width, &image_height, &colormap_entries);
    if (err != 0) return error.ReadInfoFail;

    const bytes_per_pixel: u32 = if (colormap_entries > 0) 1 else 4; // indexed or rgba
    const image_size = bytes_per_pixel * image_width * image_height;

    var self: Image = Image{
        .width = image_width,
        .height = image_height,
        .pixels = try allocator.alloc(u8, image_size),
        .allocator = allocator,
    };
    errdefer self.deinit();
    if (colormap_entries > 0) {
        const colormap = try allocator.alloc(u8, 4 * colormap_len);
        // init remaining entries to black
        var i: usize = colormap_entries;
        while (i < colormap_len) : (i += 1) {
            std.mem.copy(u8, colormap[4 * i ..][0..4], &col.black);
        }
        self.colormap = colormap;
    }

    err = readPngFile(c_file_path.ptr, self.pixels.ptr, if (self.colormap) |colormap| colormap.ptr else null);
    if (err != 0) return error.ReadPngFail;

    return self;
}

pub fn initFromMemory(allocator: Allocator, memory: []const u8) !Image {
    var image_width: u32 = undefined;
    var image_height: u32 = undefined;
    var colormap_entries: u32 = undefined;
    var err = readPngMemoryInfo(memory.ptr, memory.len, &image_width, &image_height, &colormap_entries);
    if (err != 0) return error.ReadInfoFail;

    const bytes_per_pixel: u32 = if (colormap_entries > 0) 1 else 4; // indexed or rgba
    const image_size = bytes_per_pixel * image_width * image_height;

    var self: Image = Image{
        .width = image_width,
        .height = image_height,
        .pixels = try allocator.alloc(u8, image_size),
        .allocator = allocator,
    };
    errdefer self.deinit();
    if (colormap_entries > 0) {
        const colormap = try allocator.alloc(u8, 4 * colormap_len);
        // init remaining entries to black
        var i: usize = colormap_entries;
        while (i < colormap_len) : (i += 1) {
            std.mem.copy(u8, colormap[4 * i ..][0..4], &col.black);
        }
        self.colormap = colormap;
    }

    err = readPngMemory(memory.ptr, memory.len, self.pixels.ptr, if (self.colormap) |colormap| colormap.ptr else null);
    if (err != 0) return error.ReadPngFail;

    return self;
}

pub fn deinit(self: Image) void {
    self.allocator.free(self.pixels);
    if (self.colormap) |colormap| self.allocator.free(colormap);
}

pub fn clone(self: Image, allocator: std.mem.Allocator) !Image {
    if (self.colormap != null) @panic("Not implementated");
    return Image{
        .allocator = allocator,
        .width = self.width,
        .height = self.height,
        .pixels = try allocator.dupe(u8, self.pixels),
    };
}

pub fn writeToFile(self: Image, file_path: []const u8) !void {
    var colormap_entries: u32 = 0;
    var colormap_ptr: [*c]const u8 = null;
    if (self.colormap) |colormap| {
        colormap_ptr = colormap.ptr;
        colormap_entries = @truncate(u32, colormap.len / 4);
    }
    const c_file_path = try std.cstr.addNullByte(self.allocator, file_path);
    defer self.allocator.free(c_file_path);
    const err = writePngFile(c_file_path.ptr, self.width, self.height, self.pixels.ptr, colormap_ptr, colormap_entries);
    if (err != 0) return error.WritePngFail;
}

pub fn writeToMemory(self: Image, allocator: Allocator) ![]const u8 {
    var colormap_entries: u32 = 0;
    var colormap_ptr: [*c]const u8 = null;
    if (self.colormap) |colormap| {
        colormap_ptr = colormap.ptr;
        colormap_entries = @truncate(u32, colormap.len / 4);
    }
    var mem_len: usize = undefined;
    var err = writePngMemory(null, &mem_len, self.width, self.height, self.pixels.ptr, colormap_ptr, colormap_entries);
    if (err != 0) return error.WritePngDetermineSizeFail;
    const mem = try allocator.alloc(u8, mem_len);
    errdefer allocator.free(mem);
    err = writePngMemory(mem.ptr, &mem_len, self.width, self.height, self.pixels.ptr, colormap_ptr, colormap_entries);
    if (err != 0) return error.WritePngFail;
    return mem;
}

fn convertIndexedToRgba(allocator: Allocator, indexed_image: Image) !Image {
    const image = try initEmptyRgba(allocator, indexed_image.width, indexed_image.height);
    const colormap = indexed_image.colormap.?;
    const pixel_count = indexed_image.width * indexed_image.height;
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        const index = @intCast(usize, indexed_image.pixels[i]);
        std.mem.copy(u8, image.pixels[4 * i ..][0..4], colormap[4 * index ..][0..4]);
    }
    return image;
}

// implementation in c/png_image.c
extern fn readPngFileInfo(file_path: [*c]const u8, width: [*c]u32, height: [*c]u32, colormap_entries: [*c]u32) callconv(.C) c_int;
extern fn readPngFile(file_path: [*c]const u8, pixels: [*c]const u8, colormap: [*c]const u8) callconv(.C) c_int;
extern fn readPngMemoryInfo(memory: [*c]const u8, len: usize, width: [*c]u32, height: [*c]u32, colormap_entries: [*c]u32) callconv(.C) c_int;
extern fn readPngMemory(memory: [*c]const u8, len: usize, pixels: [*c]const u8, colormap: [*c]const u8) callconv(.C) c_int;
extern fn writePngFile(file_path: [*c]const u8, width: u32, height: u32, pixels: [*c]const u8, colormap: [*c]const u8, colormap_entries: u32) callconv(.C) c_int;
extern fn writePngMemory(memory: [*c]const u8, len: [*c]usize, width: u32, height: u32, pixels: [*c]const u8, colormap: [*c]const u8, colormap_entries: u32) callconv(.C) c_int;
