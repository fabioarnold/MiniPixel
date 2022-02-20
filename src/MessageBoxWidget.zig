const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const geometry = @import("gui/geometry.zig");
const Rect = geometry.Rect;

pub const Buttons = enum {
    ok,
    yes_no_cancel,
};

pub const Icon = enum {
    @"error",
    question,
};

pub const Result = enum {
    none,
    ok,
    cancel,
    yes,
    no,
};

const MessageBoxWidget = @This();

widget: gui.Widget,
allocator: Allocator,
drawIconFn: fn (f32, f32) void,
message_label: *gui.Label,
ok_button: *gui.Button,
cancel_button: *gui.Button,
yes_button: *gui.Button,
no_button: *gui.Button,
result: Result = .none,

pub fn init(allocator: Allocator, message: []const u8) !*MessageBoxWidget {
    const width = 240;
    const height = 100;
    var self = try allocator.create(MessageBoxWidget);
    self.* = MessageBoxWidget{
        .widget = gui.Widget.init(allocator, Rect(f32).make(0, 0, width, height)),
        .allocator = allocator,
        .drawIconFn = drawNoIcon,
        .message_label = try gui.Label.init(allocator, Rect(f32).make(10 + 32 + 10, 10, width - 30 - 32, 40), message),
        .ok_button = try gui.Button.init(allocator, Rect(f32).make(width - 80 - 10, height - 25 - 10, 80, 25), "OK"),
        .cancel_button = try gui.Button.init(allocator, Rect(f32).make(width - 80 - 10, height - 25 - 10, 80, 25), "Cancel"),
        .yes_button = try gui.Button.init(allocator, Rect(f32).make(width - 80 - 10, height - 25 - 10, 80, 25), "Yes"),
        .no_button = try gui.Button.init(allocator, Rect(f32).make(width - 80 - 10, height - 25 - 10, 80, 25), "No"),
    };
    self.widget.onKeyDownFn = onKeyDown;

    self.ok_button.onClickFn = onOkButtonClick;
    self.cancel_button.onClickFn = onCancelButtonClick;
    self.yes_button.onClickFn = onYesButtonClick;
    self.no_button.onClickFn = onNoButtonClick;

    try self.widget.addChild(&self.message_label.widget);
    try self.widget.addChild(&self.ok_button.widget);
    try self.widget.addChild(&self.cancel_button.widget);
    try self.widget.addChild(&self.yes_button.widget);
    try self.widget.addChild(&self.no_button.widget);

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *MessageBoxWidget) void {
    self.message_label.deinit();
    self.ok_button.deinit();
    self.cancel_button.deinit();
    self.yes_button.deinit();
    self.no_button.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn setSize(self: *MessageBoxWidget, width: f32, height: f32) void {
    self.message_label.widget.setSize(width - 30 - 32, 40);
    self.widget.setSize(width, height);
}

pub fn configure(self: *MessageBoxWidget, icon: Icon, buttons: Buttons, message: []const u8) void {
    self.drawIconFn = switch (icon) {
        .@"error" => drawErrorIcon,
        .question => drawQuestionIcon,
    };
    const rect = self.widget.relative_rect;
    switch (buttons) {
        .ok => {
            self.ok_button.widget.setPosition(0.5 * rect.w - 40, rect.h - 35);
            self.ok_button.widget.visible = true;
            self.cancel_button.widget.visible = false;
            self.yes_button.widget.visible = false;
            self.no_button.widget.visible = false;
        },
        .yes_no_cancel => {
            self.ok_button.widget.visible = false;
            self.cancel_button.widget.setPosition(rect.w - 90, rect.h - 35);
            self.cancel_button.widget.visible = true;
            self.yes_button.widget.setPosition(rect.w - 90 - 90 - 90, rect.h - 35);
            self.yes_button.widget.visible = true;
            self.no_button.widget.setPosition(rect.w - 90 - 90, rect.h - 35);
            self.no_button.widget.visible = true;
        }
    }
    self.message_label.text = message;
}

fn onKeyDown(widget: *gui.Widget, event: *gui.KeyEvent) void {
    var self = @fieldParentPtr(MessageBoxWidget, "widget", widget);
    switch (event.key) {
        .Return => self.setResult(if (self.ok_button.widget.visible) .ok else .yes),
        .Escape => self.setResult(if (self.cancel_button.widget.visible) .cancel else .none),
        else => event.event.ignore(),
    }
}

fn onOkButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(MessageBoxWidget, "widget", parent);
        self.setResult(.ok);
    }
}

fn onCancelButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(MessageBoxWidget, "widget", parent);
        self.setResult(.cancel);
    }
}

fn onYesButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(MessageBoxWidget, "widget", parent);
        self.setResult(.yes);
    }
}

fn onNoButtonClick(button: *gui.Button) void {
    if (button.widget.parent) |parent| {
        var self = @fieldParentPtr(MessageBoxWidget, "widget", parent);
        self.setResult(.no);
    }
}

fn setResult(self: *MessageBoxWidget, result: Result) void {
    self.result = result;
    if (self.widget.getWindow()) |window| {
        window.close();
    }
}

fn drawNoIcon(x: f32, y: f32) void {
    _ = x;
    _ = y;
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

fn drawQuestionIcon(x: f32, y: f32) void {
    nvg.save();
    defer nvg.restore();
    nvg.translate(x, y);
    nvg.beginPath();
    nvg.circle(16, 16, 15.5);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
    nvg.fillColor(nvg.rgb(10, 32, 231));
    nvg.fontFace("guifontbold");
    nvg.fontSize(22);
    nvg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    _ = nvg.text(16, 16 + 2, "?");
}

pub fn draw(widget: *gui.Widget) void {
    var self = @fieldParentPtr(MessageBoxWidget, "widget", widget);
    const rect = widget.relative_rect;

    nvg.beginPath();
    nvg.rect(0, 0, rect.w, rect.h - 45);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(0, rect.h - 45, rect.w, 45);
    nvg.fillColor(gui.theme_colors.background);
    nvg.fill();

    self.drawIconFn(10, 13);

    widget.drawChildren();
}
