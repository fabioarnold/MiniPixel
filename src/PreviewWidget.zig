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

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document, vg: nvg) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .background_image = vg.createImageRGBA(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x66, 0x66, 0x66, 0xFF, 0x99, 0x99, 0x99, 0xFF,
            0x99, 0x99, 0x99, 0xFF, 0x66, 0x66, 0x66, 0xFF,
        }),
    };

    self.widget.onMouseMoveFn = &onMouseMove;
    self.widget.onMouseDownFn = &onMouseDown;
    self.widget.onMouseUpFn = &onMouseUp;

    self.widget.drawFn = &draw;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    vg.deleteImage(self.background_image);
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

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    vg.save();
    defer vg.restore();
    vg.translate(rect.x, rect.y);

    gui.drawPanel(vg, 0, 0, rect.w, rect.h, 1, false, false);
    vg.beginPath();
    vg.rect(5.5, 5.5, rect.w - 11, rect.h - 11);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();

    const client_w = rect.w - 12;
    const client_h = rect.h - 12;
    vg.scissor(6, 6, client_w, client_h);
    vg.translate(6, 6);
    const client_rect = Rect(f32).make(0, 0, client_w, client_h);
    self.drawBackground(client_rect, vg);

    const d_x = client_w - @intToFloat(f32, self.document.getWidth());
    const d_y = client_h - @intToFloat(f32, self.document.getHeight());
    self.translation.x = std.math.clamp(self.translation.x, std.math.min(0, d_x), std.math.max(0, d_x));
    self.translation.y = std.math.clamp(self.translation.y, std.math.min(0, d_y), std.math.max(0, d_y));
    vg.translate(self.translation.x, self.translation.y);
    self.document.draw(vg);

    if (self.document.selection) |selection| {
        self.drawSelection(selection, client_rect.translated(self.translation.scaled(-1)), vg);
    }
}

fn drawBackground(self: Self, rect: Rect(f32), vg: nvg) void {
    vg.beginPath();
    vg.rect(rect.x, rect.y, rect.w, rect.h);
    vg.fillPaint(vg.imagePattern(0, 0, 8, 8, 0, self.background_image, 1));
    vg.fill();
}

fn drawSelection(self: Self, selection: Document.Selection, rect: Rect(f32), vg: nvg) void {
    const document_rect = Rect(f32).make(0, 0, @intToFloat(f32, self.document.getWidth()), @intToFloat(f32, self.document.getHeight()));
    const selection_rect = Rect(f32).make(
        @intToFloat(f32, selection.rect.x),
        @intToFloat(f32, selection.rect.y),
        @intToFloat(f32, selection.rect.w),
        @intToFloat(f32, selection.rect.h),
    );
    const intersection = rect.intersection(document_rect.intersection(selection_rect));
    vg.scissor(intersection.x, intersection.y, intersection.w, intersection.h);
    if (self.document.blend_mode == .replace) {
        self.drawBackground(selection_rect, vg);
    }
    self.document.drawSelection(vg);
}
