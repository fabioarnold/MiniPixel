const std = @import("std");
const Allocator = std.mem.Allocator;

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;

pub fn Slider(comptime T: type) type {
    comptime std.debug.assert(T == f32);

    return struct {
        widget: gui.Widget,
        allocator: Allocator,

        value: T = 0,
        min_value: T = 0,
        max_value: T = 100,
        pressed: bool = false,

        onChangedFn: *const fn (*Self) void = onChanged,

        const Self = @This();

        pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
            var self = try allocator.create(Self);
            self.* = Self{
                .widget = gui.Widget.init(allocator, rect),
                .allocator = allocator,
            };
            self.widget.onMouseMoveFn = onMouseMove;
            self.widget.onMouseDownFn = onMouseDown;
            self.widget.onMouseUpFn = onMouseUp;
            self.widget.drawFn = draw;

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.widget.deinit();
            self.allocator.destroy(self);
        }

        fn onChanged(self: *Self) void { _ = self; }

        fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
            const self = @fieldParentPtr(Self, "widget", widget);

            if (self.pressed) {
                const rect = widget.getRect();
                const x = std.math.clamp(event.x, 0, rect.w - 1) / (rect.w - 1);
                self.value = self.min_value + x * (self.max_value - self.min_value);
                self.onChangedFn(self);
            }
        }

        fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
            if (event.button == .left) {
                const self = @fieldParentPtr(Self, "widget", widget);
                self.pressed = true;

                const rect = widget.getRect();
                const x = std.math.clamp(event.x, 0, rect.w - 1) / (rect.w - 1);
                self.value = self.min_value + x * (self.max_value - self.min_value);
                self.onChangedFn(self);
            }
        }

        fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
            if (event.button == .left) {
                const self = @fieldParentPtr(Self, "widget", widget);
                self.pressed = false;
            }
        }

        pub fn setValue(self: *Self, value: T) void {
            self.value = std.math.clamp(value, self.min_value, self.max_value);
        }

        fn draw(widget: *gui.Widget, vg: nvg) void {
            const self = @fieldParentPtr(Self, "widget", widget);

            const rect = widget.relative_rect;
            gui.drawPanelInset(vg, rect.x, rect.y + 0.5 * rect.h - 1, rect.w, 2, 1);

            const x = (self.value - self.min_value) / (self.max_value - self.min_value);
            drawIndicator(vg, rect.x + x * rect.w, rect.y + 0.5 * rect.h - 1);
        }
    };
}

fn drawIndicator(vg: nvg, x: f32, y: f32) void {
    vg.beginPath();
    vg.moveTo(x, y);
    vg.lineTo(x + 4, y - 4);
    vg.lineTo(x - 4, y - 4);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
}
