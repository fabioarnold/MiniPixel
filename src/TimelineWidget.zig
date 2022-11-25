const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const gui = @import("gui");
const icons = @import("icons.zig");
const nvg = @import("nanovg");
const geometry = @import("gui/geometry.zig");
const Point = geometry.Point;
const Rect = geometry.Rect;
const Document = @import("Document.zig");
const LayerWidget = @import("LayerWidget.zig");

const TimelineWidget = @This();

widget: gui.Widget,
allocator: Allocator,

document: *Document, // just a reference

begin_button: *gui.Button,
left_button: *gui.Button,
play_button: *gui.Button,
right_button: *gui.Button,
end_button: *gui.Button,

add_frame_button: *gui.Button,
delete_frame_button: *gui.Button,

add_layer_button: *gui.Button,
delete_layer_button: *gui.Button,

visible_button: *gui.Button,
lock_button: *gui.Button,
link_button: *gui.Button,

onion_skinning_button: *gui.Button,

layer_widgets: ArrayList(*LayerWidget),

const Self = @This();

const name_w: f32 = 160; // col for layer names
const tile_w: f32 = 22;

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);

    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .begin_button = try gui.Button.init(allocator, Rect(f32).make(5 + 0 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .left_button = try gui.Button.init(allocator, Rect(f32).make(5 + 1 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .play_button = try gui.Button.init(allocator, Rect(f32).make(5 + 2 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .right_button = try gui.Button.init(allocator, Rect(f32).make(5 + 3 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .end_button = try gui.Button.init(allocator, Rect(f32).make(5 + 4 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .add_frame_button = try gui.Button.init(allocator, Rect(f32).make(15 + 5 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .delete_frame_button = try gui.Button.init(allocator, Rect(f32).make(15 + 6 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .add_layer_button = try gui.Button.init(allocator, Rect(f32).make(25 + 7 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .delete_layer_button = try gui.Button.init(allocator, Rect(f32).make(25 + 8 * (tile_w - 1), 5, tile_w, tile_w), ""),
        .visible_button = try gui.Button.init(allocator, Rect(f32).make(6, 5 + tile_w + 6, 20, 20), ""),
        .lock_button = try gui.Button.init(allocator, Rect(f32).make(27, 5 + tile_w + 6, 20, 20), ""),
        .link_button = try gui.Button.init(allocator, Rect(f32).make(48, 5 + tile_w + 6, 20, 20), ""),
        .onion_skinning_button = try gui.Button.init(allocator, Rect(f32).make(5 + 64, 5 + tile_w + 5, 20, 20), ""),
        .layer_widgets = ArrayList(*LayerWidget).init(allocator),
    };
    self.widget.onResizeFn = onResize;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.drawFn = draw;

    self.begin_button.iconFn = icons.iconTimelineBegin;
    self.begin_button.icon_x = 4;
    self.begin_button.icon_y = 4;
    self.begin_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.gotoFirstFrame();
        }
    }.click;
    self.left_button.iconFn = icons.iconTimelineLeft;
    self.left_button.icon_x = 4;
    self.left_button.icon_y = 4;
    self.left_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.gotoPrevFrame();
        }
    }.click;
    self.play_button.iconFn = icons.iconTimelinePlay;
    self.play_button.icon_x = 4;
    self.play_button.icon_y = 4;
    self.play_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.togglePlayback();
        }
    }.click;
    self.right_button.iconFn = icons.iconTimelineRight;
    self.right_button.icon_x = 4;
    self.right_button.icon_y = 4;
    self.right_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.gotoNextFrame();
        }
    }.click;
    self.end_button.iconFn = icons.iconTimelineEnd;
    self.end_button.icon_x = 4;
    self.end_button.icon_y = 4;
    self.end_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.gotoLastFrame();
        }
    }.click;

    self.add_frame_button.iconFn = icons.iconAddFrame;
    self.add_frame_button.icon_x = 3;
    self.add_frame_button.icon_y = 3;
    self.add_frame_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.newFrame();
        }
    }.click;
    self.delete_frame_button.iconFn = icons.iconDeleteFrameDisabled;
    self.delete_frame_button.icon_x = 3;
    self.delete_frame_button.icon_y = 3;
    self.delete_frame_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.deleteFrame(timeline.document.selected_frame) catch {}; // TODO: handle?
        }
    }.click;
    self.add_layer_button.iconFn = icons.iconAddLayer;
    self.add_layer_button.icon_x = 3;
    self.add_layer_button.icon_y = 3;
    self.add_layer_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.addLayer() catch {}; // TODO: handle?
            timeline.document.selectLayer(timeline.document.getLayerCount() - 1);
        }
    }.click;
    self.delete_layer_button.iconFn = icons.iconDeleteLayerDisabled;
    self.delete_layer_button.icon_x = 3;
    self.delete_layer_button.icon_y = 3;
    self.delete_layer_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.deleteLayer(timeline.document.selected_layer) catch {}; // TODO: handle?
        }
    }.click;

    self.visible_button.style = .toolbar;
    self.visible_button.onClickFn = onVisibleButtonClicked;
    self.lock_button.style = .toolbar;
    self.lock_button.onClickFn = onLockButtonClicked;
    self.link_button.style = .toolbar;
    self.link_button.onClickFn = onLinkButtonClicked;

    self.onion_skinning_button.widget.visible = false;
    self.onion_skinning_button.style = .toolbar;
    self.onion_skinning_button.iconFn = icons.iconOnionSkinning;
    self.onion_skinning_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            const timeline = @fieldParentPtr(Self, "widget", button.widget.parent.?);
            timeline.document.onion_skinning = !timeline.document.onion_skinning;
        }
    }.click;

    try self.widget.addChild(&self.begin_button.widget);
    try self.widget.addChild(&self.left_button.widget);
    try self.widget.addChild(&self.play_button.widget);
    try self.widget.addChild(&self.right_button.widget);
    try self.widget.addChild(&self.end_button.widget);
    try self.widget.addChild(&self.add_frame_button.widget);
    try self.widget.addChild(&self.delete_frame_button.widget);
    try self.widget.addChild(&self.add_layer_button.widget);
    try self.widget.addChild(&self.delete_layer_button.widget);
    try self.widget.addChild(&self.visible_button.widget);
    try self.widget.addChild(&self.lock_button.widget);
    try self.widget.addChild(&self.link_button.widget);
    try self.widget.addChild(&self.onion_skinning_button.widget);

    self.onDocumentChanged(); // Sync

    return self;
}

pub fn deinit(self: *Self) void {
    self.begin_button.deinit();
    self.left_button.deinit();
    self.play_button.deinit();
    self.right_button.deinit();
    self.end_button.deinit();
    self.add_frame_button.deinit();
    self.delete_frame_button.deinit();
    self.add_layer_button.deinit();
    self.delete_layer_button.deinit();
    self.visible_button.deinit();
    self.lock_button.deinit();
    self.link_button.deinit();
    self.onion_skinning_button.deinit();
    for (self.layer_widgets.items) |layer_widget| {
        layer_widget.deinit();
    }
    self.layer_widgets.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn onDocumentChanged(self: *Self) void {
    const layer_count = self.document.getLayerCount();
    self.delete_frame_button.widget.enabled = self.document.getFrameCount() > 1;
    self.delete_frame_button.iconFn = if (self.delete_frame_button.widget.enabled) icons.iconDeleteFrame else icons.iconDeleteFrameDisabled;
    self.delete_layer_button.widget.enabled = layer_count > 1;
    self.delete_layer_button.iconFn = if (self.delete_layer_button.widget.enabled) icons.iconDeleteLayer else icons.iconDeleteLayerDisabled;

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
            const rect = Rect(f32).make(5, 53 + @intToFloat(f32, i) * (tile_w - 1), 60, tile_w);
            const layer_widget = LayerWidget.init(self.allocator, rect, self.document, i) catch return; // TODO: handle?
            self.layer_widgets.append(layer_widget) catch return;
            self.widget.addChild(&layer_widget.widget) catch return;
        }
    }

    self.updateVisibleButtons();
    self.updateLockButtons();
    self.updateLinkButtons();
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = widget;
    _ = event;
    // const self = @fieldParentPtr(Self, "widget", widget);
    // const rect = widget.relative_rect;
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

pub fn newFrame(self: *Self) void {
    self.document.addFrame() catch {}; // TODO: handle?
    self.document.gotoLastFrame();
}

pub fn togglePlayback(self: *Self) void {
    // TODO: store playback state in document
    if (self.play_button.iconFn == &icons.iconTimelinePlay) {
        self.play_button.iconFn = icons.iconTimelinePause;
        self.document.play();
    } else {
        self.play_button.iconFn = icons.iconTimelinePlay;
        self.document.pause();
    }
}

fn selectFrameAndLayer(self: *Self, mouse_x: f32, mouse_y: f32) void {
    const x = 5 + name_w;
    const y = 5 + tile_w + 5;
    if (mouse_x >= x and mouse_y >= y) {
        const frame = @floatToInt(u32, (mouse_x - x) / (tile_w - 1));
        if (frame < self.document.frame_count) {
            self.document.gotoFrame(frame);
        }
        const layer = @floatToInt(u32, (mouse_y - y) / (tile_w - 1));
        if (layer > 0 and layer - 1 < self.document.getLayerCount()) {
            self.document.selectLayer(layer - 1);
        }
    }
}

fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    const rect = widget.relative_rect;

    gui.drawPanel(vg, rect.x, rect.y, rect.w, rect.h, 1, false, false);

    vg.beginPath();
    const x = rect.x + 5;
    const y = rect.y + 5 + tile_w + 5;
    vg.rect(x + 0.5, y + 0.5, rect.w - 1 - 10, rect.h - 1 - 15 - 21);
    vg.strokeColor(gui.theme_colors.border);
    vg.stroke();

    const layer_count = self.document.getLayerCount();
    const frame_count = self.document.getFrameCount();

    // draw selection
    const selected_layer = self.document.selected_layer;
    const selected_frame = self.document.selected_frame;
    vg.beginPath();
    vg.rect(x + 1, y + 1 + @intToFloat(f32, 1 + selected_layer) * (tile_w - 1), name_w + @intToFloat(f32, frame_count) * (tile_w - 1), (tile_w - 1));
    vg.rect(x + 1 + name_w + @intToFloat(f32, selected_frame) * (tile_w - 1), y + 1, (tile_w - 1), @intToFloat(f32, 1 + layer_count) * (tile_w - 1));
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();

    // draw grid
    vg.beginPath();
    var row: usize = 0;
    while (row <= layer_count) : (row += 1) {
        vg.moveTo(x + 1, y + @intToFloat(f32, 1 + row) * (tile_w - 1) + 0.5);
        vg.lineTo(x + name_w + @intToFloat(f32, frame_count) * (tile_w - 1) + 1, y + @intToFloat(f32, 1 + row) * (tile_w - 1) + 0.5);
    }
    var col: usize = 0;
    while (col < 3) : (col += 1) {
        vg.moveTo(x + @intToFloat(f32, 1 + col) * (tile_w - 1) + 0.5, y + 1);
        vg.lineTo(x + @intToFloat(f32, 1 + col) * (tile_w - 1) + 0.5, y + @intToFloat(f32, 1 + layer_count) * (tile_w - 1) + 0.5);
    }
    col = 0;
    while (col <= frame_count) : (col += 1) {
        vg.moveTo(x + name_w + @intToFloat(f32, col) * (tile_w - 1) + 0.5, y + 1);
        vg.lineTo(x + name_w + @intToFloat(f32, col) * (tile_w - 1) + 0.5, y + @intToFloat(f32, 1 + layer_count) * (tile_w - 1) + 0.5);
    }
    vg.strokeColor(gui.theme_colors.shadow);
    vg.stroke();

    // draw text
    var buf: [50]u8 = undefined;
    vg.fontFace("guifont");
    vg.fontSize(12);
    vg.textAlign(.{.vertical = .middle});
    vg.fillColor(nvg.rgb(0, 0, 0));
    var layer: usize = 1;
    while (layer <= layer_count) : (layer += 1) {
        const text = std.fmt.bufPrint(&buf, "Layer #{}", .{layer}) catch unreachable;
        _ = vg.text(x + 60 + 5, y + (@intToFloat(f32, layer) + 0.5) * (tile_w - 1) + 1, text);
    }
    vg.textAlign(.{.horizontal = .center, .vertical = .middle});
    var frame: usize = 0;
    while (frame < frame_count) : (frame += 1) {
        const text = std.fmt.bufPrint(&buf, "{}", .{frame + 1}) catch unreachable;
        _ = vg.text(x + name_w + (@intToFloat(f32, frame) + 0.5) * (tile_w - 1), y + 0.5 * (tile_w - 1) + 1, text);
    }

    // draw cel indicators
    row = 0;
    while (row < layer_count) : (row += 1) {
        col = 0;
        while (col < frame_count) : (col += 1) {
            if (self.document.layers.items[row].cels.items[col].bitmap == null) {
                vg.beginPath();
                vg.circle(x + name_w + (@intToFloat(f32, col)) * (tile_w - 1) + 11, y + (@intToFloat(f32, 1 + row)) * (tile_w - 1) + 11, 5.5);
                vg.strokeColor(nvg.rgb(66, 66, 66));
                vg.stroke();
            } else {
                vg.beginPath();
                vg.circle(x + name_w + (@intToFloat(f32, col)) * (tile_w - 1) + 11, y + (@intToFloat(f32, 1 + row)) * (tile_w - 1) + 11, 6);
                vg.fillColor(nvg.rgb(66, 66, 66));
                vg.fill();
            }
        }
    }

    widget.drawChildren(vg);
}
