const std = @import("std");
const Image = @import("Image.zig");

var clipboard_image: ?Image = null;

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
