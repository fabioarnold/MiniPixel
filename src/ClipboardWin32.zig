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

pub fn getImage(allocator: *std.mem.Allocator) !?Image {
    const png_format = c.RegisterClipboardFormatA("PNG");
    if (png_format != 0 and c.IsClipboardFormatAvailable(png_format) != 0) {
        if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
        defer _ = c.CloseClipboard();

        if (c.GetClipboardData(png_format)) |png_handle| {
            const size = c.GlobalSize(png_handle);
            if (c.GlobalLock(png_handle)) |local_mem| {
                defer _ = c.GlobalUnlock(png_handle);
                const data = @ptrCast([*]const u8, local_mem);
                return try Image.initFromMemory(allocator, data[0..size]);
            }
        }
    }

    if (c.IsClipboardFormatAvailable(c.CF_DIBV5) != 0) {
        if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
        defer _ = c.CloseClipboard();
        if (c.GetClipboardData(c.CF_DIBV5)) |handle| {
            const ptr = @alignCast(@alignOf(*c.BITMAPV5HEADER), handle);
            const header = @ptrCast(*c.BITMAPV5HEADER, ptr);
            const bit_count = header.bV5BitCount;
            var r_mask: u32 = 0xff_00_00;
            var r_shift: u8 = 16;
            var g_mask: u32 = 0x00_ff_00;
            var g_shift: u8 = 8;
            var b_mask: u32 = 0x00_00_ff;
            var b_shift: u8 = 0;
            var a_mask: u32 = 0xff_00_00_00;
            var a_shift: u8 = 24;
            if (header.bV5Compression == 3) { // BI_BITFIELDS (translate-c fail)
                r_mask = header.bV5RedMask;
                _ = r_shift; // TODO: calc shift
                g_mask = header.bV5GreenMask;
                _ = g_shift; // TODO: calc shift
                b_mask = header.bV5BlueMask;
                _ = b_shift; // TODO: calc shift
                a_mask = header.bV5AlphaMask;
                _ = a_shift; // TODO: calc shift
                @panic("TODO");
            }
            const src = @ptrCast([*]u8, ptr)[header.bV5Size .. header.bV5Size + header.bV5SizeImage];

            var image: Image = undefined;
            image.width = @intCast(u32, header.bV5Width);
            image.height = @intCast(u32, header.bV5Height);
            image.pixels = try allocator.alloc(u8, 4 * image.width * image.height);

            if (bit_count == 24) {
                const bytes_per_row = 3 * image.width;
                const pitch = 4 * ((bytes_per_row + 3) / 4);
                var y: u32 = 0;
                while (y < image.height) : (y += 1) {
                    const y_flip = image.height - 1 - y;
                    var x: u32 = 0;
                    while (x < image.width) : (x += 1) {
                        const r = src[(y * pitch + 3 * x) + 2];
                        const g = src[(y * pitch + 3 * x) + 1];
                        const b = src[(y * pitch + 3 * x) + 0];
                        image.pixels[4 * (y_flip * image.width + x) + 0] = r;
                        image.pixels[4 * (y_flip * image.width + x) + 1] = g;
                        image.pixels[4 * (y_flip * image.width + x) + 2] = b;
                        image.pixels[4 * (y_flip * image.width + x) + 3] = 0xff;
                    }
                }

                return image;
            } else {
                @panic("TODO");
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
    }

    return null;
}

pub fn setImage(allocator: *std.mem.Allocator, image: Image) !void {
    const png_format = c.RegisterClipboardFormatA("PNG");
    if (png_format == 0) return error.FormatPngUnsupported;

    if (c.OpenClipboard(null) == 0) return error.OpenClipboardFailed;
    defer _ = c.CloseClipboard();

    if (c.EmptyClipboard() == 0) return error.EmptyClipboardFailed;

    var png_data = try image.writeToMemory(allocator);
    defer allocator.free(png_data);

    // copy to global memory
    const global_handle = c.GlobalAlloc(c.GMEM_MOVEABLE, png_data.len);
    if (global_handle == null) return error.GlobalAllocFail;
    defer _ = c.GlobalFree(global_handle);

    if (c.GlobalLock(global_handle)) |local_mem| {
        defer _ = c.GlobalUnlock(global_handle);
        const data = @ptrCast([*]u8, local_mem);
        std.mem.copy(u8, data[0..png_data.len], png_data);

        _ = c.SetClipboardData(png_format, global_handle);
    }
}
