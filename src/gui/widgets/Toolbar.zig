const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

const pad: f32 = 2;

const Self = @This();

widget: gui.Widget,
allocator: Allocator,

has_grip: bool = false,

separators: ArrayList(*gui.Widget),

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .separators = ArrayList(*gui.Widget).init(allocator),
    };

    self.widget.onResizeFn = onResize;
    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    for (self.separators.items) |widget| {
        self.allocator.destroy(widget);
    }
    self.separators.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onResize(widget: *gui.Widget, _: *gui.ResizeEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    self.updateLayout();
}

fn updateLayout(self: Self) void {
    var rem = self.widget.relative_rect.w - pad;
    var grow_count: u32 = 0;
    for (self.widget.children.items) |child| {
        if (child.layout.grow) {
            grow_count += 1;
        } else {
            rem -= child.relative_rect.w + pad;
        }
    }
    if (rem < 0) rem = 0;
    var x = pad;
    for (self.widget.children.items) |child| {
        child.relative_rect.x = x;
        if (child.layout.grow) {
            child.relative_rect.w = @round(rem / @intToFloat(f32, grow_count) - pad);
            rem -= child.relative_rect.w + pad;
            grow_count -= 1;
        }
        x += child.relative_rect.w + pad;
    }
}

pub fn addButton(self: *Self, button: *gui.Button) !void {
    button.style = .toolbar;
    button.widget.focus_policy = gui.FocusPolicy.none();
    button.widget.relative_rect.w = 20;
    button.widget.relative_rect.h = 20;
    try self.addWidget(&button.widget);
}

pub fn addSeparator(self: *Self) !void {
    var separator = try self.allocator.create(gui.Widget);
    separator.* = gui.Widget.init(self.allocator, Rect(f32).make(0, 0, 4, 20));
    separator.drawFn = drawSeparator;
    try self.separators.append(separator);
    try self.addWidget(separator);
}

pub fn addWidget(self: *Self, widget: *gui.Widget) !void {
    widget.relative_rect.y = pad;
    try self.widget.addChild(widget);
    self.updateLayout();
}

fn drawSeparator(widget: *gui.Widget, vg: nvg) void {
    const rect = widget.relative_rect;

    vg.beginPath();
    vg.rect(rect.x + 1, rect.y + 1, 1, rect.h - 2);
    vg.fillColor(gui.theme_colors.shadow);
    vg.fill();
    vg.beginPath();
    vg.rect(rect.x + 2, rect.y + 1, 1, rect.h - 2);
    vg.fillColor(gui.theme_colors.light);
    vg.fill();
}

fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    gui.drawPanel(vg, rect.x, rect.y, rect.w, rect.h, 1, false, false);

    if (self.has_grip) {
        drawGrip(vg, rect.x + rect.w - 16, rect.y + rect.h - 16);
    }

    widget.drawChildren(vg);
}

fn drawGrip(vg: nvg, x: f32, y: f32) void {
    vg.scissor(x, y, 14, 14);
    defer vg.resetScissor();

    vg.beginPath();
    vg.moveTo(x, y + 16);
    vg.lineTo(x + 16, y);
    vg.moveTo(x + 4, y + 16);
    vg.lineTo(x + 4 + 16, y);
    vg.moveTo(x + 8, y + 16);
    vg.lineTo(x + 8 + 16, y);
    vg.strokeColor(gui.theme_colors.light);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(x + 1, y + 16);
    vg.lineTo(x + 1 + 16, y);
    vg.moveTo(x + 5, y + 16);
    vg.lineTo(x + 5 + 16, y);
    vg.moveTo(x + 9, y + 16);
    vg.lineTo(x + 9 + 16, y);
    vg.strokeColor(gui.theme_colors.shadow);
    vg.stroke();
}
