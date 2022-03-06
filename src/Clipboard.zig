const std = @import("std");
const Application = @import("gui").Application;
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

fn isColorString(string: []const u8) bool {
    if (string.len != 9) return false;
    if (string[0] != '#') return false;
    for (string[1..]) |c| {
        switch (c) {
            '0'...'9', 'A'...'F' => {},
            else => return false,
        }
    }
    return true;
}

pub fn hasColor(allocator: std.mem.Allocator) bool {
    if (!Application.hasClipboardText()) return false;
    const string = (Application.getClipboardText(allocator) catch return false).?;
    defer allocator.free(string);
    return isColorString(string);
}

pub fn getColor(allocator: std.mem.Allocator) ![4]u8 {
    const string = (try Application.getClipboardText(allocator)).?;
    defer allocator.free(string);
    if (!isColorString(string)) return error.InvalidColorFormat;
    return [_]u8{
        try std.fmt.parseInt(u8, string[1..3], 16),
        try std.fmt.parseInt(u8, string[3..5], 16),
        try std.fmt.parseInt(u8, string[5..7], 16),
        try std.fmt.parseInt(u8, string[7..9], 16),
    };
}

pub fn setColor(allocator: std.mem.Allocator, color: [4]u8) !void {
    var string: [9]u8 = undefined;
    _ = try std.fmt.bufPrint(&string, "#{X:0>2}{X:0>2}{X:0>2}{X:0>2}", .{ color[0], color[1], color[2], color[3] });
    try Application.setClipboardText(allocator, &string);
}
