const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const geometry = @import("gui/geometry.zig");
const Rect = geometry.Rect;

const ErrorMessageWidget = @This();

widget: gui.Widget,
allocator: *Allocator,
message_label: *gui.Label,
ok_button: *gui.Button,

const Self = @This();

pub fn init(allocator: *Allocator, message: []const u8) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, Rect(f32).make(0, 0, 240, 100)),
        .allocator = allocator,
        .message_label = try gui.Label.init(allocator, Rect(f32).make(10 + 32 + 10, 20, 0, 20), message),
        .ok_button = try gui.Button.init(allocator, Rect(f32).make(240 - 80 - 10, 100 - 25 - 10, 80, 25), "OK"),
    };
    self.widget.onKeyDownFn = onKeyDown;

    self.ok_button.onClickFn = onOkButtonClick;

    try self.widget.addChild(&self.message_label.widget);
    try self.widget.addChild(&self.ok_button.widget);

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    self.message_label.deinit();
    self.ok_button.deinit();
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
    if (self.widget.getWindow()) |window| {
        window.close();
    }
}

fn cancel(self: *Self) void {
    if (self.widget.getWindow()) |window| {
        window.close();
    }
}

fn drawErrorIcon(x: f32, y: f32) void {
    nvg.save();
    defer nvg.restore();
    nvg.translate(x, y);
    nvg.beginPath();
    nvg.circle(16, 16, 15.5);
    nvg.fillColor(nvg.rgb(250, 10, 0));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(9, 9);
    nvg.lineTo(23, 23);
    nvg.moveTo(23, 9);
    nvg.lineTo(9, 23);
    nvg.strokeColor(nvg.rgbf(1, 1, 1));
    nvg.strokeWidth(3);
    nvg.stroke();
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

    drawErrorIcon(10, 13);

    widget.drawChildren();
}
