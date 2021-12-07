const std = @import("std");

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

pub fn Spinner(comptime T: type) type {
    comptime if (T != i32 and T != f32) @compileError("Spinner needs to be i32 or f32");

    const StepMode = enum(u1) {
        linear,
        exponential,
    };

    return struct {
        widget: gui.Widget,
        allocator: *std.mem.Allocator,
        text_box: *gui.TextBox,
        up_button: *gui.Button,
        down_button: *gui.Button,

        value: T = 0,
        min_value: T = 0,
        max_value: T = 100,
        step_value: T = 1,
        step_mode: StepMode = .linear,

        baseTextBoxBlurFn: fn (*gui.Widget, *gui.FocusEvent) void,

        onChangedFn: ?fn (*Self) void = null,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator, rect: Rect(f32)) !*Self {
            var self = try allocator.create(Self);
            self.* = Self{
                .widget = gui.Widget.init(allocator, rect),
                .text_box = try gui.TextBox.init(allocator, Rect(f32).make(0, 0, 0, 0)),
                .baseTextBoxBlurFn = undefined,
                .up_button = try gui.Button.init(allocator, Rect(f32).make(0, 0, 0, 0), ""),
                .down_button = try gui.Button.init(allocator, Rect(f32).make(0, 0, 0, 0), ""),
                .allocator = allocator,
            };
            self.up_button.widget.focus_policy = gui.FocusPolicy.none();
            self.down_button.widget.focus_policy = gui.FocusPolicy.none();
            self.baseTextBoxBlurFn = self.text_box.widget.onBlurFn;
            self.widget.onResizeFn = onResize;
            self.widget.onKeyDownFn = onKeyDown;
            self.widget.onKeyUpFn = onKeyUp;

            try self.widget.addChild(&self.up_button.widget);
            try self.widget.addChild(&self.down_button.widget);
            try self.widget.addChild(&self.text_box.widget);

            self.text_box.onChangedFn = struct {
                fn changed(text_box: *gui.TextBox) void {
                    const error_color = nvg.rgbf(1, 0.82, 0.8);
                    if (text_box.widget.parent) |parent| {
                        const spinner = @fieldParentPtr(Spinner(T), "widget", parent);
                        if (text_box.text.items.len > 0) {
                            const text = text_box.text.items;
                            if (switch (T) {
                                i32 => std.fmt.parseInt(i32, text, 10),
                                f32 => std.fmt.parseFloat(f32, text),
                                else => unreachable,
                            }) |value| {
                                const old_value = spinner.value;
                                const in_range = value >= spinner.min_value and value <= spinner.max_value;
                                if (in_range) {
                                    spinner.value = std.math.clamp(value, spinner.min_value, spinner.max_value);
                                    if (spinner.value != old_value) spinner.notifyChanged();
                                    text_box.background_color = gui.theme_colors.light;
                                } else {
                                    text_box.background_color = error_color;
                                }
                            } else |_| { // error
                                text_box.background_color = error_color;
                            }
                        }
                    }
                }
            }.changed;
            self.text_box.widget.onBlurFn = struct {
                fn blur(widget: *gui.Widget, event: *gui.FocusEvent) void {
                    if (widget.parent) |parent| {
                        const spinner = @fieldParentPtr(Spinner(T), "widget", parent);
                        spinner.up_button.pressed = false;
                        spinner.down_button.pressed = false;
                        spinner.baseTextBoxBlurFn(widget, event);
                        spinner.updateTextBox();
                        spinner.text_box.background_color = gui.theme_colors.light;
                    }
                }
            }.blur;

            self.up_button.iconFn = gui.drawSmallArrowUp;
            self.up_button.onClickFn = struct {
                fn click(button: *gui.Button) void {
                    if (button.widget.parent) |parent| {
                        const spinner = @fieldParentPtr(Spinner(T), "widget", parent);
                        spinner.increment();
                        spinner.updateTextBox(); // ignore focus
                    }
                }
            }.click;
            self.up_button.auto_repeat_interval = 150;

            self.down_button.iconFn = gui.drawSmallArrowDown;
            self.down_button.onClickFn = struct {
                fn click(button: *gui.Button) void {
                    if (button.widget.parent) |parent| {
                        const spinner = @fieldParentPtr(Spinner(T), "widget", parent);
                        spinner.decrement();
                        spinner.updateTextBox(); // ignore focus
                    }
                }
            }.click;
            self.down_button.auto_repeat_interval = 150;

            self.updateTextBox();
            self.updateLayout();

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.text_box.deinit();
            self.up_button.deinit();
            self.down_button.deinit();
            self.widget.deinit();
            self.allocator.destroy(self);
        }

        fn onResize(widget: *gui.Widget, event: *gui.ResizeEvent) void {
            _ = event;
            const self = @fieldParentPtr(Self, "widget", widget);
            self.updateLayout();
        }

        fn onKeyDown(widget: *gui.Widget, event: *gui.KeyEvent) void {
            const self = @fieldParentPtr(Self, "widget", widget);
            switch (event.key) {
                .Up => {
                    self.up_button.pressed = true;
                    self.increment();
                    self.updateTextBox(); // ignore focus
                },
                .Down => {
                    self.down_button.pressed = true;
                    self.decrement();
                    self.updateTextBox(); // ignore focus
                },
                else => event.event.ignore(),
            }
        }

        fn onKeyUp(widget: *gui.Widget, event: *gui.KeyEvent) void {
            const self = @fieldParentPtr(Self, "widget", widget);
            switch (event.key) {
                .Up => self.up_button.pressed = false,
                .Down => self.down_button.pressed = false,
                else => event.event.ignore(),
            }
        }

        fn updateLayout(self: *Self) void {
            const button_width = 16;
            const rect = self.widget.relative_rect;
            self.up_button.widget.relative_rect.x = rect.w - button_width;
            self.down_button.widget.relative_rect.x = rect.w - button_width;
            self.down_button.widget.relative_rect.y = 0.5 * rect.h - 0.5;
            self.text_box.widget.setSize(rect.w + 1 - button_width, rect.h);
            self.up_button.widget.setSize(button_width, 0.5 * rect.h + 0.5);
            self.up_button.icon_x = std.math.floor((self.up_button.widget.relative_rect.w - 6) / 2);
            self.up_button.icon_y = std.math.floor((self.up_button.widget.relative_rect.h - 6) / 2);
            self.down_button.widget.setSize(button_width, 0.5 * rect.h + 0.5);
            self.down_button.icon_x = std.math.floor((self.down_button.widget.relative_rect.w - 6) / 2);
            self.down_button.icon_y = std.math.floor((self.down_button.widget.relative_rect.h - 6) / 2);
        }

        pub fn setFocus(self: *Self, focus: bool, source: gui.FocusSource) void {
            self.text_box.widget.setFocus(focus, source);
        }

        fn increment(self: *Self) void {
            const new_value = switch (self.step_mode) {
                .linear => self.value + self.step_value,
                .exponential => self.value * (1 + self.step_value),
            };
            self.setValue(new_value);
        }

        pub fn decrement(self: *Self) void {
            const new_value = switch (self.step_mode) {
                .linear => self.value - self.step_value,
                .exponential => if (T == i32) @divFloor(self.value, (1 + self.step_value)) else self.value / (1 + self.step_value),
            };
            self.setValue(new_value);
        }

        pub fn setValue(self: *Self, value: T) void {
            const old_value = self.value;
            self.value = std.math.clamp(value, self.min_value, self.max_value);
            if (self.value != old_value) {
                self.updateTextBox();
                self.text_box.background_color = gui.theme_colors.light;
                self.notifyChanged();
            }
        }

        fn updateTextBox(self: *Self) void {
            var buf: [50]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buf);
            switch (T) {
                i32 => std.fmt.formatInt(self.value, 10, .lower, .{}, fbs.writer()) catch unreachable,
                f32 => std.fmt.formatFloatDecimal(self.value, .{ .precision = 2 }, fbs.writer()) catch unreachable,
                else => unreachable,
            }
            if (std.mem.indexOfScalar(u8, buf[0..fbs.pos], '.')) |dec| { // trim zeroes
                while (buf[fbs.pos - 1] == '0') fbs.pos -= 1;
                if (fbs.pos - 1 == dec) fbs.pos -= 1;
            }
            self.text_box.setText(buf[0..fbs.pos]) catch {}; // TODO
        }

        fn notifyChanged(self: *Self) void {
            if (self.onChangedFn) |onChangedFn| onChangedFn(self);
        }
    };
}
