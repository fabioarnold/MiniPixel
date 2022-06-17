const std = @import("std");
const nextFrame = @import("main.zig").automatedTestLoopIteration;
const gui = @import("gui");
const EditorWidget = @import("EditorWidget.zig");

pub fn runTests(window: *gui.Window) !void {
    var editor_widget = @fieldParentPtr(EditorWidget, "widget", window.main_widget.?);
    try testFloodFill(window, editor_widget);
    try testSetIndividualPixels(window, editor_widget);
}

fn testFloodFill(window: *gui.Window, editor_widget: *EditorWidget) !void {
    try setupDocumentAndCanvas(editor_widget);
    const canvas_rect = editor_widget.canvas.widget.relative_rect;

    editor_widget.canvas.setTool(.fill);
    defer editor_widget.canvas.setTool(.draw);

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        mouseLeftDown(window, canvas_rect.x, canvas_rect.y);
        mouseLeftUp(window, canvas_rect.x, canvas_rect.y);
        editor_widget.color_foreground_background.swap();
        nextFrame();
    }
}

fn testSetIndividualPixels(window: *gui.Window, editor_widget: *EditorWidget) !void {
    try setupDocumentAndCanvas(editor_widget);
    const canvas_rect = editor_widget.canvas.widget.relative_rect;

    var y: f32 = 0;
    while (y < 10) : (y += 1) {
        var x: f32 = 0;
        while (x < 10) : (x += 1) {
            const mx = canvas_rect.x + x;
            const my = canvas_rect.y + y;
            mouseLeftDown(window, mx, my);
            mouseLeftUp(window, mx, my);
            nextFrame();
        }
    }
}

fn setupDocumentAndCanvas(editor_widget: *EditorWidget) !void {
    try editor_widget.createNewDocument(1024, 1024, .color);
    editor_widget.canvas.scale = 1;
    editor_widget.canvas.translation.x = 0;
    editor_widget.canvas.translation.y = 0;
}

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
