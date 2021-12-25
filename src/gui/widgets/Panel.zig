const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

const Panel = @This();

widget: gui.Widget,
allocator: Allocator,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
    };
    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn draw(widget: *gui.Widget) void {
    const rect = widget.relative_rect;
    gui.drawPanel(rect.x, rect.y, rect.w, rect.h, 1, false, false);

    widget.drawChildren();
}
