const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const gui = @import("gui");
const icons = @import("icons.zig");
const nvg = @import("nanovg");
const Point = gui.geometry.Point;
const Rect = gui.geometry.Rect;
const Document = @import("Document.zig");
const LayerWidget = @import("LayerWidget.zig");

const LayerListWidget = @This();

widget: gui.Widget,
allocator: Allocator,

document: *Document, // just a reference

visible_button: *gui.Button,
lock_button: *gui.Button,
link_button: *gui.Button,

layer_widgets: ArrayList(*LayerWidget),

const Self = @This();

const name_w: f32 = 160; // col for layer names
const tile_size: f32 = 21;

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);

    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .visible_button = try gui.Button.init(allocator, Rect(f32).make(1 + 0 * tile_size, 1, 20, 20), ""),
        .lock_button = try gui.Button.init(allocator, Rect(f32).make(1 + 1 * tile_size, 1, 20, 20), ""),
        .link_button = try gui.Button.init(allocator, Rect(f32).make(1 + 2 * tile_size, 1, 20, 20), ""),
        .layer_widgets = ArrayList(*LayerWidget).init(allocator),
    };
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.drawFn = draw;

    self.visible_button.style = .toolbar;
    self.visible_button.onClickFn = onVisibleButtonClicked;
    self.lock_button.style = .toolbar;
    self.lock_button.onClickFn = onLockButtonClicked;
    self.link_button.style = .toolbar;
    self.link_button.onClickFn = onLinkButtonClicked;

    try self.widget.addChild(&self.visible_button.widget);
    try self.widget.addChild(&self.lock_button.widget);
    try self.widget.addChild(&self.link_button.widget);

    return self;
}

pub fn deinit(self: *Self) void {
    self.visible_button.deinit();
    self.lock_button.deinit();
    self.link_button.deinit();
    for (self.layer_widgets.items) |layer_widget| {
        layer_widget.deinit();
    }
    self.layer_widgets.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn onDocumentChanged(self: *Self) void {
    const layer_count = self.document.getLayerCount();

    // Sync layer widgets
    if (layer_count < self.layer_widgets.items.len) {
        const remove_count = self.layer_widgets.items.len - layer_count;
        for (self.layer_widgets.items[layer_count..]) |layer_widget| {
            layer_widget.deinit();
        }
        self.layer_widgets.shrinkRetainingCapacity(layer_count);
        self.widget.children.shrinkRetainingCapacity(self.widget.children.items.len - remove_count);
    } else {
        var i: u32 = @truncate(u32, self.layer_widgets.items.len);
        while (i < layer_count) : (i += 1) {
            const rect = Rect(f32).make(0, @intToFloat(f32, layer_count - i) * tile_size, 3 * tile_size, tile_size + 1);
            const layer_widget = LayerWidget.init(self.allocator, rect, self.document, i) catch return; // TODO: handle?
            self.layer_widgets.append(layer_widget) catch return;
            self.widget.addChild(&layer_widget.widget) catch return;
        }
    }
    for (self.layer_widgets.items) |layer_widget, i| {
        layer_widget.widget.relative_rect.y = @intToFloat(f32, layer_count - i) * tile_size;
    }

    self.updateVisibleButtons();
    self.updateLockButtons();
    self.updateLinkButtons();
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    if (event.button == .left) {
        self.selectFrameAndLayer(event.x, event.y);
    }
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    if (event.isButtonPressed(.left)) {
        self.selectFrameAndLayer(event.x, event.y);
    }
}

fn onVisibleButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const layer_count = self.document.getLayerCount();
    var all_visible: bool = true;
    var i: u32 = 0;
    while (i < layer_count) : (i += 1) {
        if (!self.document.isLayerVisible(i)) {
            all_visible = false;
            break;
        }
    }
    i = 0;
    while (i < layer_count) : (i += 1) {
        self.document.setLayerVisible(i, !all_visible);
    }
    self.updateVisibleButtons();
}

fn onLockButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const layer_count = self.document.getLayerCount();
    var all_unlocked: bool = true;
    var i: u32 = 0;
    while (i < layer_count) : (i += 1) {
        if (self.document.isLayerLocked(i)) {
            all_unlocked = false;
            break;
        }
    }
    i = 0;
    while (i < layer_count) : (i += 1) {
        self.document.setLayerLocked(i, all_unlocked);
    }
    self.updateLockButtons();
}

fn onLinkButtonClicked(button: *gui.Button) void {
    const self = @fieldParentPtr(Self, "widget", button.widget.parent.?);
    const layer_count = self.document.getLayerCount();
    var all_linked: bool = true;
    var i: u32 = 0;
    while (i < layer_count) : (i += 1) {
        if (!self.document.isLayerLinked(i)) {
            all_linked = false;
            break;
        }
    }
    i = 0;
    while (i < layer_count) : (i += 1) {
        self.document.setLayerLinked(i, !all_linked);
    }
    self.updateLinkButtons();
}

pub fn updateVisibleButtons(self: *Self) void {
    var any_visible: bool = false;
    for (self.layer_widgets.items) |layer_widget, i| {
        const visible = self.document.isLayerVisible(@truncate(u32, i));
        if (visible) any_visible = true;
        layer_widget.visible_button.iconFn = if (visible) icons.iconEyeOpen else icons.iconEyeClosed;
        layer_widget.visible_button.checked = !visible;
    }
    self.visible_button.iconFn = if (any_visible) icons.iconEyeOpen else icons.iconEyeClosed;
    self.visible_button.checked = !any_visible;
}

pub fn updateLockButtons(self: *Self) void {
    var any_unlocked: bool = false;
    for (self.layer_widgets.items) |layer_widget, i| {
        const locked = self.document.isLayerLocked(@truncate(u32, i));
        if (!locked) any_unlocked = true;
        layer_widget.lock_button.iconFn = if (locked) icons.iconLockClosed else icons.iconLockOpen;
        layer_widget.lock_button.checked = locked;
    }
    self.lock_button.iconFn = if (any_unlocked) icons.iconLockOpen else icons.iconLockClosed;
    self.lock_button.checked = !any_unlocked;
}

pub fn updateLinkButtons(self: *Self) void {
    var any_unlinked: bool = false;
    for (self.layer_widgets.items) |layer_widget, i| {
        const linked = self.document.isLayerLinked(@truncate(u32, i));
        if (!linked) any_unlinked = true;
        layer_widget.link_button.iconFn = if (linked) icons.iconLinked else icons.iconUnlinked;
        layer_widget.link_button.checked = linked;
    }
    self.link_button.iconFn = if (any_unlinked) icons.iconUnlinked else icons.iconLinked;
    self.link_button.checked = !any_unlinked;
}

fn selectFrameAndLayer(self: *Self, mouse_x: f32, mouse_y: f32) void {
    const frame_x = name_w;
    const frame_y = 0;
    if (mouse_x >= frame_x and mouse_y >= frame_y) {
        const frame = @floatToInt(u32, (mouse_x - frame_x) / tile_size);
        if (frame < self.document.getFrameCount()) {
            self.document.gotoFrame(frame);
        }
    }
    const layer_x = 3 * tile_size;
    const layer_y = tile_size;
    if (mouse_x >= layer_x and mouse_y >= layer_y) {
        const layer = @floatToInt(u32, (mouse_y - layer_y) / tile_size);
        if (layer < self.document.getLayerCount()) {
            self.document.selectLayer(self.document.getLayerCount() - 1 - layer);
        }
    }
}

fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    const rect = widget.relative_rect;

    vg.beginPath();
    vg.rect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
    vg.strokeColor(gui.theme_colors.border);
    vg.stroke();
    vg.save();
    defer vg.restore();
    vg.scissor(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);

    if (rect.w <= 2 or rect.h <= 2) return;
    {
        vg.save();
        defer vg.restore();
        vg.translate(rect.x + 1, rect.y + 1);

        const layer_count = self.document.getLayerCount();
        const frame_count = self.document.getFrameCount();

        // draw selection
        const selected_layer = self.document.selected_layer;
        const selected_frame = self.document.selected_frame;
        const grid_w = name_w + @intToFloat(f32, frame_count) * tile_size;
        const grid_h = @intToFloat(f32, 1 + layer_count) * tile_size;
        vg.beginPath();
        vg.rect(0, @intToFloat(f32, layer_count - selected_layer) * tile_size, grid_w, tile_size);
        vg.rect(name_w + @intToFloat(f32, selected_frame) * tile_size, 0, tile_size, grid_h);
        vg.fillColor(nvg.rgbf(1, 1, 1));
        vg.fill();

        // draw grid
        vg.beginPath();
        var row: usize = 1;
        while (row <= layer_count + 1) : (row += 1) {
            const row_y = @intToFloat(f32, row) * tile_size - 0.5;
            vg.moveTo(0, row_y);
            vg.lineTo(grid_w, row_y);
        }
        var col: usize = 1;
        while (col <= 3) : (col += 1) {
            const col_x = @intToFloat(f32, col) * tile_size - 0.5;
            vg.moveTo(col_x, 0);
            vg.lineTo(col_x, grid_h);
        }
        col = 0;
        while (col <= frame_count) : (col += 1) {
            const col_x = name_w + @intToFloat(f32, col) * tile_size - 0.5;
            vg.moveTo(col_x, 0);
            vg.lineTo(col_x, grid_h);
        }
        vg.strokeColor(gui.theme_colors.shadow);
        vg.stroke();

        // draw text
        var buf: [10]u8 = undefined;
        vg.fontFace("guifont");
        vg.fontSize(12);
        vg.fillColor(nvg.rgb(0, 0, 0));
        vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
        var frame: usize = 0;
        while (frame < frame_count) : (frame += 1) {
            const text = std.fmt.bufPrint(&buf, "{}", .{frame + 1}) catch unreachable;
            _ = vg.text(name_w + @intToFloat(f32, frame) * tile_size + 10, 10, text);
        }

        // draw cel indicators
        row = 0;
        while (row < layer_count) : (row += 1) {
            const y = @intToFloat(f32, layer_count - row) * tile_size + 10;
            col = 0;
            while (col < frame_count) : (col += 1) {
                const x = name_w + @intToFloat(f32, col) * tile_size + 10;
                if (self.document.layers.items[row].cels.items[col].bitmap == null) {
                    vg.beginPath();
                    vg.circle(x, y, 5.5);
                    vg.strokeColor(nvg.rgb(66, 66, 66));
                    vg.stroke();
                } else {
                    vg.beginPath();
                    vg.circle(x, y, 6);
                    vg.fillColor(nvg.rgb(66, 66, 66));
                    vg.fill();
                }
            }
        }
    }

    widget.drawChildren(vg);
}
