const std = @import("std");
const Allocator = std.mem.Allocator;

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

const ListView = @This();

widget: gui.Widget,
allocator: Allocator,

vertical_scrollbar: *gui.Scrollbar,
horizontal_scrollbar: *gui.Scrollbar,

model: Model,

const Self = @This();

const item_h: f32 = 20;

pub const Model = struct {
    ctx: usize,
    countFn: fn (ctx: usize) usize,
    getFn: fn (ctx: usize, i: usize) []const u8,
    isSelectedFn: fn (ctx: usize, i: usize) bool,
    selectFn: fn (ctx: usize, i: usize) void,
    swapFn: fn (ctx: usize, i: usize, j: usize) void,
    deleteFn: fn (ctx: usize, i: usize) void,
};

pub fn init(allocator: Allocator, rect: Rect(f32), model: Model) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .vertical_scrollbar = try gui.Scrollbar.init(allocator, rect, .vertical),
        .horizontal_scrollbar = try gui.Scrollbar.init(allocator, rect, .horizontal),
        .model = model,
    };
    self.widget.onResizeFn = onResize;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.drawFn = draw;

    try self.widget.addChild(&self.vertical_scrollbar.widget);
    try self.widget.addChild(&self.horizontal_scrollbar.widget);

    self.updateLayout();

    return self;
}

pub fn deinit(self: *Self) void {
    self.vertical_scrollbar.deinit();
    self.horizontal_scrollbar.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    self.updateLayout();
}

fn updateLayout(self: *Self) void {
    const button_size = 16;
    const rect = self.widget.relative_rect;
    self.vertical_scrollbar.widget.relative_rect.x = rect.w - button_size;
    self.vertical_scrollbar.widget.setSize(button_size, rect.h + 1 - button_size);
    self.horizontal_scrollbar.widget.relative_rect.y = rect.h - button_size;
    self.horizontal_scrollbar.widget.setSize(rect.w + 1 - button_size, button_size);

    const content_w = rect.w - button_size - 2;
    const content_h = rect.h - button_size - 2;
    self.horizontal_scrollbar.setMaxValue(512 - content_w - 1);
    self.vertical_scrollbar.setMaxValue(512 - content_h - 1);
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    _ = self;
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.button == .left) {
        const self = @fieldParentPtr(Self, "widget", widget);
        //const rect = widget.getRect();
        const i = @floatToInt(usize, event.y / item_h);
        self.model.selectFn(self.model.ctx, i);
    }
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    _ = self;
}

fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;

    // background
    nvg.beginPath();
    nvg.rect(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);
    nvg.fillColor(gui.theme_colors.light);
    nvg.fill();

    nvg.fontFace("guifont");
    nvg.fontSize(gui.pixelsToPoints(9));
    var text_align = @enumToInt(nvg.TextAlign.middle);
    var x = rect.x;
    text_align |= @enumToInt(nvg.TextAlign.left);
    x += 5;
    nvg.textAlign(@intToEnum(nvg.TextAlign, text_align));
    nvg.fillColor(nvg.rgb(0, 0, 0));
    const len = self.model.countFn(self.model.ctx);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const y = rect.y + 1 + @intToFloat(f32, i) * item_h;
        const is_selected = self.model.isSelectedFn(self.model.ctx, i);
        if (is_selected) {
            nvg.beginPath();
            nvg.rect(rect.x + 1, y, rect.w - 2, item_h);
            nvg.fillColor(nvg.rgb(90, 140, 240));
            nvg.fill();
            nvg.fillColor(gui.theme_colors.light);
        } else {
            nvg.fillColor(nvg.rgb(0, 0, 0));
        }
        const name = self.model.getFn(self.model.ctx, i);
        _ = nvg.text(x, y + 0.5 * item_h, name);
    }

    // border
    nvg.beginPath();
    nvg.rect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
    nvg.strokeColor(gui.theme_colors.border);
    nvg.stroke();

    // corner between scrollbars
    nvg.beginPath();
    nvg.rect(rect.x + rect.w - 15, rect.y + rect.h - 15, 14, 14);
    nvg.fillColor(gui.theme_colors.background);
    nvg.fill();

    widget.drawChildren();
}
