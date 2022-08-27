const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Rect = @import("gui/geometry.zig").Rect;
const Point = @import("gui/geometry.zig").Point;
const BlendMode = @import("color.zig").BlendMode;

const image_alpha_data = @embedFile("../data/blendmodealpha.png");
const image_replace_data = @embedFile("../data/blendmodereplace.png");

widget: gui.Widget,
allocator: Allocator,

active: BlendMode = .replace,

image_alpha: nvg.Image,
image_replace: nvg.Image,
rects: [2]Rect(f32),

onChangedFn: ?std.meta.FnPtr(fn (*Self) void) = null,

const pad = 5;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .rects = [_]Rect(f32){
            Rect(f32).make(pad + 1, 33 - 27, rect.w - 2 * pad - 2, 27),
            Rect(f32).make(pad + 1, 33, rect.w - 2 * pad - 2, 27),
        },
        .image_alpha = vg.createImageMem(image_alpha_data, .{ .nearest = true }),
        .image_replace = vg.createImageMem(image_replace_data, .{ .nearest = true }),
    };

    self.widget.onMouseDownFn = onMouseDown;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    vg.deleteImage(self.image_alpha);
    vg.deleteImage(self.image_replace);
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn setActive(self: *Self, active: BlendMode) void {
    if (self.active != active) {
        self.active = active;
        if (self.onChangedFn) |onChanged| onChanged(self);
    }
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (!widget.enabled) return;
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

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    vg.save();
    defer vg.restore();
    vg.translate(rect.x, rect.y);

    gui.drawPanel(vg, 0, 0, rect.w, rect.h, 1, false, false);
    gui.drawPanelInset(vg, pad, pad, rect.w - 2 * pad, rect.h - 2 * pad, 1);

    const active_rect = self.rects[@enumToInt(self.active)];
    vg.beginPath();
    vg.rect(active_rect.x, active_rect.y, active_rect.w, active_rect.h);
    vg.fillColor(if (widget.enabled) gui.theme_colors.focus else gui.theme_colors.shadow);
    vg.fill();

    const alpha: f32 = if (widget.enabled) 1 else 0.5;
    vg.beginPath();
    vg.rect(32, 33 - 25, 32, 24);
    vg.fillPaint(vg.imagePattern(32, 33 - 25, 32, 24, 0, self.image_alpha, alpha));
    vg.fill();
    vg.beginPath();
    vg.rect(32, 33 + 1, 32, 24);
    vg.fillPaint(vg.imagePattern(32, 33 + 1, 32, 24, 0, self.image_replace, alpha));
    vg.fill();
}
