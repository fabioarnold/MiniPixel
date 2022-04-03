const std = @import("std");

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

const Label = @This();

widget: gui.Widget,
allocator: std.mem.Allocator,
text: []const u8,
text_alignment: gui.TextAlignment = .left,
padding: f32 = 0,
draw_border: bool = false,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, rect: Rect(f32), text: []const u8) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .text = text,
    };
    self.widget.drawFn = draw;
    return self;
}

pub fn deinit(self: *Self) void {
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;

    if (self.draw_border) {
        gui.drawPanelInset(vg, rect.x, rect.y, rect.w, rect.h, 1);
        vg.scissor(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);
    } else {
        vg.scissor(rect.x, rect.y, rect.w, rect.h);
    }
    defer vg.resetScissor();

    vg.fontFace("guifont");
    vg.fontSize(12);
    var text_align = nvg.TextAlign{ .vertical = .middle };
    var x = rect.x;
    var y = rect.y + 0.5 * rect.h;
    switch (self.text_alignment) {
        .left => {
            text_align.horizontal = .left;
            x += self.padding;
        },
        .center => {
            text_align.horizontal = .center;
            x += 0.5 * rect.w;
        },
        .right => {
            text_align.horizontal = .right;
            x += rect.w - self.padding;
        },
    }
    vg.fillColor(nvg.rgb(0, 0, 0));
    const has_newline = std.mem.indexOfScalar(u8, self.text, '\n') != null;
    if (rect.w == 0 or !has_newline) {
        vg.textAlign(text_align);
        _ = vg.text(x, rect.y + 0.5 * rect.h, self.text);
    } else {
        // NanoVG only vertically aligns the first line. So we have to do our own vertical centering.
        text_align.vertical = .top;
        vg.textAlign(text_align);
        vg.textLineHeight(14.0 / 12.0);
        var bounds: [4]f32 = undefined;
        vg.textBoxBounds(x, y, rect.w, self.text, &bounds);
        y -= 0.5 * (bounds[3] - bounds[1]);
        vg.textBox(x, y, rect.w, self.text);
    }
}
