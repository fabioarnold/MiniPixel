const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Rect = @import("gui/geometry.zig").Rect;

const ColorPickerWidget = @This();

widget: gui.Widget,
allocator: Allocator,
spinners: [4]*gui.Spinner(i32) = undefined,
sliders: [5]*gui.Slider(f32) = undefined,

color: [4]u8 = [_]u8{ 0, 0, 0, 0xff },

onChangedFn: ?fn (*ColorPickerWidget) void = null,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
    };
    self.widget.drawFn = draw;

    const pad = 5;
    inline for ([_]u2{ 0, 1, 2, 3 }) |i| {
        const y = @intToFloat(f32, i) * 28;
        self.sliders[i] = try gui.Slider(f32).init(allocator, Rect(f32).make(pad, y + pad, rect.w - 50 - 2 * pad, 23));
        self.sliders[i].max_value = 1;
        self.sliders[i].onChangedFn = SliderChangedFn(i).changed;
        self.sliders[i].widget.drawFn = SliderDrawFn(i).draw;
        try self.widget.addChild(&self.sliders[i].widget);

        self.spinners[i] = try gui.Spinner(i32).init(allocator, Rect(f32).make(rect.w - 50, y + pad, 45, 23));
        self.spinners[i].max_value = 255;
        self.spinners[i].onChangedFn = SpinnerChangedFn(i).changed;
        try self.widget.addChild(&self.spinners[i].widget);
    }

    self.setRgba(&self.color); // update the spinner values

    return self;
}

pub fn deinit(self: *Self) void {
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        self.sliders[i].deinit();
        self.spinners[i].deinit();
    }
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn setRgba(self: *Self, color: []const u8) void {
    std.debug.assert(color.len == 4);
    for (color) |c, i| {
        self.color[i] = c;
        self.sliders[i].setValue(@intToFloat(f32, c) / 255.0);
        self.spinners[i].setValue(color[i]);
    }
}

pub fn setRgb(self: *Self, color: []const u8) void {
    std.debug.assert(color.len == 3);
    for (color) |c, i| {
        self.color[i] = c;
        self.sliders[i].setValue(@intToFloat(f32, c) / 255.0);
        self.spinners[i].setValue(color[i]);
    }
}

fn SliderChangedFn(comptime color_index: comptime_int) type {
    return struct {
        fn changed(slider: *gui.Slider(f32)) void {
            if (slider.widget.parent) |parent| {
                var picker = @fieldParentPtr(Self, "widget", parent);
                const value = @floatToInt(u8, slider.value * 255.0);
                if (picker.color[color_index] != value) {
                    picker.color[color_index] = value;
                    picker.spinners[color_index].setValue(value);
                    if (picker.onChangedFn) |onChanged| onChanged(picker);
                }
            }
        }
    };
}

fn SpinnerChangedFn(comptime color_index: comptime_int) type {
    return struct {
        fn changed(spinner: *gui.Spinner(i32)) void {
            if (spinner.widget.parent) |parent| {
                var picker = @fieldParentPtr(Self, "widget", parent);
                if (picker.color[color_index] != spinner.value) {
                    picker.color[color_index] = @intCast(u8, spinner.value);
                    picker.sliders[color_index].setValue(@intToFloat(f32, spinner.value) / 255.0);
                    if (picker.onChangedFn) |onChanged| onChanged(picker);
                }
            }
        }
    };
}

fn SliderDrawFn(comptime color_index: u2) type {
    return struct {
        fn draw(widget: *gui.Widget) void {
            if (widget.parent) |parent| {
                const picker = @fieldParentPtr(Self, "widget", parent);

                const rect = widget.relative_rect;

                const icol = switch (color_index) {
                    0 => nvg.rgb(0, picker.color[1], picker.color[2]),
                    1 => nvg.rgb(picker.color[0], 0, picker.color[2]),
                    2 => nvg.rgb(picker.color[0], picker.color[1], 0),
                    3 => nvg.rgb(0, 0, 0),
                };

                const ocol = switch (color_index) {
                    0 => nvg.rgb(0xff, picker.color[1], picker.color[2]),
                    1 => nvg.rgb(picker.color[0], 0xff, picker.color[2]),
                    2 => nvg.rgb(picker.color[0], picker.color[1], 0xff),
                    3 => nvg.rgb(0xff, 0xff, 0xff),
                };

                nvg.beginPath();
                nvg.rect(rect.x, rect.y + 4, rect.w, rect.h - 4);
                const gradient = nvg.linearGradient(rect.x, 0, rect.x + rect.w, 0, icol, ocol);
                nvg.fillPaint(gradient);
                nvg.fill();
                const x = @intToFloat(f32, picker.color[color_index]) / 255.0;
                drawColorPickerIndicator(rect.x + x * rect.w, rect.y + 4);
            }
        }
    };
}

fn drawColorPickerIndicator(x: f32, y: f32) void {
    nvg.beginPath();
    nvg.moveTo(x, y);
    nvg.lineTo(x + 4, y - 4);
    nvg.lineTo(x - 4, y - 4);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub fn draw(widget: *gui.Widget) void {
    const rect = widget.relative_rect;
    gui.drawPanel(rect.x, rect.y, rect.w, rect.h, 1, false, false);

    widget.drawChildren();
}
