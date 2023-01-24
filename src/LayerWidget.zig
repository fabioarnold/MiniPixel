const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const icons = @import("icons.zig");
const Rect = gui.geometry.Rect;

const Document = @import("Document.zig");
const LayerListWidget = @import("LayerListWidget.zig");

widget: gui.Widget,
allocator: Allocator,

document: *Document, // just a reference
layer_index: u32,

visible_button: *gui.Button,
lock_button: *gui.Button,
link_button: *gui.Button,
name_label: *gui.Label,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document, layer_index: u32) !*Self {
    var self = try allocator.create(Self);

    const layer_name = try std.fmt.allocPrint(allocator, "Layer {}", .{layer_index + 1});

    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .layer_index = layer_index,
        .visible_button = try gui.Button.init(allocator, Rect(f32).make(1, 1, 20, 20), ""),
        .lock_button = try gui.Button.init(allocator, Rect(f32).make(22, 1, 20, 20), ""),
        .link_button = try gui.Button.init(allocator, Rect(f32).make(43, 1, 20, 20), ""),
        .name_label = try gui.Label.init(allocator, Rect(f32).make(64, 1, 95, 20), layer_name),
    };

    self.visible_button.style = .toolbar;
    self.visible_button.onClickFn = onVisibleButtonClicked;
    self.lock_button.style = .toolbar;
    self.lock_button.onClickFn = onLockButtonClicked;
    self.link_button.style = .toolbar;
    self.link_button.onClickFn = onLinkButtonClicked;
    self.name_label.padding = 4;

    try self.widget.addChild(&self.visible_button.widget);
    try self.widget.addChild(&self.lock_button.widget);
    try self.widget.addChild(&self.link_button.widget);
    try self.widget.addChild(&self.name_label.widget);

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.name_label.text);
    self.visible_button.deinit();
    self.lock_button.deinit();
    self.link_button.deinit();
    self.name_label.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn onVisibleButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const visible = self.document.isLayerVisible(self.layer_index);
    self.document.setLayerVisible(self.layer_index, !visible);
    const layer_list = @fieldParentPtr(LayerListWidget, "widget", self.widget.parent.?);
    layer_list.updateVisibleButtons();
}

pub fn onLockButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const locked = self.document.isLayerLocked(self.layer_index);
    self.document.setLayerLocked(self.layer_index, !locked);
    const layer_list = @fieldParentPtr(LayerListWidget, "widget", self.widget.parent.?);
    layer_list.updateLockButtons();
}

pub fn onLinkButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const linked = self.document.isLayerLinked(self.layer_index);
    self.document.setLayerLinked(self.layer_index, !linked);
    const layer_list = @fieldParentPtr(LayerListWidget, "widget", self.widget.parent.?);
    layer_list.updateLinkButtons();
}
