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
const LayerListWidget = @import("LayerListWidget.zig");

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

onion_skinning_button: *gui.Button,

layer_list_widget: *LayerListWidget,

drag_y: ?f32 = null,

const Self = @This();

const padding: f32 = 5;
const button_size: f32 = 22;
const header_h: f32 = 5 + button_size - 1 + 5;

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);

    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .begin_button = try gui.Button.init(allocator, Rect(f32).make(5 + 0 * (button_size - 1), 5, button_size, button_size), ""),
        .left_button = try gui.Button.init(allocator, Rect(f32).make(5 + 1 * (button_size - 1), 5, button_size, button_size), ""),
        .play_button = try gui.Button.init(allocator, Rect(f32).make(5 + 2 * (button_size - 1), 5, button_size, button_size), ""),
        .right_button = try gui.Button.init(allocator, Rect(f32).make(5 + 3 * (button_size - 1), 5, button_size, button_size), ""),
        .end_button = try gui.Button.init(allocator, Rect(f32).make(5 + 4 * (button_size - 1), 5, button_size, button_size), ""),
        .add_frame_button = try gui.Button.init(allocator, Rect(f32).make(15 + 5 * (button_size - 1), 5, button_size, button_size), ""),
        .delete_frame_button = try gui.Button.init(allocator, Rect(f32).make(15 + 6 * (button_size - 1), 5, button_size, button_size), ""),
        .add_layer_button = try gui.Button.init(allocator, Rect(f32).make(25 + 7 * (button_size - 1), 5, button_size, button_size), ""),
        .delete_layer_button = try gui.Button.init(allocator, Rect(f32).make(25 + 8 * (button_size - 1), 5, button_size, button_size), ""),
        .onion_skinning_button = try gui.Button.init(allocator, Rect(f32).make(5 + 64, 5 + button_size + 5, 20, 20), ""),
        .layer_list_widget = try LayerListWidget.init(allocator, Rect(f32).make(padding, header_h, rect.w - 2 * padding, rect.h - header_h - padding), document),
    };
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onResizeFn = onResize;
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
    try self.widget.addChild(&self.onion_skinning_button.widget);
    try self.widget.addChild(&self.layer_list_widget.widget);

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
    self.onion_skinning_button.deinit();
    self.layer_list_widget.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn onDocumentChanged(self: *Self) void {
    const layer_count = self.document.getLayerCount();
    self.delete_frame_button.widget.enabled = self.document.getFrameCount() > 1;
    self.delete_frame_button.iconFn = if (self.delete_frame_button.widget.enabled) icons.iconDeleteFrame else icons.iconDeleteFrameDisabled;
    self.delete_layer_button.widget.enabled = layer_count > 1;
    self.delete_layer_button.iconFn = if (self.delete_layer_button.widget.enabled) icons.iconDeleteLayer else icons.iconDeleteLayerDisabled;
    self.layer_list_widget.onDocumentChanged();
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    if (event.button == .left and event.y < header_h) {
        self.drag_y = event.y;
    }
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    if (event.button == .left) {
        self.drag_y = null;
    }
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    if (event.isButtonPressed(.left)) {
        if (self.drag_y) |drag_y| {
            const min_y = 16 + 24;
            const min_h = header_h;
            const rect = widget.relative_rect;
            const delta_y = event.y - drag_y;
            if (delta_y < 0) {
                const new_y = rect.y + delta_y;
                if (new_y < min_y) {
                    if (rect.y > min_y) {
                        const new_delta_y = min_y - rect.y;
                        widget.setSize(rect.w, rect.h - new_delta_y);
                    }
                } else {
                    widget.setSize(rect.w, rect.h - delta_y);
                }
            } else if (delta_y > 0) {
                const new_h = rect.h - delta_y;
                if (new_h < min_h) {
                    if (rect.h > min_h) {
                        widget.setSize(rect.w, min_h);
                    }
                } else {
                    widget.setSize(rect.w, new_h);
                }
            }
        }
    } else {
        self.drag_y = null;
    }
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    self.layer_list_widget.widget.setSize(event.new_width - 2 * padding, event.new_height - header_h - padding);
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

fn draw(widget: *gui.Widget, vg: nvg) void {
    const rect = widget.relative_rect;
    vg.save();
    vg.scissor(rect.x, rect.y, rect.w, rect.h);
    defer vg.restore();

    gui.drawPanel(vg, rect.x, rect.y, rect.w, rect.h, 1, false, false);

    widget.drawChildren(vg);
}
