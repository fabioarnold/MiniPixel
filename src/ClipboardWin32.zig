const std = @import("std");
const c = @cImport({
    @cInclude("Windows.h");
});
const Image = @import("Image.zig");

pub fn hasImage() bool {
    const png_format = c.RegisterClipboardFormatA("PNG");
    if (png_format != 0 and c.IsClipboardFormatAvailable(png_format) != 0) return true;
    if (c.IsClipboardFormatAvailable(c.CF_DIBV5) != 0) return true;
    return false;
}

pub fn getImage(allocator: std.mem.Allocator) !Image {
    const png_format = c.RegisterClipboardFormatA("PNG");
    if (png_format != 0 and c.IsClipboardFormatAvailable(png_format) != 0) {
        if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
        defer _ = c.CloseClipboard();

        if (c.GetClipboardData(png_format)) |png_handle| {
            const size = c.GlobalSize(png_handle);
            if (c.GlobalLock(png_handle)) |local_mem| {
                defer _ = c.GlobalUnlock(png_handle);
                const data = @as([*]const u8, @ptrCast(local_mem));
                return try Image.initFromMemory(allocator, data[0..size]);
            }
        }
    }

    if (c.IsClipboardFormatAvailable(c.CF_DIBV5) != 0) {
        if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
        defer _ = c.CloseClipboard();
        if (c.GetClipboardData(c.CF_DIBV5)) |handle| {
            const size = c.GlobalSize(handle);
            if (c.GlobalLock(handle)) |local_mem| {
                defer _ = c.GlobalUnlock(handle);
                const data = @as([*]const u8, @ptrCast(local_mem));
                return try loadBitmapV5Image(allocator, data[0..size]);
            }
        }
    }

    // if (c.IsClipboardFormatAvailable(c.CF_DIB) != 0) {
    //     const handle = c.GetClipboardData(c.CF_DIB);
    //     if (handle != null) {
    //         const header = @ptrCast(*c.BITMAPINFO, @alignCast(@alignOf(*c.BITMAPINFO), handle));
    //         image.width = @intCast(u32, header.bmiHeader.biWidth);
    //         image.height = @intCast(u32, header.bmiHeader.biWidth);
    //         @panic("TODO");
    //     }
    // }

    return error.UnsupportedFormat;
}

pub fn setImage(allocator: std.mem.Allocator, image: Image) !void {
    const png_format = c.RegisterClipboardFormatA("PNG");
    if (png_format == 0) return error.FormatPngUnsupported;

    if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
    defer _ = c.CloseClipboard();

    if (c.EmptyClipboard() == 0) return error.EmptyClipboardFailed;

    const png_data = try image.writeToMemory(allocator);
    defer allocator.free(png_data);

    // copy to global memory
    const global_handle = c.GlobalAlloc(c.GMEM_MOVEABLE, png_data.len);
    if (global_handle == null) return error.GlobalAllocFail;
    defer _ = c.GlobalFree(global_handle);

    if (c.GlobalLock(global_handle)) |local_mem| {
        defer _ = c.GlobalUnlock(global_handle);
        const data = @as([*]u8, @ptrCast(local_mem));
        @memcpy(data[0..png_data.len], png_data);

        _ = c.SetClipboardData(png_format, global_handle);
    }
}

// https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapv5header
fn loadBitmapV5Image(allocator: std.mem.Allocator, mem: []const u8) !Image {
    const header: *const c.BITMAPV5HEADER = @alignCast(@ptrCast(mem.ptr));
    const src = mem[header.bV5Size .. header.bV5Size + header.bV5SizeImage];

    var image: Image = undefined;
    image.width = @as(u32, @intCast(header.bV5Width));

    // If the value of bV5Height is positive, the bitmap is a bottom-up DIB
    // and its origin is the lower-left corner. If bV5Height value is negative,
    // the bitmap is a top-down DIB and its origin is the upper-left corner.
    var origin_top: bool = false;
    if (header.bV5Height < 0) {
        image.height = @as(u32, @intCast(-header.bV5Height));
        origin_top = true;
    } else {
        image.height = @as(u32, @intCast(header.bV5Height));
    }

    std.debug.assert(header.bV5Planes == 1); // Must be 1

    // TODO: Support other bit depths
    // 0: Defined by JPEG or PNG file format
    // 1: Monochrome
    // 4: 16 color palette
    // 8: 256 color palette
    // 16: 16-bit color depth
    // 24: 8-bit for red, green, blue
    // 32: 8-bit for red, green, blue and unused (alpha?)
    if (header.bV5BitCount != 24 and header.bV5BitCount != 32) return error.BitmapUnsupported;

    // TODO: support more formats
    // BI_RLE8, BI_RLE4, BI_BITFIELDS, BI_JPEG, BI_PNG
    const BI_RGB = 0; // Zig can't translate the c.BI_RGB macro currently
    if (header.bV5Compression != BI_RGB) return error.BitmapUnsupported;

    image.pixels = try allocator.alloc(u8, 4 * image.width * image.height);

    if (header.bV5BitCount == 24) {
        const bytes_per_row = 3 * image.width;
        const pitch = 4 * ((bytes_per_row + 3) / 4);
        var y: u32 = 0;
        while (y < image.height) : (y += 1) {
            const y_flip = if (origin_top) y else image.height - 1 - y;
            var x: u32 = 0;
            while (x < image.width) : (x += 1) {
                const b = src[(y * pitch + 3 * x) + 0];
                const g = src[(y * pitch + 3 * x) + 1];
                const r = src[(y * pitch + 3 * x) + 2];
                image.pixels[4 * (y_flip * image.width + x) + 0] = r;
                image.pixels[4 * (y_flip * image.width + x) + 1] = g;
                image.pixels[4 * (y_flip * image.width + x) + 2] = b;
                image.pixels[4 * (y_flip * image.width + x) + 3] = 0xff;
            }
        }
    } else if (header.bV5BitCount == 32) {
        // red = 0xff
        // green = 0xff00
        const pitch = 4 * image.width;
        var y: u32 = 0;
        while (y < image.height) : (y += 1) {
            const y_flip = if (origin_top) y else image.height - 1 - y;
            var x: u32 = 0;
            while (x < image.width) : (x += 1) {
                const b = src[(y * pitch + 4 * x) + 0];
                const g = src[(y * pitch + 4 * x) + 1];
                const r = src[(y * pitch + 4 * x) + 2];
                const a = src[(y * pitch + 4 * x) + 3];
                image.pixels[4 * (y_flip * image.width + x) + 0] = r;
                image.pixels[4 * (y_flip * image.width + x) + 1] = g;
                image.pixels[4 * (y_flip * image.width + x) + 2] = b;
                image.pixels[4 * (y_flip * image.width + x) + 3] = a;
            }
        }
    }

    return image;
}
