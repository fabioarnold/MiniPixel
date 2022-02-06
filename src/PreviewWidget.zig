const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Document = @import("Document.zig");
const Rect = @import("gui/geometry.zig").Rect;
const Point = @import("gui/geometry.zig").Point;

const PreviewWidget = @This();

widget: gui.Widget,
allocator: Allocator,

document: *Document,
translation: Point(f32) = Point(f32).make(0, 0),
drag_offset: ?Point(f32) = null,

background_image: nvg.Image,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .background_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x66, 0x66, 0x66, 0xFF, 0x99, 0x99, 0x99, 0xFF,
            0x99, 0x99, 0x99, 0xFF, 0x66, 0x66, 0x66, 0xFF,
        }),
    };

    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    nvg.deleteImage(self.background_image);
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    if (self.drag_offset) |drag_offset| {
        self.translation = Point(f32).make(event.x, event.y).subtracted(drag_offset);
    }
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.drag_offset = Point(f32).make(event.x, event.y).subtracted(self.translation);
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    _ = event; // unused
    var self = @fieldParentPtr(Self, "widget", widget);
    self.drag_offset = null;
}

pub fn draw(widget: *gui.Widget) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    nvg.save();
    defer nvg.restore();
    nvg.translate(rect.x, rect.y);

    gui.drawPanel(0, 0, rect.w, rect.h, 1, false, false);
    nvg.beginPath();
    nvg.rect(5.5, 5.5, rect.w - 11, rect.h - 11);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();

    const client_w = rect.w - 12;
    const client_h = rect.h - 12;
    nvg.scissor(6, 6, client_w, client_h);
    nvg.translate(6, 6);
    nvg.beginPath();
    nvg.rect(0, 0, client_w, client_h);
    nvg.fillPaint(nvg.imagePattern(0, 0, 8, 8, 0, self.background_image, 1));
    nvg.fill();

    const d_x = client_w - @intToFloat(f32, self.document.bitmap.width);
    const d_y = client_h - @intToFloat(f32, self.document.bitmap.height);
    self.translation.x = std.math.clamp(self.translation.x, std.math.min(0, d_x), std.math.max(0, d_x));
    self.translation.y = std.math.clamp(self.translation.y, std.math.min(0, d_y), std.math.max(0, d_y));
    nvg.translate(self.translation.x, self.translation.y);
    self.document.draw();

    if (self.document.selection) |selection| {
        self.drawSelection(selection);
    }
}

fn drawSelection(self: Self, selection: Document.Selection) void {
    const fx = @intToFloat(f32, selection.rect.x);
    const fy = @intToFloat(f32, selection.rect.y);
    const fw = @intToFloat(f32, selection.rect.w);
    const fh = @intToFloat(f32, selection.rect.h);
    {
        nvg.save();
        defer nvg.restore();
        nvg.scissor(0, 0, @intToFloat(f32, self.document.bitmap.width), @intToFloat(f32, self.document.bitmap.height));
        nvg.beginPath();
        nvg.rect(fx, fy, fw, fh);
        nvg.fillPaint(nvg.imagePattern(fx, fy, fw, fh, 0, selection.texture, 1));
        nvg.fill();
    }
}
