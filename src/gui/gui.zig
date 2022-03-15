const std = @import("std");

const nvg = @import("nanovg");
pub const geometry = @import("geometry.zig");
const Rect = geometry.Rect;
const Point = geometry.Point;
usingnamespace @import("event.zig");
pub const Timer = @import("Timer.zig");
pub const Application = @import("Application.zig");
pub const Window = @import("Window.zig");
pub const Widget = @import("Widget.zig");
pub const Panel = @import("widgets/Panel.zig");
pub const Label = @import("widgets/Label.zig");
pub const Button = @import("widgets/Button.zig");
pub const RadioButton = @import("widgets/RadioButton.zig");
pub const TextBox = @import("widgets/TextBox.zig");
pub const Toolbar = @import("widgets/Toolbar.zig");
pub const Slider = @import("widgets/Slider.zig").Slider;
pub const Spinner = @import("widgets/Spinner.zig").Spinner;
pub const ListView = @import("widgets/ListView.zig");
pub const Scrollbar = @import("widgets/Scrollbar.zig");

const ThemeColors = struct {
    background: nvg.Color,
    shadow: nvg.Color,
    light: nvg.Color,
    border: nvg.Color,
    select: nvg.Color,
    focus: nvg.Color,
};

pub var theme_colors: ThemeColors = undefined;
pub var grid_image: nvg.Image = undefined;

fn defaultColorTheme() ThemeColors {
    return .{
        .background = nvg.rgb(224, 224, 224),
        .shadow = nvg.rgb(170, 170, 170),
        .light = nvg.rgb(255, 255, 255),
        .border = nvg.rgb(85, 85, 85),
        .select = nvg.rgba(0, 120, 247, 102),
        .focus = nvg.rgb(85, 160, 230),
    };
}

pub fn init() void {
    theme_colors = defaultColorTheme();

    grid_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF,
    });
}

pub fn deinit() void {
    nvg.deleteImage(grid_image);
}

pub fn pixelsToPoints(pixel_size: f32) f32 {
    return pixel_size * 96.0 / 72.0;
}

pub fn drawPanel(x: f32, y: f32, w: f32, h: f32, depth: f32, hovered: bool, pressed: bool) void {
    if (w <= 0 or h <= 0) return;

    var color_bg = theme_colors.background;
    var color_shadow = theme_colors.shadow;
    var color_light = theme_colors.light;

    if (pressed) {
        color_bg = nvg.rgb(204, 204, 204);
        color_shadow = theme_colors.background;
        color_light = theme_colors.shadow;
    } else if (hovered) {
        color_bg = nvg.rgb(240, 240, 240);
    }

    // background
    nvg.beginPath();
    nvg.rect(x, y, w, h);
    nvg.fillColor(color_bg);
    nvg.fill();

    // shadow
    nvg.beginPath();
    nvg.moveTo(x, y + h);
    nvg.lineTo(x + w, y + h);
    nvg.lineTo(x + w, y);
    nvg.lineTo(x + w - depth, y + depth);
    nvg.lineTo(x + w - depth, y + h - depth);
    nvg.lineTo(x + depth, y + h - depth);
    nvg.closePath();
    nvg.fillColor(color_shadow);
    nvg.fill();

    // light
    nvg.beginPath();
    nvg.moveTo(x + w, y);
    nvg.lineTo(x, y);
    nvg.lineTo(x, y + h);
    nvg.lineTo(x + depth, y + h - depth);
    nvg.lineTo(x + depth, y + depth);
    nvg.lineTo(x + w - depth, y + depth);
    nvg.closePath();
    nvg.fillColor(color_light);
    nvg.fill();
}

pub fn drawPanelInset(x: f32, y: f32, w: f32, h: f32, depth: f32) void {
    if (w <= 0 or h <= 0) return;

    var color_shadow = theme_colors.shadow;
    var color_light = theme_colors.light;

    // light
    nvg.beginPath();
    nvg.moveTo(x, y + h);
    nvg.lineTo(x + w, y + h);
    nvg.lineTo(x + w, y);
    nvg.lineTo(x + w - depth, y + depth);
    nvg.lineTo(x + w - depth, y + h - depth);
    nvg.lineTo(x + depth, y + h - depth);
    nvg.closePath();
    nvg.fillColor(color_light);
    nvg.fill();

    // shadow
    nvg.beginPath();
    nvg.moveTo(x + w, y);
    nvg.lineTo(x, y);
    nvg.lineTo(x, y + h);
    nvg.lineTo(x + depth, y + h - depth);
    nvg.lineTo(x + depth, y + depth);
    nvg.lineTo(x + w - depth, y + depth);
    nvg.closePath();
    nvg.fillColor(color_shadow);
    nvg.fill();
}

pub fn drawSmallArrowUp() void { // size: 6x6
    nvg.beginPath();
    nvg.moveTo(3, 1);
    nvg.lineTo(0, 4);
    nvg.lineTo(6, 4);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub fn drawSmallArrowDown() void { // size: 6x6
    nvg.beginPath();
    nvg.moveTo(3, 5);
    nvg.lineTo(0, 2);
    nvg.lineTo(6, 2);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub fn drawSmallArrowLeft() void {
    nvg.beginPath();
    nvg.moveTo(1, 3);
    nvg.lineTo(4, 0);
    nvg.lineTo(4, 6);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub fn drawSmallArrowRight() void {
    nvg.beginPath();
    nvg.moveTo(5, 3);
    nvg.lineTo(2, 0);
    nvg.lineTo(2, 6);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub const Orientation = enum(u1) {
    horizontal,
    vertical,
};

pub const TextAlignment = enum(u8) {
    left,
    center,
    right,
};
