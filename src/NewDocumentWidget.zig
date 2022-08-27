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
color_label: *gui.Label,
indexed_radio: *gui.RadioButton,
truecolor_radio: *gui.RadioButton,
ok_button: *gui.Button,
cancel_button: *gui.Button,

onSelectedFn: ?*const fn (*Self) void = null,

const Self = @This();

pub fn init(allocator: Allocator, editor_widget: *EditorWidget) !*Self {
    const rect = Rect(f32).make(0, 0, 240, 100);
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .editor_widget = editor_widget,
        .width_label = try gui.Label.init(allocator, Rect(f32).make(10, 10, 45, 20), "Width:"),
        .width_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(55, 10, 60, 20)),
        .height_label = try gui.Label.init(allocator, Rect(f32).make(125, 10, 45, 20), "Height:"),
        .height_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(170, 10, 60, 20)),
        .color_label = try gui.Label.init(allocator, Rect(f32).make(10, 35, 45, 20), "Color:"),
        .indexed_radio = try gui.RadioButton.init(allocator, Rect(f32).make(55, 35, 95, 20), "Indexed (8-bit)"),
        .truecolor_radio = try gui.RadioButton.init(allocator, Rect(f32).make(160 - 3, 35, 70 + 3, 20), "True color"),
        .ok_button = try gui.Button.init(allocator, Rect(f32).make(rect.w - 160 - 10 - 10, rect.h - 25 - 10, 80, 25), "OK"),
        .cancel_button = try gui.Button.init(allocator, Rect(f32).make(rect.w - 80 - 10, rect.h - 25 - 10, 80, 25), "Cancel"),
    };
    self.widget.onKeyDownFn = onKeyDown;

    self.width_spinner.setValue(@intCast(i32, editor_widget.document.getWidth()));
    self.height_spinner.setValue(@intCast(i32, editor_widget.document.getHeight()));
    self.width_spinner.min_value = 1;
    self.height_spinner.min_value = 1;
    self.width_spinner.max_value = 1 << 14; // 16k
    self.height_spinner.max_value = 1 << 14;
    self.truecolor_radio.checked = true;
    self.truecolor_radio.onClickFn = onTruecolorRadioClick;
    self.indexed_radio.onClickFn = onIndexedRadioClick;

    self.ok_button.onClickFn = onOkButtonClick;
    self.cancel_button.onClickFn = onCancelButtonClick;

    try self.widget.addChild(&self.width_label.widget);
    try self.widget.addChild(&self.width_spinner.widget);
    try self.widget.addChild(&self.height_label.widget);
    try self.widget.addChild(&self.height_spinner.widget);
    try self.widget.addChild(&self.color_label.widget);
    try self.widget.addChild(&self.indexed_radio.widget);
    try self.widget.addChild(&self.truecolor_radio.widget);
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
    self.color_label.deinit();
    self.indexed_radio.deinit();
    self.truecolor_radio.deinit();
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

fn onIndexedRadioClick(radio: *gui.RadioButton) void {
    if (radio.widget.parent) |parent| {
        var self = @fieldParentPtr(Self, "widget", parent);
        self.indexed_radio.checked = true;
        self.truecolor_radio.checked = false;
    }
}

fn onTruecolorRadioClick(radio: *gui.RadioButton) void {
    if (radio.widget.parent) |parent| {
        var self = @fieldParentPtr(Self, "widget", parent);
        self.indexed_radio.checked = false;
        self.truecolor_radio.checked = true;
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
        if (self.truecolor_radio.checked) .color else .indexed,
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

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const rect = widget.relative_rect;
    gui.drawPanel(vg, rect.x, rect.y, rect.w, rect.h, 1, false, false);

    widget.drawChildren(vg);
}
