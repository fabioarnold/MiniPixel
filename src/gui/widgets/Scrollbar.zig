const std = @import("std");
const Allocator = std.mem.Allocator;

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

const Scrollbar = @This();

widget: gui.Widget,
allocator: Allocator,

orientation: gui.Orientation,
mouse_offset: f32 = 0,

value: f32 = 0,
min_value: f32 = 0,
max_value: f32 = 0,

decrement_button: *gui.Button,
increment_button: *gui.Button,
thumb_button: *gui.Button,

onChangedFn: ?*const fn (*Self) void = null,

pub const button_size = 16;
const scroll_speed = 5;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), orientation: gui.Orientation) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .orientation = orientation,
        .increment_button = try gui.Button.init(allocator, Rect(f32).make(0, 0, button_size, button_size), ""),
        .decrement_button = try gui.Button.init(allocator, Rect(f32).make(0, 0, button_size, button_size), ""),
        .thumb_button = try gui.Button.init(allocator, Rect(f32).make(0, 0, button_size, button_size), ""),
    };
    self.widget.onResizeFn = onResize;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.drawFn = draw;

    self.thumb_button.widget.onMouseDownFn = thumbMouseDown;
    self.thumb_button.widget.onMouseMoveFn = thumbMouseMove;
    self.thumb_button.widget.focus_policy = gui.FocusPolicy.none();

    self.decrement_button.onClickFn = decrementClick;
    self.decrement_button.widget.focus_policy = gui.FocusPolicy.none();
    self.decrement_button.auto_repeat_interval = 10;
    self.decrement_button.iconFn = if (self.orientation == .vertical)
        gui.drawSmallArrowUp
    else
        gui.drawSmallArrowLeft;
    self.decrement_button.icon_x = 5;
    self.decrement_button.icon_y = 5;
    self.increment_button.onClickFn = incrementClick;
    self.increment_button.widget.focus_policy = gui.FocusPolicy.none();
    self.increment_button.auto_repeat_interval = 10;
    self.increment_button.iconFn = if (self.orientation == .vertical)
        gui.drawSmallArrowDown
    else
        gui.drawSmallArrowRight;
    self.increment_button.icon_x = 5;
    self.increment_button.icon_y = 5;

    try self.widget.addChild(&self.decrement_button.widget);
    try self.widget.addChild(&self.increment_button.widget);
    try self.widget.addChild(&self.thumb_button.widget);

    self.updateLayout();

    return self;
}

pub fn deinit(self: *Self) void {
    self.decrement_button.deinit();
    self.increment_button.deinit();
    self.thumb_button.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn setValue(self: *Self, value: f32) void {
    const clamped_value = std.math.clamp(value, self.min_value, self.max_value);
    if (clamped_value != self.value) {
        self.value = clamped_value;
        self.updateThumbPosition();
        if (self.onChangedFn) |onChanged| onChanged(self);
    }
}

pub fn setMaxValue(self: *Self, max_value: f32) void {
    self.max_value = std.math.max(0, max_value);
    self.setValue(self.value); // clamps
    self.updateThumbSize();
    self.updateThumbPosition();
}

fn decrementClick(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    self.setValue(self.value - scroll_speed);
}

fn incrementClick(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    self.setValue(self.value + scroll_speed);
}

fn updateThumbPosition(self: *Self) void {
    const rect = self.widget.getRect();
    const thumb_rect = self.thumb_button.widget.getRect();
    const range = (if (self.orientation == .vertical)
        rect.h - thumb_rect.h
    else
        rect.w - thumb_rect.w) - 2 * button_size + 2;
    const pos = button_size - 1 + self.value * range / self.max_value;
    if (self.orientation == .vertical) {
        self.thumb_button.widget.relative_rect.y = pos;
    } else {
        self.thumb_button.widget.relative_rect.x = pos;
    }
}

fn updateThumbSize(self: *Self) void {
    const view = if (self.orientation == .vertical)
        self.widget.relative_rect.h
    else
        self.widget.relative_rect.w;
    const content = view + self.max_value;
    const track = view - 2 * button_size + 2;
    if (track < button_size) {
        self.thumb_button.widget.visible = false;
        return;
    } else {
        self.thumb_button.widget.visible = true;
    }
    const thumb = track * view / content;
    if (self.orientation == .vertical) {
        self.thumb_button.widget.setSize(button_size, thumb);
    } else {
        self.thumb_button.widget.setSize(thumb, button_size);
    }
}

fn thumbMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    gui.Button.onMouseDown(widget, event);
    const self = @fieldParentPtr(Self, "widget", widget.parent.?);
    self.mouse_offset = if (self.orientation == .vertical) event.y else event.x;
}

fn thumbMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.isButtonPressed(.left)) {
        const self = @fieldParentPtr(Self, "widget", widget.parent.?);
        if (self.orientation == .vertical) {
            const y = widget.relative_rect.y + event.y - self.mouse_offset;
            const max_y = self.widget.relative_rect.h - (button_size - 1) - widget.relative_rect.h;
            widget.relative_rect.y = std.math.clamp(y, button_size - 1, max_y);

            const max_widget = max_y - (button_size - 1);
            self.setValue(self.max_value * (widget.relative_rect.y - (button_size - 1)) / max_widget);
        } else {
            const x = widget.relative_rect.x + event.x - self.mouse_offset;
            const max_x = self.widget.relative_rect.w - button_size + 1 - widget.relative_rect.w;
            widget.relative_rect.x = std.math.clamp(x, button_size - 1, max_x);

            const max_widget = max_x - (button_size - 1);
            self.setValue(self.max_value * (widget.relative_rect.x - (button_size - 1)) / max_widget);
        }
    }
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    self.updateLayout();
}

fn updateLayout(self: *Self) void {
    const rect = self.widget.relative_rect;
    var button_size0: f32 = button_size;
    var button_size1: f32 = button_size;
    if (self.orientation == .vertical) {
        if (rect.h < 2 * button_size - 1) {
            button_size0 = @floor((rect.h + 1) / 2);
            button_size1 = rect.h + 1 - button_size0;
        }
        self.decrement_button.widget.relative_rect.h = button_size0;
        self.decrement_button.icon_y = @floor((button_size0 - 6 + 1) / 2);
        self.increment_button.widget.relative_rect.h = button_size1;
        self.increment_button.icon_y = @floor((button_size1 - 6 + 1) / 2);
        self.increment_button.widget.relative_rect.y = rect.h - button_size1;
    } else {
        if (rect.w < 2 * button_size - 1) {
            button_size0 = @floor((rect.w + 1) / 2);
            button_size1 = rect.w + 1 - button_size0;
        }
        self.decrement_button.widget.relative_rect.w = button_size0;
        self.decrement_button.icon_x = @floor((button_size0 - 6 + 1) / 2);
        self.increment_button.widget.relative_rect.w = button_size1;
        self.increment_button.icon_x = @floor((button_size1 - 6 + 1) / 2);
        self.increment_button.widget.relative_rect.x = rect.w - button_size1;
    }
    self.updateThumbSize();
    self.updateThumbPosition();
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    _ = self;
    _ = event;
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    const rect = widget.getRect();
    _ = self;
    _ = rect;
    _ = event;
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    _ = self;
    _ = event;
}

fn draw(widget: *gui.Widget, vg: nvg) void {
    //const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;

    // background
    vg.beginPath();
    vg.rect(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);
    vg.fillColor(gui.theme_colors.shadow);
    vg.fill();

    // border
    vg.beginPath();
    vg.rect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
    vg.strokeColor(gui.theme_colors.border);
    vg.stroke();

    widget.drawChildren(vg);
}
