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

pub fn init(vg: nvg) void {
    theme_colors = defaultColorTheme();

    grid_image = vg.createImageRGBA(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF,
    });
}

pub fn deinit(vg: nvg) void {
    vg.deleteImage(grid_image);
}

pub fn pixelsToPoints(pixel_size: f32) f32 {
    return pixel_size * 96.0 / 72.0;
}

pub fn drawPanel(vg: nvg, x: f32, y: f32, w: f32, h: f32, depth: f32, hovered: bool, pressed: bool) void {
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
    vg.beginPath();
    vg.rect(x, y, w, h);
    vg.fillColor(color_bg);
    vg.fill();

    // shadow
    vg.beginPath();
    vg.moveTo(x, y + h);
    vg.lineTo(x + w, y + h);
    vg.lineTo(x + w, y);
    vg.lineTo(x + w - depth, y + depth);
    vg.lineTo(x + w - depth, y + h - depth);
    vg.lineTo(x + depth, y + h - depth);
    vg.closePath();
    vg.fillColor(color_shadow);
    vg.fill();

    // light
    vg.beginPath();
    vg.moveTo(x + w, y);
    vg.lineTo(x, y);
    vg.lineTo(x, y + h);
    vg.lineTo(x + depth, y + h - depth);
    vg.lineTo(x + depth, y + depth);
    vg.lineTo(x + w - depth, y + depth);
    vg.closePath();
    vg.fillColor(color_light);
    vg.fill();
}

pub fn drawPanelInset(vg: nvg, x: f32, y: f32, w: f32, h: f32, depth: f32) void {
    if (w <= 0 or h <= 0) return;

    var color_shadow = theme_colors.shadow;
    var color_light = theme_colors.light;

    // light
    vg.beginPath();
    vg.moveTo(x, y + h);
    vg.lineTo(x + w, y + h);
    vg.lineTo(x + w, y);
    vg.lineTo(x + w - depth, y + depth);
    vg.lineTo(x + w - depth, y + h - depth);
    vg.lineTo(x + depth, y + h - depth);
    vg.closePath();
    vg.fillColor(color_light);
    vg.fill();

    // shadow
    vg.beginPath();
    vg.moveTo(x + w, y);
    vg.lineTo(x, y);
    vg.lineTo(x, y + h);
    vg.lineTo(x + depth, y + h - depth);
    vg.lineTo(x + depth, y + depth);
    vg.lineTo(x + w - depth, y + depth);
    vg.closePath();
    vg.fillColor(color_shadow);
    vg.fill();
}

pub fn drawSmallArrowUp(vg: nvg) void { // size: 6x6
    vg.beginPath();
    vg.moveTo(3, 1);
    vg.lineTo(0, 4);
    vg.lineTo(6, 4);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
}

pub fn drawSmallArrowDown(vg: nvg) void { // size: 6x6
    vg.beginPath();
    vg.moveTo(3, 5);
    vg.lineTo(0, 2);
    vg.lineTo(6, 2);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
}

pub fn drawSmallArrowLeft(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(1, 3);
    vg.lineTo(4, 0);
    vg.lineTo(4, 6);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
}

pub fn drawSmallArrowRight(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(5, 3);
    vg.lineTo(2, 0);
    vg.lineTo(2, 6);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
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
