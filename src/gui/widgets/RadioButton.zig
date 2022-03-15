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
focused: bool = false,
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
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onFocusFn = onFocus;
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

fn onKeyDown(widget: *gui.Widget, key_event: *gui.KeyEvent) void {
    widget.onKeyDown(key_event);
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    if (key_event.key == .Space) {
        self.click();
    }
}

fn onFocus(widget: *gui.Widget, focus_event : *gui.FocusEvent) void {
    const self = @fieldParentPtr(RadioButton, "widget", widget);
    self.focused = focus_event.source == .keyboard;
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
    if (!widget.isFocused()) self.focused = false;

    const cx = rect.x + 6;
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
    _ = nvg.text(rect.x + 16, cy, self.text);
    if (self.focused) {
        var bounds: [4]f32 = undefined;
        _ = nvg.textBounds(rect.x + 16, cy, self.text, &bounds);
        nvg.beginPath();
        nvg.rect(@round(bounds[0]) - 1.5, @round(bounds[1]) - 1.5, @round(bounds[2] - bounds[0]) + 3, @round(bounds[3] - bounds[1]) + 3);
        nvg.strokePaint(nvg.imagePattern(0, 0, 2, 2, 0, gui.grid_image, 1));
        nvg.stroke();
    }
}
