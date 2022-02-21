const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui.zig");
const event = @import("event.zig");
const Point = @import("geometry.zig").Point;
const Rect = @import("geometry.zig").Rect;

const Layout = struct {
    grow: bool = false,
};

const debug_focus = false;

const Widget = @This();

window: ?*gui.Window = null,
parent: ?*Widget = null,
children: ArrayList(*Widget),
relative_rect: Rect(f32), // Relative to parent
layout: Layout = Layout{},
focus_policy: event.FocusPolicy = event.FocusPolicy{},
enabled: bool = true,
visible: bool = true,

drawFn: fn (*Widget) void = drawChildren,

onResizeFn: fn (*Widget, *event.ResizeEvent) void = onResize,
onMouseMoveFn: fn (*Widget, *event.MouseEvent) void = onMouseMove,
onMouseDownFn: fn (*Widget, *event.MouseEvent) void = onMouseDown,
onMouseUpFn: fn (*Widget, *event.MouseEvent) void = onMouseUp,
onMouseWheelFn: fn (*Widget, *event.MouseEvent) void = onMouseWheel,
onTouchPanFn: fn (*Widget, *event.TouchEvent) void = onTouchPan,
onTouchZoomFn: fn (*Widget, *event.TouchEvent) void = onTouchZoom,
onKeyDownFn: fn (*Widget, *event.KeyEvent) void = onKeyDown,
onKeyUpFn: fn (*Widget, *event.KeyEvent) void = onKeyUp,
onTextInputFn: fn (*Widget, *event.TextInputEvent) void = onTextInput,
onFocusFn: fn (*Widget, *event.FocusEvent) void = onFocus,
onBlurFn: fn (*Widget, *event.FocusEvent) void = onBlur,
onEnterFn: fn (*Widget) void = onEnter,
onLeaveFn: fn (*Widget) void = onLeave,
onClipboardUpdateFn: fn (*Widget) void = onClipboardUpdate,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) Self {
    return Self{ .children = ArrayList(*Self).init(allocator), .relative_rect = rect };
}

pub fn deinit(self: *Self) void {
    self.children.deinit();
}

pub fn addChild(self: *Self, child: *Widget) !void {
    std.debug.assert(child.parent == null);
    child.parent = self;
    try self.children.append(child);
}

pub fn getWindow(self: *Self) ?*gui.Window {
    if (self.parent) |parent| {
        return parent.getWindow();
    }
    return self.window;
}

pub fn getApplication(self: *Self) ?*gui.Application {
    const window = self.getWindow() orelse return null;
    return window.application;
}

pub fn isEnabled(self: Self) bool {
    if (!self.enabled) return false;
    if (self.parent) |parent| {
        return parent.isEnabled();
    }
    return true;
}

pub fn isFocused(self: *Self) bool {
    if (self.getWindow()) |window| {
        return window.is_active and window.focused_widget == self;
    }
    return false;
}

pub fn setFocus(self: *Self, focus: bool, source: gui.FocusSource) void {
    if (focus and !self.acceptsFocus(source)) return;
    if (self.getWindow()) |window| {
        window.setFocusedWidget(if (focus) self else null, source);
    }
}

// local without position
pub fn getRect(self: Self) Rect(f32) {
    return .{ .x = 0, .y = 0, .w = self.relative_rect.w, .h = self.relative_rect.h };
}

// position relative to containing window
pub fn getWindowRelativeRect(self: *Self) Rect(f32) {
    if (self.parent) |parent| {
        const offset = parent.getWindowRelativeRect().getPosition();
        return self.relative_rect.translated(offset);
    } else {
        return self.relative_rect;
    }
}

pub fn setPosition(self: *Self, x: f32, y: f32) void {
    self.relative_rect.x = x;
    self.relative_rect.y = y;
}

// also fires event
pub fn setSize(self: *Self, width: f32, height: f32) void {
    if (width != self.relative_rect.w or height != self.relative_rect.h) {
        var re = event.ResizeEvent{
            .old_width = self.relative_rect.w,
            .old_height = self.relative_rect.h,
            .new_width = width,
            .new_height = height,
        };
        self.relative_rect.w = width;
        self.relative_rect.h = height;

        self.handleEvent(&re.event);
    }
}

pub fn drawChildren(self: *Self) void {
    nvg.save();
    defer nvg.restore();
    const offset = self.relative_rect.getPosition();
    nvg.translate(offset.x, offset.y);
    for (self.children.items) |child| {
        child.draw();
    }
}

pub fn draw(self: *Self) void {
    if (!self.visible) return;

    self.drawFn(self);

    if (debug_focus) {
        if (self.isFocused()) {
            nvg.beginPath();
            const r = self.relative_rect;
            nvg.rect(r.x, r.y, r.w - 1, r.h - 1);
            nvg.strokeColor(nvg.rgbf(1, 0, 0));
            nvg.stroke();
        }
    }
}

pub const HitTestResult = struct {
    widget: *Widget,
    local_position: Point(f32),
};

pub fn hitTest(self: *Self, position: Point(f32)) HitTestResult {
    const relative_position = position.subtracted(self.relative_rect.getPosition());
    for (self.children.items) |child| {
        if (child.visible and child.relative_rect.contains(relative_position)) {
            return child.hitTest(relative_position);
        }
    }
    return HitTestResult{ .widget = self, .local_position = relative_position };
}

fn onResize(self: *Self, resize_event: *event.ResizeEvent) void {
    _ = resize_event;
    _ = self;
}

fn onMouseMove(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseDown(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseUp(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseWheel(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onTouchPan(self: *Self, touch_event: *event.TouchEvent) void {
    _ = touch_event;
    _ = self;
}

fn onTouchZoom(self: *Self, touch_event: *event.TouchEvent) void {
    _ = touch_event;
    _ = self;
}

pub fn onKeyDown(self: *Self, key_event: *event.KeyEvent) void {
    if (key_event.key == .Tab) {
        if (key_event.modifiers == 0) {
            self.focusNextWidget(.keyboard);
            key_event.event.accept();
            return;
        } else if (key_event.isSingleModifierPressed(.shift)) {
            self.focusPreviousWidget(.keyboard);
            key_event.event.accept();
            return;
        }
    }
    key_event.event.ignore();
}

fn onKeyUp(self: *Self, key_event: *event.KeyEvent) void {
    _ = self;
    key_event.event.ignore();
}

fn onTextInput(self: *Self, text_input_event: *event.TextInputEvent) void {
    _ = text_input_event;
    _ = self;
}

fn onFocus(self: *Self, focus_event: *event.FocusEvent) void {
    _ = focus_event;
    _ = self;
}

fn onBlur(self: *Self, focus_event: *event.FocusEvent) void {
    _ = focus_event;
    _ = self;
}

fn onEnter(self: *Self) void {
    _ = self;
}

fn onLeave(self: *Self) void {
    _ = self;
}

fn onClipboardUpdate(self: *Self) void {
    _ = self;
}

/// bubbles event up until it is accepted
pub fn dispatchEvent(self: *Self, e: *event.Event) void {
    var maybe_target: ?*Self = self;
    while (maybe_target) |target| : (maybe_target = target.parent) {
        target.handleEvent(e);
        if (e.is_accepted) break;
    }
}

pub fn handleEvent(self: *Self, e: *event.Event) void {
    const resize_event = @fieldParentPtr(event.ResizeEvent, "event", e);
    const mouse_event = @fieldParentPtr(event.MouseEvent, "event", e);
    const touch_event = @fieldParentPtr(event.TouchEvent, "event", e);
    const key_event = @fieldParentPtr(event.KeyEvent, "event", e);
    const text_input_event = @fieldParentPtr(event.TextInputEvent, "event", e);
    const focus_event = @fieldParentPtr(event.FocusEvent, "event", e);

    switch (e.type) {
        .Resize => self.onResizeFn(self, resize_event),
        .MouseMove => self.onMouseMoveFn(self, mouse_event),
        .MouseDown => {
            if (self.acceptsFocus(.mouse)) {
                self.setFocus(true, .mouse);
            }
            self.onMouseDownFn(self, mouse_event);
        },
        .MouseUp => self.onMouseUpFn(self, mouse_event),
        .MouseWheel => self.onMouseWheelFn(self, mouse_event),
        .TouchPan => self.onTouchPanFn(self, touch_event),
        .TouchZoom => self.onTouchZoomFn(self, touch_event),
        .KeyDown => self.onKeyDownFn(self, key_event),
        .KeyUp => self.onKeyUpFn(self, key_event),
        .TextInput => self.onTextInputFn(self, text_input_event),
        .Focus => self.onFocusFn(self, focus_event),
        .Blur => self.onBlurFn(self, focus_event),
        .Enter => self.onEnterFn(self),
        .Leave => self.onLeaveFn(self),
        .ClipboardUpdate => self.onClipboardUpdateFn(self),
    }
}

pub fn acceptsFocus(self: Self, source: event.FocusSource) bool {
    return self.visible and self.focus_policy.accepts(source) and self.isEnabled();
}

fn focusNextWidget(self: *Self, source: event.FocusSource) void {
    if (!self.acceptsFocus(source)) return;
    const window = self.getWindow() orelse return;
    var focusable_widgets = std.ArrayList(*gui.Widget).init(self.children.allocator);
    defer focusable_widgets.deinit();
    window.collectFocusableWidgets(&focusable_widgets, source) catch return;

    if (std.mem.indexOfScalar(*gui.Widget, focusable_widgets.items, self)) |i| {
        const next_i = (i + 1) % focusable_widgets.items.len;
        focusable_widgets.items[next_i].setFocus(true, .keyboard);
    }
}

fn focusPreviousWidget(self: *Self, source: event.FocusSource) void {
    if (!self.acceptsFocus(source)) return;
    const window = self.getWindow() orelse return;
    var focusable_widgets = std.ArrayList(*gui.Widget).init(self.children.allocator);
    defer focusable_widgets.deinit();
    window.collectFocusableWidgets(&focusable_widgets, source) catch return;

    if (std.mem.indexOfScalar(*gui.Widget, focusable_widgets.items, self)) |i| {
        const n = focusable_widgets.items.len;
        const previous_i = (i + n - 1) % n;
        focusable_widgets.items[previous_i].setFocus(true, .keyboard);
    }
}
