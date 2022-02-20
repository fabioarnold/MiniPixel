const std = @import("std");
const Allocator = std.mem.Allocator;

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Point = @import("../geometry.zig").Point;
const Rect = @import("../geometry.zig").Rect;

const RadioButton = @This();

widget: gui.Widget,
allocator: Allocator,
text: []const u8,

hovered: bool = false,
pressed: bool = false,
checked: bool = false,

onClickFn: ?fn (*RadioButton) void = null,

pub fn init(allocator: Allocator, rect: Rect(f32), text: [:0]const u8) !*RadioButton {
    var self = try allocator.create(RadioButton);
    self.* = RadioButton{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .text = text,
    };
    self.widget.focus_policy.mouse = true;
    self.widget.focus_policy.keyboard = true;

    self.widget.drawFn = draw;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.onKeyUpFn = onKeyUp;
    self.widget.onEnterFn = onEnter;
    self.widget.onLeaveFn = onLeave;

    return self;
}

pub fn deinit(self: *RadioButton) void {
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn click(self: *RadioButton) void {
    if (!self.widget.isEnabled()) return;
    if (self.onClickFn) |clickFn| {
        clickFn(self);
    }
}

pub fn onMouseDown(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    if (!widget.isEnabled()) return;
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    const mouse_position = Point(f32).make(mouse_event.x, mouse_event.y);
    self.hovered = widget.getRect().contains(mouse_position);
    if (mouse_event.button == .left) {
        if (self.hovered) {
            self.pressed = true;
        }
    }
}

fn onMouseUp(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    if (!widget.isEnabled()) return;
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    const mouse_position = Point(f32).make(mouse_event.x, mouse_event.y);
    self.hovered = widget.getRect().contains(mouse_position);
    if (mouse_event.button == .left) {
        self.pressed = false;
        if (self.hovered) {
            self.click();
        }
    }
}

fn onKeyUp(widget: *gui.Widget, key_event: *gui.KeyEvent) void {
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    if (key_event.key == .Space) {
        self.click();
    }
}

fn onEnter(widget: *gui.Widget) void {
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    self.hovered = true;
}

fn onLeave(widget: *gui.Widget) void {
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    self.hovered = false;
}

pub fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(RadioButton, "widget", widget);

    const rect = widget.relative_rect;
    // const enabled = widget.isEnabled(); // TODO
    const focused = widget.isFocused();

    const cx = rect.x + 10;
    const cy = rect.y + 0.5 * rect.h;

    nvg.beginPath();
    nvg.arc(cx, cy, 5.5, -0.25 * std.math.pi, -1.25 * std.math.pi, .ccw);
    nvg.strokeColor(gui.theme_colors.shadow);
    nvg.stroke();
    nvg.beginPath();
    nvg.arc(cx, cy, 5.5, 0.75 * std.math.pi, -0.25 * std.math.pi, .ccw);
    nvg.strokeColor(gui.theme_colors.light);
    nvg.stroke();
    nvg.beginPath();
    nvg.ellipse(cx, cy, 4.5, 4.5);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.strokeColor(gui.theme_colors.border);
    nvg.stroke();
    if (self.checked or self.hovered) {
        nvg.beginPath();
        nvg.ellipse(cx, cy, 2, 2);
        nvg.fillColor(if (self.checked) nvg.rgb(0, 0, 0) else gui.theme_colors.shadow);
        nvg.fill();
    }

    nvg.fontFace("guifont");
    nvg.fontSize(12);
    nvg.textAlign(nvg.TextAlign{ .vertical = .middle });
    nvg.fillColor(nvg.rgb(0, 0, 0));
    _ = nvg.text(rect.x + 20, cy, self.text);
    if (focused) {
        var bounds: [4]f32 = undefined;
        _ = nvg.textBounds(rect.x + 20, cy, self.text, &bounds);
        nvg.beginPath();
        nvg.rect(bounds[0] - 0.5, bounds[1] - 0.5, @round(bounds[2] - bounds[0]) + 1, @round(bounds[3] - bounds[1]) + 1);
        nvg.strokeColor(nvg.rgb(0, 0, 0)); // TODO: dashed lines
        nvg.stroke();
    }
}
