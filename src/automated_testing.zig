const std = @import("std");
const nextFrame = @import("main.zig").automatedTestLoopIteration;
const gui = @import("gui");
const EditorWidget = @import("EditorWidget.zig");

fn mouseLeftDown(window: *gui.Window, x: f32, y: f32) void {
    var me = gui.MouseEvent{
        .event = .{ .type = .MouseDown },
        .button = .left,
        .click_count = 0,
        .state = 1,
        .modifiers = 0,
        .x = x,
        .y = y,
        .wheel_x = 0,
        .wheel_y = 0,
    };
    window.handleEvent(&me.event);
}

fn mouseLeftUp(window: *gui.Window, x: f32, y: f32) void {
    var me = gui.MouseEvent{
        .event = .{ .type = .MouseUp },
        .button = .left,
        .click_count = 0,
        .state = 1,
        .modifiers = 0,
        .x = x,
        .y = y,
        .wheel_x = 0,
        .wheel_y = 0,
    };
    window.handleEvent(&me.event);
}

pub fn runTests(window: *gui.Window) !void {
    var editor_widget = @fieldParentPtr(EditorWidget, "widget", window.main_widget.?);
    try testCanSetIndividualPixels(window, editor_widget);
}

fn testCanSetIndividualPixels(window: *gui.Window, editor_widget: *EditorWidget) !void {
    // Setup
    try editor_widget.createNewDocument(1024, 1024, .color);
    editor_widget.canvas.scale = 1;
    editor_widget.canvas.translation.x = 0;
    editor_widget.canvas.translation.y = 0;
    const canvas_rect =  editor_widget.canvas.widget.relative_rect;

    var y: f32 = 0;
    while (y < 16) : (y += 1) {
        var x: f32 = 0;
        while (x < 16) : (x += 1) {
            const mx = canvas_rect.x + x;
            const my = canvas_rect.y + y;
            mouseLeftDown(window, mx, my);
            mouseLeftUp(window, mx, my);
            nextFrame();
        }
    }
}
