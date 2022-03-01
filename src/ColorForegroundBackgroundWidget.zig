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

onChangedFn: ?fn (*Self, change_type: ChangeType) void = null,

const pad = 5;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
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
        .background_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x66, 0x66, 0x66, 0xFF, 0x99, 0x99, 0x99, 0xFF,
            0x99, 0x99, 0x99, 0xFF, 0x66, 0x66, 0x66, 0xFF,
        }),
    };

    self.widget.onMouseDownFn = onMouseDown;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    nvg.deleteImage(self.background_image);
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

pub fn setRgba(self: *Self, color_layer: ColorLayer, color: []u8) void {
    const i = @enumToInt(color_layer);
    if (!std.mem.eql(u8, &self.colors[i], color)) {
        std.mem.copy(u8, &self.colors[i], color);
        self.notifyChanged(.color);
    }
}

pub fn getActiveRgba(self: Self) [4]u8 {
    return self.getRgba(self.active);
}

pub fn setActiveRgba(self: *Self, color: []u8) void {
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

pub fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    nvg.save();
    defer nvg.restore();
    nvg.translate(rect.x, rect.y);

    gui.drawPanel(0, 0, rect.w, rect.h, 1, false, false);

    gui.drawPanelInset(pad, pad, 56, 56, 1);

    var i: usize = self.colors.len;
    while (i > 0) {
        i -= 1;
        const stroke_width: f32 = if (i == @enumToInt(self.active)) 2 else 1;
        const stroke_color = if (i == @enumToInt(self.active)) nvg.rgb(0, 0, 0) else nvg.rgb(66, 66, 66);
        nvg.beginPath();
        nvg.rect(
            self.rects[i].x + 0.5 * stroke_width,
            self.rects[i].y + 0.5 * stroke_width,
            self.rects[i].w - stroke_width,
            self.rects[i].h - stroke_width,
        );
        nvg.fillPaint(nvg.imagePattern(0, 0, 8, 8, 0, self.background_image, 1));
        nvg.fill();
        nvg.fillColor(nvg.rgba(self.colors[i][0], self.colors[i][1], self.colors[i][2], self.colors[i][3]));
        nvg.fill();

        nvg.strokeWidth(stroke_width);
        nvg.strokeColor(stroke_color);
        nvg.stroke();

        nvg.beginPath();
        nvg.moveTo(self.rects[i].x + stroke_width, self.rects[i].y + stroke_width);
        nvg.lineTo(self.rects[i].x + self.rects[i].w - stroke_width, self.rects[i].y + stroke_width);
        nvg.lineTo(self.rects[i].x + stroke_width, self.rects[i].y + self.rects[i].h - stroke_width);
        nvg.closePath();
        nvg.fillColor(nvg.rgb(self.colors[i][0], self.colors[i][1], self.colors[i][2]));
        nvg.fill();
    }
}
