const std = @import("std");
const Image = @import("Image.zig");

var clipboard_image: ?Image = null;
var clipboard_color: ?[4]u8 = null;

pub fn deinit() void {
    if (clipboard_image) |image| {
        image.deinit();
    }
}

usingnamespace switch (@import("builtin").os.tag) {
    .windows => @import("ClipboardWin32.zig"),
    else => struct {
        pub fn hasImage() bool {
            return clipboard_image != null;
        }

        pub fn getImage(allocator: std.mem.Allocator) !Image {
            if (clipboard_image) |image| {
                return try image.clone(allocator);
            } else {
                return error.EmptyClipboard;
            }
        }

        pub fn setImage(allocator: std.mem.Allocator, image: Image) !void {
            deinit();
            clipboard_image = try image.clone(allocator);
        }
    },
};

pub fn hasColor() bool {
    return clipboard_color != null;
}

pub fn getColor() ![4]u8 {
    return clipboard_color orelse error.EmptyClipboard;
}

pub fn setColor(color: [4]u8) !void {
    clipboard_color = color;
}
