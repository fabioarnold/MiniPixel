const std = @import("std");

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;
const Point = @import("../geometry.zig").Point;

const TextBox = @This();

widget: gui.Widget,
allocator: *std.mem.Allocator,
text: std.ArrayList(u8),
text_alignment: gui.TextAlignment = .left,
background_color: nvg.Color,

onChangedFn: ?fn (*Self) void = null,

hovered: bool = false,

cursor_position: usize = 0,
cursor_position_preview: usize = 0,
show_cursor_position_preview: bool = false,

selection_begin: usize = 0,
selection_end: usize = 0,

glyph_positions: std.ArrayList(nvg.GlyphPosition), // cache

base_key_down_fn: fn (*gui.Widget, *gui.KeyEvent) void,

blink: bool = false,
blink_timer: gui.Timer,

const Self = @This();

pub fn init(allocator: *std.mem.Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    const widget = gui.Widget.init(allocator, rect);
    self.* = Self{
        .widget = widget,
        .allocator = allocator,
        .text = std.ArrayList(u8).init(allocator),
        .glyph_positions = std.ArrayList(nvg.GlyphPosition).init(allocator),
        .background_color = gui.theme_colors.light,
        .base_key_down_fn = widget.onKeyDownFn,
        .blink_timer = gui.Timer{
            .on_elapsed_fn = onBlinkTimerElapsed,
            .ctx = @ptrToInt(self),
        },
    };

    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onTextInputFn = onTextInput;
    self.widget.onEnterFn = onEnter;
    self.widget.onLeaveFn = onLeave;
    self.widget.onFocusFn = onFocus;
    self.widget.onBlurFn = onBlur;
    self.widget.drawFn = draw;
    self.widget.focus_policy.keyboard = true;
    self.widget.focus_policy.mouse = true;
    return self;
}

pub fn deinit(self: *Self) void {
    self.text.deinit();
    self.glyph_positions.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onChanged(self: *Self) void {
    if (self.onChangedFn) |onChangedFn| onChangedFn(self);
}

fn getCursorPositionFromMousePosition(self: Self, mouse_position_x: f32) usize {
    const x = mouse_position_x + self.widget.relative_rect.x;
    for (self.glyph_positions.items) |glyph_position, i| {
        const glyph_center = 0.5 * (glyph_position.minx + glyph_position.maxx);
        if (x < glyph_center) {
            return i;
        }
    }
    return self.glyph_positions.items.len;
}

fn onMouseMove(widget: *gui.Widget, event: *gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    const mouse_position = Point(f32).make(event.x, event.y);

    const cursor_position = self.getCursorPositionFromMousePosition(mouse_position.x);

    if (event.isButtonPressed(.left)) {
        self.cursor_position = cursor_position;
        self.selection_end = cursor_position;
        self.blink = false;
        self.blink_timer.start(blink_interval);
    } else {
        self.cursor_position_preview = cursor_position;
        self.show_cursor_position_preview = true;
    }
}

fn onMouseDown(widget: *gui.Widget, event: *gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    const mouse_position = Point(f32).make(event.x, event.y);

    self.cursor_position = self.getCursorPositionFromMousePosition(mouse_position.x);
    self.selection_begin = self.cursor_position;
    self.selection_end = self.cursor_position;

    self.show_cursor_position_preview = false;
    self.blink = true;
    self.blink_timer.start(blink_interval);

    if (event.click_count == 2) {
        self.selectAll();
    }
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    _ = event;
    var self = @fieldParentPtr(Self, "widget", widget);

    if (self.hovered) {
        self.blink = true;
        self.blink_timer.start(blink_interval);
    }
}

fn onEnter(widget: *gui.Widget) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.hovered = true;
}

fn onLeave(widget: *gui.Widget) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.hovered = false;
    self.show_cursor_position_preview = false;
}

fn onFocus(widget: *gui.Widget, event: *gui.FocusEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.blink_timer.start(blink_interval);
    if (event.source == .keyboard) self.selectAll();
}

fn onBlur(widget: *gui.Widget, event: *gui.FocusEvent) void {
    _ = event;
    var self = @fieldParentPtr(Self, "widget", widget);
    self.blink_timer.stop();
}

fn onKeyDown(widget: *gui.Widget, event: *gui.KeyEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.base_key_down_fn(widget, event);
    if (event.event.is_accepted) return;
    event.event.accept();

    const text_len = std.unicode.utf8CountCodepoints(self.text.items) catch unreachable;
    self.cursor_position = std.math.min(self.cursor_position, text_len); // make sure cursor position is in a valid range

    self.show_cursor_position_preview = false;

    if (event.isModifierPressed(.ctrl)) {
        switch (event.key) {
            .A => self.selectAll(),
            .X => self.cut() catch {}, // TODO: handle error
            .C => self.copy() catch {}, // TODO: handle error
            .V => self.paste() catch {}, // TODO: handle error
            else => event.event.ignore(),
        }
    } else {
        switch (event.key) {
            .Backspace => {
                if (self.hasSelection()) {
                    self.deleteSelection();
                } else if (self.cursor_position > 0) {
                    self.cursor_position -= 1;
                    self.deleteCodepointAt(self.cursor_position);
                }
            },
            .Delete => {
                if (self.hasSelection()) {
                    self.deleteSelection();
                } else {
                    self.deleteCodepointAt(self.cursor_position);
                }
            },
            .Left => {
                if (event.isModifierPressed(.shift)) {
                    if (!self.hasSelection()) {
                        self.selection_begin = self.cursor_position;
                        self.selection_end = self.cursor_position;
                    }
                    if (self.selection_end > 0) self.selection_end -= 1;
                    self.cursor_position = self.selection_end;
                } else {
                    if (self.hasSelection()) {
                        self.cursor_position = std.math.min(self.selection_begin, self.selection_end);
                        self.clearSelection();
                    } else if (self.cursor_position > 0) self.cursor_position -= 1;
                }
            },
            .Right => {
                if (event.isModifierPressed(.shift)) {
                    if (!self.hasSelection()) {
                        self.selection_begin = self.cursor_position;
                        self.selection_end = self.cursor_position;
                    }
                    if (self.selection_end < text_len) self.selection_end += 1;
                    self.cursor_position = self.selection_end;
                } else {
                    if (self.hasSelection()) {
                        self.cursor_position = std.math.max(self.selection_begin, self.selection_end);
                        self.clearSelection();
                    } else if (self.cursor_position < text_len) self.cursor_position += 1;
                }
            },
            // .Escape => { // .Return,
            //     self.widget.setFocus(false, .keyboard);
            // },
            .Home => {
                self.clearSelection();
                self.cursor_position = 0;
            },
            .End => {
                self.clearSelection();
                self.cursor_position = text_len;
            },
            else => event.event.ignore(),
        }
    }

    self.blink = true;
    self.blink_timer.start(blink_interval);
}

fn onTextInput(widget: *gui.Widget, event: *const gui.TextInputEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    if (self.hasSelection()) {
        self.deleteSelection();
    }

    const offset = getCodepointOffset(self.text.items, self.cursor_position);
    self.text.insertSlice(offset, event.text) catch unreachable;
    self.cursor_position += 1;

    self.show_cursor_position_preview = false;

    self.onChanged();
}

fn cut(self: *Self) !void {
    if (self.widget.getApplication()) |app| {
        if (self.hasSelection()) {
            try app.setClipboardText(self.allocator, self.getSelection());
            self.deleteSelection();
        } else {
            try app.setClipboardText(self.allocator, self.text.items);
            self.text.clearRetainingCapacity();
            self.cursor_position = 0;
            self.clearSelection();
        }
        self.onChanged();
    }
}

fn copy(self: *Self) !void {
    if (self.widget.getApplication()) |app| {
        const text = if (self.hasSelection()) self.getSelection() else self.text.items;
        try app.setClipboardText(self.allocator, text);
    }
}

fn paste(self: *Self) !void {
    if (self.widget.getApplication()) |app| {
        const text = (try app.getClipboardText(self.allocator)) orelse return;
        defer self.allocator.free(text);

        const codepoint_count = try std.unicode.utf8CountCodepoints(text);

        if (self.hasSelection()) {
            self.deleteSelection();
        }
        const offset = getCodepointOffset(self.text.items, self.cursor_position);
        self.text.insertSlice(offset, text) catch unreachable;
        self.cursor_position += codepoint_count;

        self.show_cursor_position_preview = true;

        self.onChanged();
    }
}

fn getCodepointOffset(text: []const u8, position: usize) usize {
    var utf8 = std.unicode.Utf8View.initUnchecked(text).iterator();
    var i: usize = 0;
    while (i < position) {
        _ = utf8.nextCodepointSlice();
        i += 1;
    }

    return utf8.i;
}

fn deleteCodepointAt(self: *Self, position: usize) void {
    var utf8 = std.unicode.Utf8View.initUnchecked(self.text.items);
    var utf8_it = utf8.iterator();
    var i: usize = 0;
    while (i < position) {
        _ = utf8_it.nextCodepointSlice();
        i += 1;
    }
    const start = utf8_it.i;
    if (utf8_it.nextCodepointSlice()) |codepoint_slice| {
        const len = codepoint_slice.len;
        self.text.replaceRange(start, len, &.{}) catch unreachable;
    }

    self.onChanged();
}

fn deleteSelection(self: *Self) void {
    if (self.selection_begin > self.selection_end)
        std.mem.swap(usize, &self.selection_begin, &self.selection_end);

    var utf8 = std.unicode.Utf8View.initUnchecked(self.text.items).iterator();
    var i: usize = 0;
    while (i < self.selection_begin) {
        _ = utf8.nextCodepointSlice();
        i += 1;
    }
    const start_i = utf8.i;
    while (i < self.selection_end) {
        _ = utf8.nextCodepointSlice();
        i += 1;
    }
    const end_i = utf8.i;
    self.text.replaceRange(start_i, end_i - start_i, &.{}) catch unreachable;

    // update cursor
    if (self.cursor_position > self.selection_end) {
        self.cursor_position -= self.selection_end - self.selection_begin;
    } else if (self.cursor_position > self.selection_begin) {
        self.cursor_position = self.selection_begin;
    }
    self.selection_end = self.selection_begin;

    self.onChanged();
}

pub fn hasSelection(self: *Self) bool {
    return self.selection_begin != self.selection_end;
}

pub fn getSelection(self: *Self) []const u8 {
    if (self.selection_begin > self.selection_end)
        std.mem.swap(usize, &self.selection_begin, &self.selection_end);

    var utf8 = std.unicode.Utf8View.initUnchecked(self.text.items).iterator();
    var i: usize = 0;
    while (i < self.selection_begin) {
        _ = utf8.nextCodepointSlice();
        i += 1;
    }
    const start_i = utf8.i;
    while (i < self.selection_end) {
        _ = utf8.nextCodepointSlice();
        i += 1;
    }
    const end_i = utf8.i;

    return self.text.items[start_i..end_i];
}

pub fn clearSelection(self: *Self) void {
    self.selection_begin = 0;
    self.selection_end = 0;
}

pub fn selectAll(self: *Self) void {
    self.selection_begin = 0;
    self.selection_end = std.unicode.utf8CountCodepoints(self.text.items) catch unreachable;
    self.cursor_position = self.selection_end;
}

pub fn setText(self: *Self, text: []const u8) !void {
    const codepoint_count = try std.unicode.utf8CountCodepoints(text);
    try self.text.replaceRange(0, self.text.items.len, text);
    self.cursor_position = std.math.min(self.cursor_position, codepoint_count);
    self.cursor_position_preview = std.math.min(self.cursor_position_preview, codepoint_count);
    self.selection_begin = std.math.min(self.selection_begin, codepoint_count);
    self.selection_end = std.math.min(self.selection_end, codepoint_count);
}

pub fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    //drawPanelInset(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2, 1);

    const is_focused = widget.isFocused();

    // background
    nvg.beginPath();
    nvg.rect(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);
    nvg.fillColor(self.background_color);
    nvg.fill();

    // border
    nvg.beginPath();
    nvg.rect(rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1);
    nvg.strokeColor(if (is_focused) gui.theme_colors.focus else gui.theme_colors.border);
    nvg.stroke();

    nvg.scissor(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);

    nvg.fontFace("guifont");
    //nvg.fontSize(pixelsToPoints(9));
    nvg.fontSize(13);
    var text_align = nvg.TextAlign{.vertical = .middle};
    const padding = 5;
    var x = rect.x;
    switch (self.text_alignment) {
        .left => {
            text_align.horizontal = .left;
            x += padding;
        },
        .center => {
            text_align.horizontal = .center;
            x += 0.5 * rect.w;
        },
        .right => {
            text_align.horizontal = .right;
            x += rect.w - padding;
        },
    }
    nvg.textAlign(text_align);

    const codepoint_count = std.unicode.utf8CountCodepoints(self.text.items) catch unreachable;
    self.glyph_positions.resize(codepoint_count) catch unreachable;
    nvg.textGlyphPositions(x, rect.y, self.text.items, self.glyph_positions.items);
    var line_height: f32 = undefined;
    var ascender: f32 = undefined;
    var descender: f32 = undefined;
    nvg.textMetrics(&ascender, &descender, &line_height);
    const cursor_h = line_height + 4;
    if (is_focused) self.drawSelection(cursor_h);
    nvg.fillColor(nvg.rgb(0, 0, 0));
    const text_max_x = nvg.text(x, rect.y + 0.5 * rect.h, self.text.items);

    self.drawCursors(cursor_h, text_max_x);

    nvg.resetScissor();
}

fn drawSelection(self: *Self, h: f32) void {
    if (!self.hasSelection()) return;
    const rect = self.widget.relative_rect;

    const min = std.math.min(self.selection_begin, self.selection_end);
    const max = std.math.max(self.selection_begin, self.selection_end);
    const min_x = self.glyph_positions.items[min].minx;
    const max_x = self.glyph_positions.items[max - 1].maxx;

    nvg.beginPath();
    nvg.rect(min_x, rect.y + 0.5 * (rect.h - h), max_x - min_x, h);
    nvg.fillColor(gui.theme_colors.select);
    nvg.fill();
}

fn drawCursors(self: *Self, cursor_h: f32, text_max_x: f32) void {
    const rect = self.widget.relative_rect;

    if (self.show_cursor_position_preview) {
        // preview
        var cursor_x = text_max_x;
        if (self.cursor_position_preview < self.glyph_positions.items.len)
            cursor_x = self.glyph_positions.items[self.cursor_position_preview].x;
        nvg.beginPath();
        nvg.moveTo(cursor_x + 0.5, rect.y + 0.5 * (rect.h - cursor_h));
        nvg.lineTo(cursor_x + 0.5, rect.y + 0.5 * (rect.h + cursor_h));
        nvg.strokeColor(nvg.rgba(0, 0, 0, 0x50));
        nvg.stroke();
    }

    if (self.widget.isFocused() and self.blink) {
        var cursor_x = text_max_x;
        if (self.cursor_position < self.glyph_positions.items.len)
            cursor_x = self.glyph_positions.items[self.cursor_position].x;
        nvg.beginPath();
        nvg.moveTo(cursor_x + 0.5, rect.y + 0.5 * (rect.h - cursor_h));
        nvg.lineTo(cursor_x + 0.5, rect.y + 0.5 * (rect.h + cursor_h));
        nvg.strokeColor(nvg.rgb(0, 0, 0));
        nvg.stroke();
    }
}

fn onBlinkTimerElapsed(ctx: usize) void {
    const self = @intToPtr(*Self, ctx);
    self.blink = !self.blink;
}

const blink_interval = 500;
