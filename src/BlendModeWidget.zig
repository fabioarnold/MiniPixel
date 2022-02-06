const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Rect = @import("gui/geometry.zig").Rect;
const Point = @import("gui/geometry.zig").Point;

const image_alpha_data = @embedFile("../data/blendmodealpha.png");
const image_replace_data = @embedFile("../data/blendmodereplace.png");

pub const BlendMode = enum(u1) {
    alpha,
    replace,
};

widget: gui.Widget,
allocator: Allocator,

active: BlendMode = .alpha,

image_alpha: nvg.Image,
image_replace: nvg.Image,
rects: [2]Rect(f32),

onChangedFn: ?fn (*Self) void = null,

const pad = 5;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .rects = [_]Rect(f32){
            Rect(f32).make(pad + 1, 33 - 27, rect.w - 2 * pad - 2, 27),
            Rect(f32).make(pad + 1, 33, rect.w - 2 * pad - 2, 27),
        },
        .image_alpha = nvg.createImageMem(image_alpha_data, .{ .nearest = true }),
        .image_replace = nvg.createImageMem(image_replace_data, .{ .nearest = true }),
    };

    self.widget.onMouseDownFn = onMouseDown;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    nvg.deleteImage(self.image_alpha);
    nvg.deleteImage(self.image_replace);
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn setActive(self: *Self, active: BlendMode) void {
    if (self.active != active) {
        self.active = active;
        if (self.onChangedFn) |onChanged| onChanged(self);
    }
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.button == .left) {
        var self = @fieldParentPtr(Self, "widget", widget);
        const point = Point(f32).make(event.x, event.y);
        for (self.rects) |rect, i| {
            if (rect.contains(point)) {
                self.setActive(@intToEnum(BlendMode, @intCast(u1, i)));
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
    gui.drawPanelInset(pad, pad, rect.w - 2 * pad, rect.h - 2 * pad, 1);

    const active_rect = self.rects[@enumToInt(self.active)];
    nvg.beginPath();
    nvg.rect(active_rect.x, active_rect.y, active_rect.w, active_rect.h);
    nvg.fillColor(gui.theme_colors.focus);
    nvg.fill();

    nvg.beginPath();
    nvg.rect(32, 33 - 25, 32, 24);
    nvg.fillPaint(nvg.imagePattern(32, 33 - 25, 32, 24, 0, self.image_alpha, 1));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(32, 33 + 1, 32, 24);
    nvg.fillPaint(nvg.imagePattern(32, 33 + 1, 32, 24, 0, self.image_replace, 1));
    nvg.fill();
}
