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

const TimelineWidget = @This();

const LayerWidget = struct {
    widget: gui.Widget,
    allocator: Allocator,

    document: *Document, // just a reference

    visible_button: *gui.Button,

    fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*LayerWidget {
        var self = try allocator.create(LayerWidget);

        self.* = LayerWidget{
            .widget = gui.Widget.init(allocator, rect),
            .allocator = allocator,
            .document = document,
            .visible_button = try gui.Button.init(allocator, Rect(f32).make(1, 1, 20, 20), ""),
        };

        self.visible_button.style = .toolbar;
        self.visible_button.iconFn = icons.iconEyeOpen;
        self.visible_button.onClickFn = struct {
            fn click(button: *gui.Button) void {
                const layer_widget = @fieldParentPtr(LayerWidget, "widget", button.widget.parent.?);
                if (layer_widget.visible_button.iconFn == &icons.iconEyeOpen) {
                    layer_widget.visible_button.iconFn = icons.iconEyeClosed;
                    layer_widget.visible_button.checked = true;
                    // layer_widget.document.setLayerVisible(0, false);
                } else {
                    layer_widget.visible_button.iconFn = icons.iconEyeOpen;
                    layer_widget.visible_button.checked = false;
                    // layer_widget.document.setLayerVisible(0, true);
                }
            }
        }.click;

        try self.widget.addChild(&self.visible_button.widget);

        return self;
    }

    fn deinit(self: *LayerWidget) void {
        self.visible_button.deinit();

        self.widget.deinit();
        self.allocator.destroy(self);
    }
};

widget: gui.Widget,
allocator: Allocator,

document: *Document, // just a reference

begin_button: *gui.Button,
left_button: *gui.Button,
play_button: *gui.Button,
right_button: *gui.Button,
end_button: *gui.Button,
onion_skinning_button: *gui.Button,

layer_widgets: ArrayList(*LayerWidget),

const Self = @This();

const name_w: f32 = 160; // col for layer names
const tile_w: f32 = 20;

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);

    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .document = document,
        .begin_button = try gui.Button.init(allocator, Rect(f32).make(5, 5, 21, 21), ""),
        .left_button = try gui.Button.init(allocator, Rect(f32).make(25, 5, 21, 21), ""),
        .play_button = try gui.Button.init(allocator, Rect(f32).make(45, 5, 21, 21), ""),
        .right_button = try gui.Button.init(allocator, Rect(f32).make(65, 5, 21, 21), ""),
        .end_button = try gui.Button.init(allocator, Rect(f32).make(85, 5, 21, 21), ""),
        .onion_skinning_button = try gui.Button.init(allocator, Rect(f32).make(5 + 60, 5 + 21 + 5, 21, 21), ""),
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
            if (timeline.play_button.iconFn == &icons.iconTimelinePlay) {
                timeline.play_button.iconFn = icons.iconTimelinePause;
                timeline.document.play();
            } else {
                timeline.play_button.iconFn = icons.iconTimelinePlay;
                timeline.document.pause();
            }
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
    try self.widget.addChild(&self.onion_skinning_button.widget);

    var i: usize = 0;
    while (i < document.layer_count) : (i += 1) {
        try self.layer_widgets.append(try LayerWidget.init(allocator, Rect(f32).make(5, 51 + @intToFloat(f32, i) * tile_w, 60, tile_w), document));
    }

    for (self.layer_widgets.items) |layer_widget| {
        try self.widget.addChild(&layer_widget.widget);
    }

    return self;
}

pub fn deinit(self: *Self) void {
    self.begin_button.deinit();
    self.left_button.deinit();
    self.play_button.deinit();
    self.right_button.deinit();
    self.end_button.deinit();
    self.onion_skinning_button.deinit();
    for (self.layer_widgets.items) |layer_widget| {
        layer_widget.deinit();
    }
    self.layer_widgets.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    // TODO
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

fn selectFrameAndLayer(self: *Self, mouse_x: f32, mouse_y: f32) void {
    const x = 5 + name_w;
    const y = 5 + 21 + 5;
    if (mouse_x >= x and mouse_y >= y) {
        const frame = @floatToInt(u32, (mouse_x - x) / tile_w);
        if (frame < self.document.frame_count) {
            self.document.gotoFrame(frame);
        }
        const layer = @floatToInt(u32, (mouse_y - y) / tile_w);
        if (layer > 0 and layer - 1 < self.document.layer_count) {
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
    const y = rect.y + 5 + 21 + 5;
    vg.rect(x + 0.5, y + 0.5, rect.w - 1 - 10, rect.h - 1 - 15 - 21);
    vg.strokeColor(gui.theme_colors.border);
    vg.stroke();

    const frame_count = self.document.frame_count;
    const layer_count = self.document.layer_count;

    // draw selection
    const selected_frame = self.document.selected_frame;
    const selected_layer = self.document.selected_layer;
    vg.beginPath();
    vg.rect(x + 1, y + 1 + @intToFloat(f32, 1 + selected_layer) * tile_w, name_w + @intToFloat(f32, frame_count) * tile_w, tile_w);
    vg.rect(x + 1 + name_w + @intToFloat(f32, selected_frame) * tile_w, y + 1, tile_w, @intToFloat(f32, 1 + layer_count) * tile_w);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();

    // draw grid
    vg.beginPath();
    var row: usize = 0;
    while (row <= layer_count) : (row += 1) {
        vg.moveTo(x + 1, y + @intToFloat(f32, 1 + row) * tile_w + 0.5);
        vg.lineTo(x + name_w + @intToFloat(f32, frame_count) * tile_w + 1, y + @intToFloat(f32, 1 + row) * tile_w + 0.5);
    }
    var col: usize = 0;
    while (col < 3) : (col += 1) {
        vg.moveTo(x + @intToFloat(f32, 1 + col) * tile_w + 0.5, y + 1);
        vg.lineTo(x + @intToFloat(f32, 1 + col) * tile_w + 0.5, y + @intToFloat(f32, 1 + layer_count) * tile_w + 0.5);
    }
    col = 0;
    while (col <= frame_count) : (col += 1) {
        vg.moveTo(x + name_w + @intToFloat(f32, col) * tile_w + 0.5, y + 1);
        vg.lineTo(x + name_w + @intToFloat(f32, col) * tile_w + 0.5, y + @intToFloat(f32, 1 + layer_count) * tile_w + 0.5);
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
        _ = vg.text(x + 60 + 5, y + (@intToFloat(f32, layer) + 0.5) * tile_w + 1, text);
    }
    vg.textAlign(.{.horizontal = .center, .vertical = .middle});
    var frame: usize = 0;
    while (frame < frame_count) : (frame += 1) {
        const text = std.fmt.bufPrint(&buf, "{}", .{frame + 1}) catch unreachable;
        _ = vg.text(x + name_w + (@intToFloat(f32, frame) + 0.5) * tile_w, y + 0.5 * tile_w + 1, text);
    }

    widget.drawChildren(vg);
}
