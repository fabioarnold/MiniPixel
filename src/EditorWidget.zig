const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nfd = @import("nfd");
const nvg = @import("nanovg");
const gui = @import("gui");
const icons = @import("icons.zig");
const geometry = @import("gui/geometry.zig");
const Point = geometry.Point;
const Rect = geometry.Rect;

const Clipboard = @import("Clipboard.zig");
const Document = @import("Document.zig");

const NewDocumentWidget = @import("NewDocumentWidget.zig");
const ErrorMessageWidget = @import("ErrorMessageWidget.zig");
const CanvasWidget = @import("CanvasWidget.zig");
const ColorPaletteWidget = @import("ColorPaletteWidget.zig");
const ColorPickerWidget = @import("ColorPickerWidget.zig");
const ColorForegroundBackgroundWidget = @import("ColorForegroundBackgroundWidget.zig");
const PreviewWidget = @import("PreviewWidget.zig");

pub const EditorWidget = @This();

widget: gui.Widget,
allocator: Allocator,

document: *Document,
document_file_path: ?[]const u8 = null,

menu_bar: *gui.Toolbar,
new_button: *gui.Button,
open_button: *gui.Button,
save_button: *gui.Button,
undo_button: *gui.Button,
redo_button: *gui.Button,
cut_button: *gui.Button,
copy_button: *gui.Button,
paste_button: *gui.Button,
crop_tool_button: *gui.Button,
select_tool_button: *gui.Button,
draw_tool_button: *gui.Button,
fill_tool_button: *gui.Button,
mirror_h_tool_button: *gui.Button,
mirror_v_tool_button: *gui.Button,
rotate_ccw_tool_button: *gui.Button,
rotate_cw_tool_button: *gui.Button,
grid_button: *gui.Button,
zoom_label: *gui.Label,
zoom_spinner: *gui.Spinner(f32),

status_bar: *gui.Toolbar,
help_status_label: *gui.Label,
tool_status_label: *gui.Label,
image_status_label: *gui.Label,
memory_status_label: *gui.Label,

// help_text: [200]u8 = .{0} ** 200,
tool_text: [100]u8 = .{0} ** 100,
image_text: [20]u8 = .{0} ** 20,
memory_text: [100]u8 = .{0} ** 100,

error_message_widget: *ErrorMessageWidget,
new_document_widget: *NewDocumentWidget,
canvas: *CanvasWidget,
color_palette: *ColorPaletteWidget,
color_picker: *ColorPickerWidget,
color_foreground_background: *ColorForegroundBackgroundWidget,
preview: *PreviewWidget,
panel_right: *gui.Panel,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,

        .document = try Document.init(allocator),

        .menu_bar = try gui.Toolbar.init(allocator, rect),
        .new_button = try gui.Button.init(allocator, rect, ""),
        .open_button = try gui.Button.init(allocator, rect, ""),
        .save_button = try gui.Button.init(allocator, rect, ""),
        .undo_button = try gui.Button.init(allocator, rect, ""),
        .redo_button = try gui.Button.init(allocator, rect, ""),
        .cut_button = try gui.Button.init(allocator, rect, ""),
        .copy_button = try gui.Button.init(allocator, rect, ""),
        .paste_button = try gui.Button.init(allocator, rect, ""),
        .crop_tool_button = try gui.Button.init(allocator, rect, ""),
        .select_tool_button = try gui.Button.init(allocator, rect, ""),
        .draw_tool_button = try gui.Button.init(allocator, rect, ""),
        .fill_tool_button = try gui.Button.init(allocator, rect, ""),
        .mirror_h_tool_button = try gui.Button.init(allocator, rect, ""),
        .mirror_v_tool_button = try gui.Button.init(allocator, rect, ""),
        .rotate_ccw_tool_button = try gui.Button.init(allocator, rect, ""),
        .rotate_cw_tool_button = try gui.Button.init(allocator, rect, ""),
        .grid_button = try gui.Button.init(allocator, rect, ""),
        .zoom_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 37, 20), "Zoom:"),
        .zoom_spinner = try gui.Spinner(f32).init(allocator, Rect(f32).make(0, 0, 53, 20)),

        .status_bar = try gui.Toolbar.init(allocator, rect),
        .help_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 450, 20), ""),
        .tool_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 120, 20), ""),
        .image_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 80, 20), ""),
        .memory_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 80, 20), ""),

        .error_message_widget = try ErrorMessageWidget.init(allocator, ""),
        .new_document_widget = try NewDocumentWidget.init(allocator, self),
        .canvas = try CanvasWidget.init(allocator, Rect(f32).make(0, 24, rect.w, rect.h), self.document),
        .color_palette = try ColorPaletteWidget.init(allocator, Rect(f32).make(0, 0, 163, 163)),
        .color_picker = try ColorPickerWidget.init(allocator, Rect(f32).make(0, 0, 163, 117)),
        .color_foreground_background = try ColorForegroundBackgroundWidget.init(allocator, Rect(f32).make(0, 0, 163, 66)),
        .preview = try PreviewWidget.init(allocator, Rect(f32).make(0, 0, 163, 120), self.document),
        .panel_right = try gui.Panel.init(allocator, Rect(f32).make(0, 0, 163, 200)),
    };
    self.widget.onResizeFn = onResize;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onClipboardUpdateFn = onClipboardUpdate;

    try self.initMenubar();

    self.help_status_label.padding = 3;
    self.help_status_label.draw_border = true;
    self.tool_status_label.padding = 3;
    self.tool_status_label.draw_border = true;
    self.image_status_label.padding = 3;
    self.image_status_label.draw_border = true;
    self.memory_status_label.padding = 3;
    self.memory_status_label.draw_border = true;

    self.status_bar.has_grip = true;

    // build status bar
    try self.status_bar.addWidget(&self.help_status_label.widget);
    try self.status_bar.addWidget(&self.tool_status_label.widget);
    try self.status_bar.addWidget(&self.image_status_label.widget);
    try self.status_bar.addWidget(&self.memory_status_label.widget);

    // add main widgets
    try self.widget.addChild(&self.menu_bar.widget);
    try self.widget.addChild(&self.canvas.widget);
    try self.widget.addChild(&self.color_palette.widget);
    try self.widget.addChild(&self.color_picker.widget);
    try self.widget.addChild(&self.color_foreground_background.widget);
    try self.widget.addChild(&self.preview.widget);
    try self.widget.addChild(&self.panel_right.widget);
    try self.widget.addChild(&self.status_bar.widget);

    try self.color_palette.loadPalContents(@embedFile("../data/palettes/arne16.pal"));
    self.color_palette.onSelectionChangedFn = struct {
        fn selectionChanged(color_palette: *ColorPaletteWidget) void {
            if (color_palette.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                if (color_palette.selected) |selected| {
                    const color = color_palette.colors[selected];
                    editor.color_picker.setRgb(color);
                    editor.color_foreground_background.setActiveRgba(editor.color_picker.color);
                    switch (editor.color_foreground_background.active) {
                        .foreground => editor.document.setForegroundColorRgba(editor.color_picker.color),
                        .background => editor.document.setBackgroundColorRgba(editor.color_picker.color),
                    }
                }
            }
        }
    }.selectionChanged;

    self.canvas.onColorChangedFn = struct {
        fn colorChanged(canvas: *CanvasWidget, color: [4]u8) void {
            if (canvas.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                editor.color_foreground_background.setRgba(.foreground, color);
            }
        }
    }.colorChanged;
    self.canvas.onScaleChangedFn = struct {
        fn zoomChanged(canvas: *CanvasWidget, zoom: f32) void {
            if (canvas.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                editor.zoom_spinner.setValue(zoom);
            }
        }
    }.zoomChanged;

    self.color_picker.onChangedFn = struct {
        fn changed(color_picker: *ColorPickerWidget) void {
            if (color_picker.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                if (editor.color_palette.selected) |selected| {
                    std.mem.copy(u8, editor.color_palette.colors[selected][0..], color_picker.color[0..3]);
                }
                editor.color_foreground_background.setActiveRgba(color_picker.color);
                switch (editor.color_foreground_background.active) {
                    .foreground => editor.document.setForegroundColorRgba(editor.color_picker.color),
                    .background => editor.document.setBackgroundColorRgba(editor.color_picker.color),
                }
            }
        }
    }.changed;

    self.color_foreground_background.onChangedFn = struct {
        fn changed(color_foreground_background: *ColorForegroundBackgroundWidget) void {
            if (color_foreground_background.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                const color = color_foreground_background.getActiveRgba();
                if (editor.color_palette.selected) |selected| {
                    const palette_color = editor.color_palette.colors[selected];
                    if (!std.mem.eql(u8, palette_color[0..], color[0..3])) {
                        editor.color_palette.clearSelection();
                    }
                }
                editor.color_picker.setRgba(color);
                switch (editor.color_foreground_background.active) {
                    .foreground => editor.document.setForegroundColorRgba(color),
                    .background => editor.document.setBackgroundColorRgba(color),
                }
            }
        }
    }.changed;

    self.document.history.editor = self; // Register for updates

    self.updateLayout();
    self.setTool(.draw);
    self.canvas.centerDocument();
    self.updateImageStatus();

    return self;
}

fn initMenubar(self: *Self) !void {
    self.new_button.iconFn = icons.iconNew;
    self.new_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).newDocument();
        }
    }.click;
    self.new_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("New Document (Ctrl+N)");
        }
    }.enter;
    self.new_button.onLeaveFn = menuButtonOnLeave;
    self.open_button.iconFn = icons.iconOpen;
    self.open_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).tryOpenDocument();
        }
    }.click;
    self.open_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Open Document (Ctrl+O)");
        }
    }.enter;
    self.open_button.onLeaveFn = menuButtonOnLeave;
    self.save_button.iconFn = icons.iconSave;
    self.save_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).trySaveDocument(false); // TODO: shif modifier
        }
    }.click;
    self.save_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Save Document (Ctrl+S), Save As (Ctrl+Shift+S)");
        }
    }.enter;
    self.save_button.onLeaveFn = menuButtonOnLeave;
    self.undo_button.iconFn = icons.iconUndoDisabled;
    self.undo_button.enabled = false;
    self.undo_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).tryUndoDocument();
        }
    }.click;
    self.undo_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Undo Action (Ctrl+Z)");
        }
    }.enter;
    self.undo_button.onLeaveFn = menuButtonOnLeave;
    self.redo_button.iconFn = icons.iconRedoDisabled;
    self.redo_button.enabled = false;
    self.redo_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).tryRedoDocument();
        }
    }.click;
    self.redo_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Redo Action (Ctrl+Y)");
        }
    }.enter;
    self.redo_button.onLeaveFn = menuButtonOnLeave;
    self.cut_button.iconFn = icons.iconCut;
    self.cut_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).cutDocument();
        }
    }.click;
    self.cut_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Cut Selection to clipboard (Ctrl+X)");
        }
    }.enter;
    self.cut_button.onLeaveFn = menuButtonOnLeave;
    self.copy_button.iconFn = icons.iconCopy;
    self.copy_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).copyDocument();
        }
    }.click;
    self.copy_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Copy Selection to Clipboard (Ctrl+C)");
        }
    }.enter;
    self.copy_button.onLeaveFn = menuButtonOnLeave;
    self.paste_button.iconFn = icons.iconPasteEnabled;
    self.checkClipboard(); // will set the correct icon
    self.paste_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).pasteDocument();
        }
    }.click;
    self.paste_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Paste from Clipboard (Ctrl+V)");
        }
    }.enter;
    self.paste_button.onLeaveFn = menuButtonOnLeave;
    self.crop_tool_button.iconFn = icons.iconToolCrop;
    self.crop_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).setTool(.crop);
        }
    }.click;
    self.crop_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Crop/Enlarge Tool (C)");
        }
    }.enter;
    self.crop_tool_button.onLeaveFn = menuButtonOnLeave;
    self.select_tool_button.iconFn = icons.iconToolSelect;
    self.select_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).setTool(.select);
        }
    }.click;
    self.select_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Rectangle Select Tool (R)");
        }
    }.enter;
    self.select_tool_button.onLeaveFn = menuButtonOnLeave;
    self.draw_tool_button.iconFn = icons.iconToolPen;
    self.draw_tool_button.checked = true;
    self.draw_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).setTool(.draw);
        }
    }.click;
    self.draw_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Pen Tool (N)");
        }
    }.enter;
    self.draw_tool_button.onLeaveFn = menuButtonOnLeave;
    self.fill_tool_button.iconFn = icons.iconToolBucket;
    self.fill_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).setTool(.fill);
        }
    }.click;
    self.fill_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Fill Tool (B)");
        }
    }.enter;
    self.fill_tool_button.onLeaveFn = menuButtonOnLeave;
    self.mirror_h_tool_button.iconFn = icons.iconMirrorHorizontally;
    self.mirror_h_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).mirrorHorizontallyDocument();
        }
    }.click;
    self.mirror_h_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Mirror Horizontally");
        }
    }.enter;
    self.mirror_h_tool_button.onLeaveFn = menuButtonOnLeave;
    self.mirror_v_tool_button.iconFn = icons.iconMirrorVertically;
    self.mirror_v_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).mirrorVerticallyDocument();
        }
    }.click;
    self.mirror_v_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Mirror Vertically");
        }
    }.enter;
    self.mirror_v_tool_button.onLeaveFn = menuButtonOnLeave;
    self.rotate_ccw_tool_button.iconFn = icons.iconRotateCcw;
    self.rotate_ccw_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).rotateCcwDocument();
        }
    }.click;
    self.rotate_ccw_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Rotate Counterclockwise");
        }
    }.enter;
    self.rotate_ccw_tool_button.onLeaveFn = menuButtonOnLeave;
    self.rotate_cw_tool_button.iconFn = icons.iconRotateCw;
    self.rotate_cw_tool_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).rotateCwDocument();
        }
    }.click;
    self.rotate_cw_tool_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Rotate Clockwise");
        }
    }.enter;
    self.rotate_cw_tool_button.onLeaveFn = menuButtonOnLeave;
    self.grid_button.iconFn = icons.iconGrid;
    self.grid_button.checked = self.canvas.grid_enabled;
    self.grid_button.onClickFn = struct {
        fn click(button: *gui.Button) void {
            getEditorFromMenuButton(button).toggleGrid();
        }
    }.click;
    self.grid_button.onEnterFn = struct {
        fn enter(button: *gui.Button) void {
            getEditorFromMenuButton(button).setHelpText("Toggle Pixel Grid (#)");
        }
    }.enter;
    self.grid_button.onLeaveFn = menuButtonOnLeave;
    self.zoom_spinner.setValue(self.canvas.scale);
    self.zoom_spinner.min_value = 1.0 / 64.0;
    self.zoom_spinner.max_value = 64;
    //self.zoom_spinner.step_value = 0.5;
    self.zoom_spinner.step_mode = .exponential;
    self.zoom_spinner.onChangedFn = struct {
        fn changed(spinner: *gui.Spinner(f32)) void {
            if (spinner.widget.parent) |menu_bar_widget| {
                if (menu_bar_widget.parent) |parent| {
                    var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                    const factor = spinner.value / editor.canvas.scale;
                    editor.canvas.zoomToDocumentCenter(factor);
                }
            }
        }
    }.changed;

    // build menu bar
    try self.menu_bar.addButton(self.new_button);
    try self.menu_bar.addButton(self.open_button);
    try self.menu_bar.addButton(self.save_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.undo_button);
    try self.menu_bar.addButton(self.redo_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.cut_button);
    try self.menu_bar.addButton(self.copy_button);
    try self.menu_bar.addButton(self.paste_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.crop_tool_button);
    try self.menu_bar.addButton(self.select_tool_button);
    try self.menu_bar.addButton(self.draw_tool_button);
    try self.menu_bar.addButton(self.fill_tool_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.mirror_h_tool_button);
    try self.menu_bar.addButton(self.mirror_v_tool_button);
    try self.menu_bar.addButton(self.rotate_ccw_tool_button);
    try self.menu_bar.addButton(self.rotate_cw_tool_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.grid_button);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addWidget(&self.zoom_label.widget);
    try self.menu_bar.addWidget(&self.zoom_spinner.widget);
}

pub fn deinit(self: *Self) void {
    self.document.deinit();
    if (self.document_file_path) |document_file_path| {
        self.allocator.free(document_file_path);
    }

    self.menu_bar.deinit();
    self.new_button.deinit();
    self.open_button.deinit();
    self.save_button.deinit();
    self.undo_button.deinit();
    self.redo_button.deinit();
    self.cut_button.deinit();
    self.copy_button.deinit();
    self.paste_button.deinit();
    self.crop_tool_button.deinit();
    self.select_tool_button.deinit();
    self.draw_tool_button.deinit();
    self.fill_tool_button.deinit();
    self.mirror_h_tool_button.deinit();
    self.mirror_v_tool_button.deinit();
    self.rotate_ccw_tool_button.deinit();
    self.rotate_cw_tool_button.deinit();
    self.grid_button.deinit();
    self.zoom_label.deinit();
    self.zoom_spinner.deinit();

    self.status_bar.deinit();
    self.help_status_label.deinit();
    self.tool_status_label.deinit();
    self.image_status_label.deinit();
    self.memory_status_label.deinit();

    self.error_message_widget.deinit();
    self.new_document_widget.deinit();
    self.canvas.deinit();
    self.color_palette.deinit();
    self.color_picker.deinit();
    self.color_foreground_background.deinit();
    self.preview.deinit();
    self.panel_right.deinit();

    self.widget.deinit();
    self.allocator.destroy(self);
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    self.updateLayout();
}

fn onKeyDown(widget: *gui.Widget, key_event: *gui.KeyEvent) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    const shift_held = key_event.isModifierPressed(.shift);
    if (key_event.isModifierPressed(.ctrl)) {
        switch (key_event.key) {
            .N => self.newDocument(),
            .O => self.tryOpenDocument(),
            .S => self.trySaveDocument(shift_held),
            .Z => self.tryUndoDocument(),
            .Y => self.tryRedoDocument(),
            .A => self.selectAll(),
            .X => self.cutDocument(),
            .C => self.copyDocument(),
            .V => self.pasteDocument(),
            .Comma => self.fillDocument(.foreground),
            .Period => self.fillDocument(.background),
            else => key_event.event.ignore(),
        }
    } else if (key_event.modifiers == 0) {
        switch (key_event.key) {
            .C => self.setTool(.crop), // Crop
            .R => self.setTool(.select), // Rectangle select
            .N => self.setTool(.draw), // peNcil
            .B => self.setTool(.fill), // Bucket
            .X => self.color_foreground_background.swap(),
            .Hash => self.toggleGrid(),
            else => key_event.event.ignore(),
        }
    } else {
        key_event.event.ignore();
    }
}

pub fn onUndoChanged(self: *Self, document: *Document) void {
    self.undo_button.enabled = document.canUndo();
    self.undo_button.iconFn = if (self.undo_button.enabled)
        icons.iconUndoEnabled
    else
        icons.iconUndoDisabled;
    self.redo_button.enabled = document.canRedo();
    self.redo_button.iconFn = if (self.redo_button.enabled)
        icons.iconRedoEnabled
    else
        icons.iconRedoDisabled;
    self.updateImageStatus();
}

fn onClipboardUpdate(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    self.checkClipboard();
}

fn checkClipboard(self: *Self) void {
    if (Clipboard.hasImage()) {
        self.paste_button.enabled = true;
        self.paste_button.iconFn = icons.iconPasteEnabled;
    } else {
        self.paste_button.enabled = false;
        self.paste_button.iconFn = icons.iconPasteDisabled;
    }
}

fn updateLayout(self: *Self) void {
    const rect = self.widget.relative_rect;
    const menu_bar_h = 24;
    const right_col_w = self.color_picker.widget.relative_rect.w;
    const canvas_w = rect.w - right_col_w;
    const canvas_h = rect.h - menu_bar_h - menu_bar_h;

    self.canvas.widget.relative_rect.x = 0;
    self.color_palette.widget.relative_rect.x = canvas_w;
    self.color_picker.widget.relative_rect.x = canvas_w;
    self.color_foreground_background.widget.relative_rect.x = canvas_w;
    self.preview.widget.relative_rect.x = canvas_w;
    self.panel_right.widget.relative_rect.x = canvas_w;

    self.canvas.widget.relative_rect.y = menu_bar_h;
    self.color_palette.widget.relative_rect.y = menu_bar_h;
    self.color_picker.widget.relative_rect.y = self.color_palette.widget.relative_rect.y + self.color_palette.widget.relative_rect.h;
    self.color_foreground_background.widget.relative_rect.y = self.color_picker.widget.relative_rect.y + self.color_picker.widget.relative_rect.h;
    self.preview.widget.relative_rect.y = self.color_foreground_background.widget.relative_rect.y + self.color_foreground_background.widget.relative_rect.h;
    self.panel_right.widget.relative_rect.y = self.preview.widget.relative_rect.y + self.preview.widget.relative_rect.h;
    self.status_bar.widget.relative_rect.y = rect.h - menu_bar_h;

    self.menu_bar.widget.setSize(rect.w, menu_bar_h);
    self.panel_right.widget.setSize(right_col_w, std.math.max(0, menu_bar_h + canvas_h - self.panel_right.widget.relative_rect.y));
    self.canvas.widget.setSize(canvas_w, canvas_h);
    self.status_bar.widget.setSize(rect.w, menu_bar_h);
}

pub fn showErrorMessageBox(self: *Self, title: [:0]const u8, message: []const u8) void {
    if (self.widget.getWindow()) |parent_window| {
        var window_or_error = parent_window.createChildWindow(
            title,
            self.error_message_widget.widget.relative_rect.w,
            self.error_message_widget.widget.relative_rect.h,
            gui.Window.CreateOptions{ .resizable = false },
        );
        if (window_or_error) |window| {
            window.is_modal = true;
            window.setMainWidget(&self.error_message_widget.widget);
            self.error_message_widget.message_label.text = message;
        } else |_| {}
    }
}

fn newDocument(self: *Self) void {
    if (self.widget.getWindow()) |parent_window| {
        var window_or_error = parent_window.createChildWindow(
            "New Document",
            self.new_document_widget.widget.relative_rect.w,
            self.new_document_widget.widget.relative_rect.h,
            gui.Window.CreateOptions{ .resizable = false },
        );
        if (window_or_error) |window| {
            window.is_modal = true;
            window.setMainWidget(&self.new_document_widget.widget);
            self.new_document_widget.width_spinner.setFocus(true, .keyboard); // keyboard will select text
        } else |_| {
            // TODO: show error
        }
    }
}

pub fn createNewDocument(self: *Self, width: u32, height: u32) !void {
    try self.document.createNew(width, height);
    self.canvas.centerDocument(); // TODO: also zoom
    self.updateImageStatus();
    self.setDocumentFilePath(null);
}

fn loadDocument(self: *Self, file_path: []const u8) !void {
    try self.document.load(file_path);
    self.canvas.centerDocument();
    self.updateImageStatus();
    self.updateWindowTitle(file_path);
}

pub fn tryLoadDocument(self: *Self, file_path: []const u8) void {
    self.loadDocument(file_path) catch {
        self.showErrorMessageBox("Load document", "Could not load document.");
    };
}

fn openDocument(self: *Self) !void {
    if (try nfd.openFileDialog("png", null)) |nfd_file_path| {
        defer nfd.freePath(nfd_file_path);
        try self.loadDocument(nfd_file_path);
        self.setDocumentFilePath(try self.allocator.dupe(u8, nfd_file_path));
    }
}

fn tryOpenDocument(self: *Self) void {
    self.openDocument() catch {
        self.showErrorMessageBox("Open document", "Could not open document.");
    };
}

fn saveDocument(self: *Self, force_save_as: bool) !void {
    if (force_save_as or self.document_file_path == null) {
        if (try nfd.saveFileDialog("png", null)) |nfd_file_path| {
            defer nfd.freePath(nfd_file_path);

            // check extension
            var png_file_path = (if (!isExtPng(nfd_file_path))
                try std.mem.concat(self.allocator, u8, &.{ nfd_file_path, ".png" })
            else
                try self.allocator.dupe(u8, nfd_file_path));

            try self.document.save(png_file_path);
            self.setDocumentFilePath(png_file_path);
        }
    } else if (self.document_file_path) |document_file_path| {
        try self.document.save(document_file_path);
    }
}

fn trySaveDocument(self: *Self, force_save_as: bool) void {
    self.saveDocument(force_save_as) catch {
        self.showErrorMessageBox("Save document", "Could not save document.");
    };
}

fn tryUndoDocument(self: *Self) void {
    self.document.undo() catch {
        self.showErrorMessageBox("Undo", "Could not undo.");
    };
}

fn tryRedoDocument(self: *Self) void {
    self.document.redo() catch {
        self.showErrorMessageBox("Redo", "Could not redo.");
    };
}

fn selectAll(self: *Self) void {
    self.setTool(.select);
    if (self.document.selection) |_| {
        self.document.clearSelection() catch {}; // TODO
    }
    const w = @intCast(i32, self.document.bitmap.width);
    const h = @intCast(i32, self.document.bitmap.height);
    self.document.makeSelection(Rect(i32).make(0, 0, w, h)) catch {}; // TODO
}

fn cutDocument(self: *Self) void {
    self.document.cut() catch {
        // TODO handle
    };
    self.checkClipboard();
}

fn copyDocument(self: *Self) void {
    self.document.copy() catch {
        // TODO handle
    };
    self.checkClipboard();
}

fn pasteDocument(self: *Self) void {
    self.document.paste() catch {
        // TODO handle
    };
    self.checkClipboard();
    self.setTool(.select);
}

fn fillDocument(self: *Self, color_layer: ColorForegroundBackgroundWidget.ColorLayer) void {
    const color = self.color_foreground_background.getRgba(color_layer);
    self.document.fill(color) catch {}; // TODO: handle
}

fn mirrorHorizontallyDocument(self: *Self) void {
    self.document.mirrorHorizontally() catch {}; // TODO: handle
}

fn mirrorVerticallyDocument(self: *Self) void {
    self.document.mirrorVertically() catch {}; // TODO: handle
}

fn rotateCwDocument(self: *Self) void {
    self.document.rotateCw() catch {}; // TODO: handle
}

fn rotateCcwDocument(self: *Self) void {
    self.document.rotateCcw() catch {}; // TODO: handle
}

fn setTool(self: *Self, tool: CanvasWidget.ToolType) void {
    self.canvas.setTool(tool);
    self.crop_tool_button.checked = tool == .crop;
    self.select_tool_button.checked = tool == .select;
    self.draw_tool_button.checked = tool == .draw;
    self.fill_tool_button.checked = tool == .fill;
    self.setHelpText(self.getToolHelpText());
}

fn toggleGrid(self: *Self) void {
    self.canvas.grid_enabled = !self.canvas.grid_enabled;
    self.grid_button.checked = self.canvas.grid_enabled;
}

fn setDocumentFilePath(self: *Self, maybe_file_path: ?[]const u8) void {
    if (self.document_file_path) |document_file_path| {
        self.allocator.free(document_file_path);
    }
    self.document_file_path = maybe_file_path;

    self.updateWindowTitle(if (maybe_file_path) |file_path| file_path else "Untitled");
}

var buf: [1024]u8 = undefined;
fn updateWindowTitle(self: *Self, file_path: []const u8) void {
    if (self.widget.getWindow()) |window| {
        const basename = std.fs.path.basename(file_path);
        const title = std.fmt.bufPrintZ(&buf, "{s} - Mini Pixel", .{basename}) catch unreachable;
        window.setTitle(title);
    }
}

fn setHelpText(self: *Self, help_text: []const u8) void {
    self.help_status_label.text = help_text;
}

fn getToolHelpText(self: Self) []const u8 {
    return switch (self.canvas.tool) {
        .crop => "Drag to create crop region, double click region to apply, right click to cancel",
        .select => "Drag to create selection, right click to cancel selection",
        .draw => "Left click to draw, right click to pick color, hold shift to draw line",
        .fill => "Left click to flood fill, right click to pick color",
    };
}

pub fn updateImageStatus(self: *Self) void {
    self.image_status_label.text = std.fmt.bufPrintZ(
        self.image_text[0..],
        "{d}x{d}",
        .{ self.document.bitmap.width, self.document.bitmap.height },
    ) catch unreachable;
}

pub fn setMemoryUsageInfo(self: *Self, bytes: usize) void {
    var unit = "KiB";
    var fb = @intToFloat(f32, bytes) / 1024.0;
    if (bytes > 1 << 20) {
        unit = "MiB";
        fb /= 1024.0;
    }
    self.memory_status_label.text = std.fmt.bufPrintZ(
        self.memory_text[0..],
        "{d:.2} {s}",
        .{ fb, unit },
    ) catch unreachable;
}

fn isExtPng(file_path: []const u8) bool {
    const ext = std.fs.path.extension(file_path);
    return std.ascii.eqlIgnoreCase(".png", ext);
}

fn getEditorFromMenuButton(menu_button: *gui.Button) *Self {
    if (menu_button.widget.parent) |menu_bar_widget| {
        if (menu_bar_widget.parent) |parent| {
            return @fieldParentPtr(EditorWidget, "widget", parent);
        }
    }
    unreachable; // forgot to add button to the menu_bar
}

fn menuButtonOnLeave(menu_button: *gui.Button) void {
    const editor = getEditorFromMenuButton(menu_button);
    editor.setHelpText(editor.getToolHelpText());
}
