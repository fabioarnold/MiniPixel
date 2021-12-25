const std = @import("std");
const Image = @import("Image.zig");

usingnamespace switch (@import("builtin").os.tag) {
    .windows => @import("ClipboardWin32.zig"),
    else => struct {
        pub fn hasImage() bool {
            return false;
        }

        pub fn getImage(allocator: std.mem.Allocator) !?Image {
            _ = allocator;
            return null;
        }

        pub fn setImage(allocator: std.mem.Allocator, image: Image) !void {
            _ = allocator;
            _ = image;
        }
    },
};
