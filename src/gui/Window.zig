const std = @import("std");

const nvg = @import("nanovg");
const gui = @import("gui.zig");
const event = @import("event.zig");
const Point = @import("geometry.zig").Point;

const Window = @This();

allocator: std.mem.Allocator,
application: *gui.Application,

id: u32,
width: f32,
height: f32,
is_modal: bool = false,

is_active: bool = true,

parent: ?*gui.Window = null,
children: std.ArrayList(*gui.Window),

main_widget: ?*gui.Widget = null,
focused_widget: ?*gui.Widget = null,
hovered_widget: ?*gui.Widget = null,
automatic_cursor_tracking_widget: ?*gui.Widget = null,

cursorFn: ?*const fn (nvg) void = null,
mouse_pos: Point(f32) = Point(f32).make(0, 0),

close_request_context: usize = 0,
onCloseRequestFn: ?*const fn (usize) bool = null, // true: yes, close window. false: no, don't close window.

closed_context: usize = 0,
onClosedFn: ?*const fn (usize) void = null,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, application: *gui.Application) !*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        .allocator = allocator,
        .application = application,
        .id = 0,
        .width = 0,
        .height = 0,
        .children = std.ArrayList(*Window).init(allocator),
    };
    return self;
}

pub fn deinit(self: *Self) void {
    if (self.parent) |parent| {
        // remove reference from parent
        parent.removeChild(self);
        self.parent = null;
    }
    for (self.children.items) |child| {
        child.parent = null;
    }
    self.children.deinit();
    self.allocator.destroy(self);
}

pub const CreateOptions = struct {
    resizable: bool = true,
    parent_id: ?u32 = null,
};

pub fn createChildWindow(self: *Self, title: [:0]const u8, width: f32, height: f32, options: CreateOptions) !*gui.Window {
    const child_window = try self.application.createWindow(title, width, height, CreateOptions{
        .resizable = options.resizable,
        .parent_id = self.id,
    });
    child_window.parent = self;
    try self.children.append(child_window);
    return child_window;
}

pub fn close(self: *Self) void {
    self.application.requestWindowClose(self);
}

pub fn setMainWidget(self: *Self, widget: ?*gui.Widget) void {
    if (self.main_widget == widget) return;
    if (self.main_widget) |main_widget| {
        main_widget.window = null;
    }
    self.main_widget = widget;
    if (self.main_widget) |main_widget| {
        main_widget.window = self;
    }
}

pub fn setFocusedWidget(self: *Self, widget: ?*gui.Widget, source: gui.FocusSource) void {
    if (self.focused_widget == widget) return;
    if (self.focused_widget) |focused_widget| {
        var blur_event = event.FocusEvent{ .event = .{ .type = .Blur }, .source = source };
        focused_widget.dispatchEvent(&blur_event.event);
    }
    self.focused_widget = widget;
    if (self.focused_widget) |focused_widget| {
        var focus_event = event.FocusEvent{ .event = .{ .type = .Focus }, .source = source };
        focused_widget.dispatchEvent(&focus_event.event);
    }
}

fn setHoveredWidget(self: *Self, widget: ?*gui.Widget) void {
    if (self.hovered_widget == widget) return;
    if (self.hovered_widget) |hovered_widget| {
        var leave_event = event.Event{ .type = .Leave };
        hovered_widget.dispatchEvent(&leave_event);
    }
    self.hovered_widget = widget;
    if (self.hovered_widget) |hovered_widget| {
        var enter_event = event.Event{ .type = .Enter };
        hovered_widget.dispatchEvent(&enter_event);
    }
}

pub fn isBlockedByModal(self: *Self) bool {
    for (self.children.items) |child| {
        if (child.is_modal) return true;
        if (child.isBlockedByModal()) return true;
    }
    return false;
}

pub fn removeChild(self: *Self, child: *gui.Window) void {
    if (std.mem.indexOfScalar(*gui.Window, self.children.items, child)) |i| {
        _ = self.children.swapRemove(i);
    }
}

pub fn collectFocusableWidgets(self: Self, focusable_widgets: *std.ArrayList(*gui.Widget), source: event.FocusSource) !void {
    const main_widget = self.main_widget orelse return error.NoMainWidget;

    const collect_focusable_widgets = struct {
        fn collect(widget: *gui.Widget, list: *std.ArrayList(*gui.Widget), s: event.FocusSource) error{OutOfMemory}!void {
            for (widget.children.items) |child| {
                if (child.acceptsFocus(s)) try list.append(child);
                try collect(child, list, s);
            }
        }
    }.collect;

    try collect_focusable_widgets(main_widget, focusable_widgets, source);
}

pub fn handleEvent(self: *Self, e: *event.Event) void {
    if (self.isBlockedByModal()) {
        if (e.type != .Leave) return;
    }

    const mouse_event = @fieldParentPtr(event.MouseEvent, "event", e);
    const touch_event = @fieldParentPtr(event.TouchEvent, "event", e);
    switch (e.type) {
        .MouseMove, .MouseDown, .MouseUp, .MouseWheel => self.handleMouseEvent(mouse_event),
        .TouchPan, .TouchZoom => self.handleTouchEvent(touch_event),
        .KeyDown, .KeyUp, .TextInput => self.handleKeyEvent(e),
        .Enter => self.setHoveredWidget(self.main_widget),
        .Leave => self.setHoveredWidget(null),
        else => {
            if (self.main_widget) |main_widget| {
                main_widget.handleEvent(e);
            }
        },
    }
}

fn handleMouseEvent(self: *Self, mouse_event: *event.MouseEvent) void {
    self.mouse_pos = Point(f32).make(mouse_event.x, mouse_event.y);

    if (self.automatic_cursor_tracking_widget) |widget| {
        if (mouse_event.event.type == .MouseUp and mouse_event.state == 0) {
            self.automatic_cursor_tracking_widget = null;
        }
        const window_relative_rect = widget.getWindowRelativeRect();
        var local_event = mouse_event.*;
        local_event.x -= window_relative_rect.x;
        local_event.y -= window_relative_rect.y;
        widget.dispatchEvent(&local_event.event);
    } else if (self.main_widget) |main_widget| {
        const position = Point(f32).make(mouse_event.x, mouse_event.y);
        const result = main_widget.hitTest(position);
        var local_event = mouse_event.*;
        local_event.x = result.local_position.x;
        local_event.y = result.local_position.y;
        self.setHoveredWidget(result.widget);
        if (mouse_event.event.type == .MouseDown) {
            self.automatic_cursor_tracking_widget = result.widget;
        }
        result.widget.dispatchEvent(&local_event.event);
    }
}

fn handleTouchEvent(self: *Self, touch_event: *event.TouchEvent) void {
    self.mouse_pos = Point(f32).make(touch_event.x, touch_event.y);
    if (self.main_widget) |main_widget| {
        const position = Point(f32).make(touch_event.x, touch_event.y);
        const result = main_widget.hitTest(position);
        var local_event = touch_event.*;
        local_event.x = result.local_position.x;
        local_event.y = result.local_position.y;
        self.setHoveredWidget(result.widget);
        result.widget.dispatchEvent(&local_event.event);
    }
}

fn handleKeyEvent(self: Self, key_event: *event.Event) void {
    if (self.focused_widget) |focused_widget| {
        return focused_widget.dispatchEvent(key_event);
    }
    if (self.main_widget) |main_widget| {
        // is root -> no need to dispatch
        return main_widget.handleEvent(key_event);
    }
}

pub fn setSize(self: *Self, width: f32, height: f32) void {
    if (self.width == width and self.height == height) return;
    self.width = width;
    self.height = height;
    if (self.main_widget) |main_widget| {
        main_widget.setSize(width, height);
    }
}

pub fn setTitle(self: *Self, title: [:0]const u8) void {
    gui.Application.setWindowTitle(self.id, title);
}

pub fn setCursor(self: *Self, cursor: ?*const fn (nvg) void) void {
    gui.Application.showCursor(cursor == null);
    self.cursorFn = cursor;
}

pub fn draw(self: Self, vg: nvg) void {
    if (self.main_widget) |main_widget| {
        main_widget.draw(vg);
    }

    if (self.cursorFn) |cursor| {
        vg.save();
        vg.translate(self.mouse_pos.x, self.mouse_pos.y);
        cursor(vg);
        vg.restore();
    }
}
