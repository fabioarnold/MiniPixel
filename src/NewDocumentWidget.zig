const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const geometry = @import("gui/geometry.zig");
const Point = geometry.Point;
const Rect = geometry.Rect;

const EditorWidget = @import("EditorWidget.zig");

const NewDocumentWidget = @This();

widget: gui.Widget,
allocator: Allocator,
editor_widget: *EditorWidget,
width_label: *gui.Label,
width_spinner: *gui.Spinner(i32),
height_label: *gui.Label,
height_spinner: *gui.Spinner(i32),
ok_button: *gui.Button,
cancel_button: *gui.Button,

onSelectedFn: ?fn (*Self) void = null,

const Self = @This();

pub fn init(allocator: Allocator, editor_widget: *EditorWidget) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, Rect(f32).make(0, 0, 240, 100)),
        .allocator = allocator,
        .editor_widget = editor_widget,
        .width_label = try gui.Label.init(allocator, Rect(f32).make(10, 20, 45, 20), "Width:"),
        .width_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(55, 20, 60, 20)),
        .height_label = try gui.Label.init(allocator, Rect(f32).make(125, 20, 45, 20), "Height:"),
        .height_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(170, 20, 60, 20)),
        .ok_button = try gui.Button.init(allocator, Rect(f32).make(240 - 160 - 10 - 10, 100 - 25 - 10, 80, 25), "OK"),
        .cancel_button = try gui.Button.init(allocator, Rect(f32).make(240 - 80 - 10, 100 - 25 - 10, 80, 25), "Cancel"),
    };
    self.widget.onKeyDownFn = onKeyDown;

    self.width_spinner.setValue(@intCast(i32, editor_widget.document.bitmap.width));
    self.height_spinner.setValue(@intCast(i32, editor_widget.document.bitmap.height));
    self.width_spinner.min_value = 1;
    self.height_spinner.min_value = 1;
    self.width_spinner.max_value = 1 << 14; // 16k
    self.height_spinner.max_value = 1 << 14;

    self.ok_button.onClickFn = onOkButtonClick;
    self.cancel_button.onClickFn = onCancelButtonClick;

    try self.widget.addChild(&self.width_label.widget);
    try self.widget.addChild(&self.width_spinner.widget);
    try self.widget.addChild(&self.height_label.widget);
    try self.widget.addChild(&self.height_spinner.widget);
    try self.widget.addChild(&self.ok_button.widget);
    try self.widget.addChild(&self.cancel_button.widget);

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    self.width_label.deinit();
    self.width_spinner.deinit();
    self.height_label.deinit();
    self.height_spinner.deinit();
    self.ok_button.deinit();
    self.cancel_button.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onKeyDown(widget: *gui.Widget, event: *gui.KeyEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    switch (event.key) {
        .Return => self.accept(),
        .Escape => self.cancel(),
        else => event.event.ignore(),
    }
}

fn onOkButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(Self, "widget", parent);
        self.accept();
    }
}

fn onCancelButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(Self, "widget", parent);
        self.cancel();
    }
}

fn accept(self: *Self) void {
    self.editor_widget.createNewDocument(
        @intCast(u32, self.width_spinner.value),
        @intCast(u32, self.height_spinner.value),
    ) catch {
        // TODO: error dialog
    };
    if (self.widget.getWindow()) |window| {
        window.close();
    }
}

fn cancel(self: *Self) void {
    if (self.widget.getWindow()) |window| {
        window.close();
    }
}

pub fn draw(widget: *gui.Widget) void {
    nvg.beginPath();
    nvg.rect(0, 0, 240, 55);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(0, 55, 240, 45);
    nvg.fillColor(gui.theme_colors.background);
    nvg.fill();

    widget.drawChildren();
}
