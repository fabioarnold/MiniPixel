const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Rect = @import("gui/geometry.zig").Rect;
const Point = @import("gui/geometry.zig").Point;
const ColorLayer = @import("color.zig").ColorLayer;

pub const ChangeType = enum {
    color,
    active,
    swap,
};

const ColorForegroundBackgroundWidget = @This();

widget: gui.Widget,
allocator: Allocator,

active: ColorLayer = .foreground,
colors: [2][4]u8 = [_][4]u8{
    [_]u8{ 0, 0, 0, 0xff }, // foregorund
    [_]u8{0xff} ** 4, // background
},
rects: [2]Rect(f32),

background_image: nvg.Image,

onChangedFn: ?std.meta.FnPtr(fn (*Self, change_type: ChangeType) void) = null,

const pad = 5;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    const rect_size = 32;
    const rect_offset = 14;

    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .rects = [_]Rect(f32){
            Rect(f32).make(2 * pad, 2 * pad, rect_size, rect_size),
            Rect(f32).make(2 * pad + rect_offset, 2 * pad + rect_offset, rect_size, rect_size),
        },
        .background_image = vg.createImageRGBA(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x66, 0x66, 0x66, 0xFF, 0x99, 0x99, 0x99, 0xFF,
            0x99, 0x99, 0x99, 0xFF, 0x66, 0x66, 0x66, 0xFF,
        }),
    };

    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    vg.deleteImage(self.background_image);
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn notifyChanged(self: *Self, change_type: ChangeType) void {
    if (self.onChangedFn) |onChanged| onChanged(self, change_type);
}

fn setActive(self: *Self, active: ColorLayer) void {
    if (self.active != active) {
        self.active = active;
        self.notifyChanged(.active);
    }
}

pub fn swap(self: *Self) void {
    std.mem.swap([4]u8, &self.colors[0], &self.colors[1]);
    self.notifyChanged(.swap);
}

pub fn getRgba(self: Self, color_layer: ColorLayer) [4]u8 {
    return self.colors[@enumToInt(color_layer)];
}

pub fn setRgba(self: *Self, color_layer: ColorLayer, color: []const u8) void {
    const i = @enumToInt(color_layer);
    if (!std.mem.eql(u8, &self.colors[i], color)) {
        std.mem.copy(u8, &self.colors[i], color);
        self.notifyChanged(.color);
    }
}

pub fn getActiveRgba(self: Self) [4]u8 {
    return self.getRgba(self.active);
}

pub fn setActiveRgba(self: *Self, color: []const u8) void {
    self.setRgba(self.active, color);
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.button == .left) {
        var self = @fieldParentPtr(Self, "widget", widget);
        const point = Point(f32).make(event.x, event.y);
        for (self.rects) |rect, i| {
            if (rect.contains(point)) {
                self.setActive(@intToEnum(ColorLayer, @intCast(u1, i)));
                break;
            }
        }
    }
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.button == .left) {
        var self = @fieldParentPtr(Self, "widget", widget);
        const point = Point(f32).make(event.x, event.y);
        const swap_rect = Rect(f32).make(10,42,14,14);
        if (swap_rect.contains(point)) {
            self.swap();
        }
    }
}

fn drawSwapArrows(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(15, 43);
    vg.lineTo(12, 47);
    vg.lineTo(14, 47);
    vg.lineTo(14, 52);
    vg.lineTo(19, 52);
    vg.lineTo(19, 54);
    vg.lineTo(23, 51);
    vg.lineTo(19, 48);
    vg.lineTo(19, 50);
    vg.lineTo(16, 50);
    vg.lineTo(16, 47);
    vg.lineTo(18, 47);
    vg.closePath();
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    vg.save();
    defer vg.restore();
    vg.translate(rect.x, rect.y);

    gui.drawPanel(vg, 0, 0, rect.w, rect.h, 1, false, false);

    gui.drawPanelInset(vg, pad, pad, 56, 56, 1);

    drawSwapArrows(vg);

    var i: usize = self.colors.len;
    while (i > 0) {
        i -= 1;
        const stroke_width: f32 = if (i == @enumToInt(self.active)) 2 else 1;
        const stroke_color = if (i == @enumToInt(self.active)) nvg.rgb(0, 0, 0) else nvg.rgb(66, 66, 66);
        vg.beginPath();
        vg.rect(
            self.rects[i].x + 0.5 * stroke_width,
            self.rects[i].y + 0.5 * stroke_width,
            self.rects[i].w - stroke_width,
            self.rects[i].h - stroke_width,
        );
        vg.fillPaint(vg.imagePattern(0, 0, 8, 8, 0, self.background_image, 1));
        vg.fill();
        vg.fillColor(nvg.rgba(self.colors[i][0], self.colors[i][1], self.colors[i][2], self.colors[i][3]));
        vg.fill();

        vg.strokeWidth(stroke_width);
        vg.strokeColor(stroke_color);
        vg.stroke();

        vg.beginPath();
        vg.moveTo(self.rects[i].x + stroke_width, self.rects[i].y + stroke_width);
        vg.lineTo(self.rects[i].x + self.rects[i].w - stroke_width, self.rects[i].y + stroke_width);
        vg.lineTo(self.rects[i].x + stroke_width, self.rects[i].y + self.rects[i].h - stroke_width);
        vg.closePath();
        vg.fillColor(nvg.rgb(self.colors[i][0], self.colors[i][1], self.colors[i][2]));
        vg.fill();
    }
}
