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
const col = @import("color.zig");
const ColorLayer = col.ColorLayer;

const Clipboard = @import("Clipboard.zig");
const Document = @import("Document.zig");

const MessageBoxWidget = @import("MessageBoxWidget.zig");
const NewDocumentWidget = @import("NewDocumentWidget.zig");
const AboutDialogWidget = @import("AboutDialogWidget.zig");
const CanvasWidget = @import("CanvasWidget.zig");
const ColorPaletteWidget = @import("ColorPaletteWidget.zig");
const ColorPickerWidget = @import("ColorPickerWidget.zig");
const ColorForegroundBackgroundWidget = @import("ColorForegroundBackgroundWidget.zig");
const BlendModeWidget = @import("BlendModeWidget.zig");
const PreviewWidget = @import("PreviewWidget.zig");
const TimelineWidget = @import("TimelineWidget.zig");

pub const EditorWidget = @This();

widget: gui.Widget,
allocator: Allocator,

document: *Document,
document_file_path: ?[]const u8 = null,
has_unsaved_changes: bool = false,

menu_bar: *gui.Toolbar,
new_button: *gui.Button,
open_button: *gui.Button,
save_button: *gui.Button,
saveas_button: *gui.Button,
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
pixel_grid_button: *gui.Button,
custom_grid_button: *gui.Button,
snap_button: *gui.Button,
custom_grid_x_spinner: *gui.Spinner(i32),
custom_grid_y_spinner: *gui.Spinner(i32),
zoom_label: *gui.Label,
zoom_spinner: *gui.Spinner(f32),
about_button: *gui.Button,

status_bar: *gui.Toolbar,
help_status_label: *gui.Label,
tool_status_label: *gui.Label,
image_status_label: *gui.Label,
memory_status_label: *gui.Label,

// help_text: [200]u8 = .{0} ** 200,
tool_text: [100]u8 = .{0} ** 100,
image_text: [40]u8 = .{0} ** 40,
memory_text: [100]u8 = .{0} ** 100,

message_box_widget: *MessageBoxWidget,
message_box_result_context: usize = 0,
onMessageBoxResultFn: ?std.meta.FnPtr(fn (usize, MessageBoxWidget.Result) void) = null,

new_document_widget: *NewDocumentWidget,
about_dialog_widget: *AboutDialogWidget,
canvas: *CanvasWidget,
palette_bar: *gui.Toolbar,
palette_open_button: *gui.Button,
palette_save_button: *gui.Button,
palette_copy_button: *gui.Button,
palette_paste_button: *gui.Button,
palette_toggle_button: *gui.Button,
color_palette: *ColorPaletteWidget,
color_picker: *ColorPickerWidget,
color_foreground_background: *ColorForegroundBackgroundWidget,
blend_mode: *BlendModeWidget,
preview: *PreviewWidget,
panel_right: *gui.Panel,
timeline: *TimelineWidget,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,

        .document = try Document.init(allocator, vg),

        .menu_bar = try gui.Toolbar.init(allocator, Rect(f32).make(0, 0, 100, 24)),
        .new_button = try gui.Button.init(allocator, rect, ""),
        .open_button = try gui.Button.init(allocator, rect, ""),
        .save_button = try gui.Button.init(allocator, rect, ""),
        .saveas_button = try gui.Button.init(allocator, rect, ""),
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
        .pixel_grid_button = try gui.Button.init(allocator, rect, ""),
        .custom_grid_button = try gui.Button.init(allocator, rect, ""),
        .snap_button = try gui.Button.init(allocator, rect, ""),
        .custom_grid_x_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(0, 0, 45, 20)),
        .custom_grid_y_spinner = try gui.Spinner(i32).init(allocator, Rect(f32).make(0, 0, 45, 20)),
        .zoom_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 37, 20), "Zoom:"),
        .zoom_spinner = try gui.Spinner(f32).init(allocator, Rect(f32).make(0, 0, 55, 20)),
        .about_button = try gui.Button.init(allocator, rect, ""),

        .status_bar = try gui.Toolbar.init(allocator, Rect(f32).make(0, 0, 100, 24)),
        .help_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 450, 20), ""),
        .tool_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 205, 20), ""),
        .image_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 100, 20), ""),
        .memory_status_label = try gui.Label.init(allocator, Rect(f32).make(0, 0, 80, 20), ""),

        .message_box_widget = try MessageBoxWidget.init(allocator, ""),
        .new_document_widget = try NewDocumentWidget.init(allocator, self),
        .about_dialog_widget = try AboutDialogWidget.init(allocator),
        .canvas = try CanvasWidget.init(allocator, Rect(f32).make(0, 24, rect.w, rect.h), self.document, vg),
        .palette_bar = try gui.Toolbar.init(allocator, Rect(f32).make(0, 0, 163, 24)),
        .palette_open_button = try gui.Button.init(allocator, rect, ""),
        .palette_save_button = try gui.Button.init(allocator, rect, ""),
        .palette_copy_button = try gui.Button.init(allocator, rect, ""),
        .palette_paste_button = try gui.Button.init(allocator, rect, ""),
        .palette_toggle_button = try gui.Button.init(allocator, rect, ""),
        .color_palette = try ColorPaletteWidget.init(allocator, Rect(f32).make(0, 0, 163, 163)),
        .color_picker = try ColorPickerWidget.init(allocator, Rect(f32).make(0, 0, 163, 117)),
        .color_foreground_background = try ColorForegroundBackgroundWidget.init(allocator, Rect(f32).make(0, 0, 66, 66), vg),
        .blend_mode = try BlendModeWidget.init(allocator, Rect(f32).make(66, 0, 163 - 66, 66), vg),
        .preview = try PreviewWidget.init(allocator, Rect(f32).make(0, 0, 163, 120), self.document, vg),
        .panel_right = try gui.Panel.init(allocator, Rect(f32).make(0, 0, 163, 200)),
        .timeline = try TimelineWidget.init(allocator, Rect(f32).make(0, 0, 100, 140), self.document),
    };
    self.widget.onResizeFn = onResize;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onClipboardUpdateFn = onClipboardUpdate;

    try self.initMenubar();

    self.help_status_label.padding = 3;
    self.help_status_label.draw_border = true;
    self.help_status_label.widget.layout.grow = true;
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
    try self.widget.addChild(&self.palette_bar.widget);
    try self.palette_bar.addButton(self.palette_open_button);
    try self.palette_bar.addButton(self.palette_save_button);
    try self.palette_bar.addSeparator();
    try self.palette_bar.addButton(self.palette_copy_button);
    try self.palette_bar.addButton(self.palette_paste_button);
    try self.palette_bar.addSeparator();
    try self.palette_bar.addButton(self.palette_toggle_button);
    try self.widget.addChild(&self.color_palette.widget);
    try self.widget.addChild(&self.color_picker.widget);
    try self.widget.addChild(&self.color_foreground_background.widget);
    try self.widget.addChild(&self.blend_mode.widget);
    try self.widget.addChild(&self.preview.widget);
    try self.widget.addChild(&self.panel_right.widget);
    try self.widget.addChild(&self.timeline.widget);
    try self.widget.addChild(&self.status_bar.widget);

    configureToolbarButton(self.palette_open_button, icons.iconOpen, tryOpenPalette, "Open Palette");
    configureToolbarButton(self.palette_save_button, icons.iconSave, trySavePalette, "Save Palette");
    configureToolbarButton(self.palette_copy_button, icons.iconCopyEnabled, tryCopyPalette, "Copy Color");
    configureToolbarButton(self.palette_paste_button, icons.iconPasteEnabled, tryPastePalette, "Paste Color");
    configureToolbarButton(self.palette_toggle_button, icons.iconColorPalette, tryTogglePalette, "Toggle between 8-bit indexed mode and true color");

    std.mem.copy(u8, self.document.colormap, &self.color_palette.colors);
    try self.document.history.reset(self.document); // so palette is part of first snapshot
    self.color_palette.onSelectionChangedFn = struct {
        fn selectionChanged(color_palette: *ColorPaletteWidget) void {
            if (color_palette.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                if (color_palette.selected) |selected| {
                    const color = color_palette.colors[4 * selected ..][0..4];
                    switch (editor.document.getBitmapType()) {
                        .color => editor.color_picker.setRgb(color[0..3]), // in true color mode we don't set the alpha
                        .indexed => editor.color_picker.setRgba(color),
                    }
                    editor.color_foreground_background.setActiveRgba(&editor.color_picker.color);
                    switch (editor.color_foreground_background.active) {
                        .foreground => {
                            editor.document.foreground_color = editor.color_picker.color;
                            editor.document.foreground_index = @truncate(u8, selected);
                        },
                        .background => {
                            editor.document.background_color = editor.color_picker.color;
                            editor.document.background_index = @truncate(u8, selected);
                        },
                    }
                }
                editor.checkClipboard();
            }
        }
    }.selectionChanged;

    self.canvas.onColorPickedFn = struct {
        fn colorPicked(canvas: *CanvasWidget) void {
            if (canvas.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                switch (editor.document.getBitmapType()) {
                    .color => editor.color_foreground_background.setRgba(.foreground, &editor.document.foreground_color),
                    .indexed => {
                        if (editor.color_foreground_background.active == .foreground) {
                            editor.color_palette.setSelection(editor.document.foreground_index);
                        } else {
                            editor.color_foreground_background.setRgba(.foreground, &editor.document.foreground_color);
                        }
                    },
                }
            }
        }
    }.colorPicked;
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
                    std.mem.copy(u8, editor.color_palette.colors[4 * selected ..][0..4], &color_picker.color);
                    editor.updateDocumentPaletteAt(selected);
                }
                editor.color_foreground_background.setActiveRgba(&color_picker.color);
                switch (editor.color_foreground_background.active) {
                    .foreground => editor.document.foreground_color = editor.color_picker.color,
                    .background => editor.document.background_color = editor.color_picker.color,
                }
            }
        }
    }.changed;

    self.color_foreground_background.onChangedFn = struct {
        fn changed(color_foreground_background: *ColorForegroundBackgroundWidget, change_type: ColorForegroundBackgroundWidget.ChangeType) void {
            if (color_foreground_background.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                const color = color_foreground_background.getActiveRgba();
                switch (editor.document.getBitmapType()) {
                    .color => {
                        if (editor.color_palette.selected) |selected| {
                            // In true color mode deselect
                            const palette_color = editor.color_palette.colors[4 * selected ..][0..4];
                            if (!std.mem.eql(u8, palette_color[0..3], color[0..3])) {
                                editor.color_palette.clearSelection();
                            }
                        }
                        editor.document.foreground_color = editor.color_foreground_background.getRgba(.foreground);
                        editor.document.background_color = editor.color_foreground_background.getRgba(.background);
                    },
                    .indexed => {
                        if (change_type == .swap) {
                            std.mem.swap(u8, &editor.document.foreground_index, &editor.document.background_index);
                        }
                        if (change_type == .active or change_type == .swap) {
                            switch (color_foreground_background.active) {
                                .foreground => editor.color_palette.selected = editor.document.foreground_index,
                                .background => editor.color_palette.selected = editor.document.background_index,
                            }
                        }
                    },
                }
                editor.color_picker.setRgba(&color);
            }
        }
    }.changed;

    self.blend_mode.onChangedFn = struct {
        fn changed(blend_mode: *BlendModeWidget) void {
            if (blend_mode.widget.parent) |parent| {
                var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                editor.document.blend_mode = blend_mode.active;
            }
        }
    }.changed;

    self.document.history.editor = self; // Register for updates

    self.updateLayout();
    self.setTool(.draw);
    self.canvas.centerDocument();
    self.updateImageStatus();
    self.checkClipboard();

    return self;
}

fn configureToolbarButton(
    button: *gui.Button,
    iconFn: std.meta.FnPtr(fn (nvg) void),
    comptime onEditorClick: fn (*Self) void,
    comptime help_text: []const u8,
) void {
    button.iconFn = iconFn;
    button.onClickFn = struct {
        fn click(b: *gui.Button) void {
            onEditorClick(getEditorFromMenuButton(b));
        }
    }.click;
    button.onEnterFn = struct {
        fn enter(b: *gui.Button) void {
            getEditorFromMenuButton(b).setHelpText(help_text);
        }
    }.enter;
    button.onLeaveFn = menuButtonOnLeave;
}

fn initMenubar(self: *Self) !void {
    configureToolbarButton(self.new_button, icons.iconNew, newDocument, "New Document (Ctrl+N)");
    configureToolbarButton(self.open_button, icons.iconOpen, tryOpenDocument, "Open Document (Ctrl+O)");
    configureToolbarButton(self.save_button, icons.iconSave, trySaveDocument, "Save Document (Ctrl+S)");
    configureToolbarButton(self.saveas_button, icons.iconSaveAs, trySaveAsDocument, "Save Document As (Ctrl+Shift+S)");

    configureToolbarButton(self.undo_button, icons.iconUndoDisabled, tryUndoDocument, "Undo Action (Ctrl+Z)");
    configureToolbarButton(self.redo_button, icons.iconRedoDisabled, tryRedoDocument, "Redo Action (Ctrl+Y)");

    configureToolbarButton(self.cut_button, icons.iconCut, cutDocument, "Cut Selection to Clipboard (Ctrl+X)");
    configureToolbarButton(self.copy_button, icons.iconCopyEnabled, copyDocument, "Copy Selection to Clipboard (Ctrl+C)");
    configureToolbarButton(self.paste_button, icons.iconPasteEnabled, pasteDocument, "Paste from Clipboard (Ctrl+V)");

    configureToolbarButton(self.crop_tool_button, icons.iconToolCrop, setToolCrop, "Crop/Enlarge Tool (C)");
    configureToolbarButton(self.select_tool_button, icons.iconToolSelect, setToolSelect, "Rectangle Select Tool (R)");
    configureToolbarButton(self.draw_tool_button, icons.iconToolPen, setToolDraw, "Pen Tool (N)");
    configureToolbarButton(self.fill_tool_button, icons.iconToolBucket, setToolFill, "Fill Tool (B)");

    configureToolbarButton(self.mirror_h_tool_button, icons.iconMirrorHorizontally, mirrorHorizontallyDocument, "Mirror Horizontally");
    configureToolbarButton(self.mirror_v_tool_button, icons.iconMirrorVertically, mirrorVerticallyDocument, "Mirror Vertically");
    configureToolbarButton(self.rotate_ccw_tool_button, icons.iconRotateCcw, rotateDocumentCcw, "Rotate Counterclockwise");
    configureToolbarButton(self.rotate_cw_tool_button, icons.iconRotateCw, rotateDocumentCw, "Rotate Clockwise");

    configureToolbarButton(self.pixel_grid_button, icons.iconPixelGrid, togglePixelGrid, "Toggle Pixel Grid (#)");
    self.pixel_grid_button.checked = self.canvas.pixel_grid_enabled;
    configureToolbarButton(self.custom_grid_button, icons.iconCustomGrid, toggleCustomGrid, "Toggle Custom Grid");
    self.custom_grid_button.checked = self.canvas.pixel_grid_enabled;
    configureToolbarButton(self.snap_button, icons.iconSnapDisabled, toggleGridSnapping, "Toggle Grid Snapping");
    self.snap_button.widget.enabled = false;
    self.snap_button.checked = self.canvas.grid_snapping_enabled;
    self.custom_grid_x_spinner.min_value = 2;
    self.custom_grid_x_spinner.max_value = 512;
    self.custom_grid_x_spinner.step_mode = .exponential;
    self.custom_grid_x_spinner.setValue(@intCast(i32, self.canvas.custom_grid_spacing_x));
    self.custom_grid_x_spinner.widget.enabled = false;
    self.custom_grid_x_spinner.onChangedFn = struct {
        fn changed(spinner: *gui.Spinner(i32)) void {
            if (spinner.widget.parent) |menu_bar_widget| {
                if (menu_bar_widget.parent) |parent| {
                    var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                    editor.canvas.custom_grid_spacing_x = @intCast(u32, spinner.value);
                }
            }
        }
    }.changed;
    self.custom_grid_y_spinner.min_value = 2;
    self.custom_grid_y_spinner.max_value = 512;
    self.custom_grid_y_spinner.step_mode = .exponential;
    self.custom_grid_y_spinner.setValue(@intCast(i32, self.canvas.custom_grid_spacing_y));
    self.custom_grid_y_spinner.widget.enabled = false;
    self.custom_grid_y_spinner.onChangedFn = struct {
        fn changed(spinner: *gui.Spinner(i32)) void {
            if (spinner.widget.parent) |menu_bar_widget| {
                if (menu_bar_widget.parent) |parent| {
                    var editor = @fieldParentPtr(EditorWidget, "widget", parent);
                    editor.canvas.custom_grid_spacing_y = @intCast(u32, spinner.value);
                }
            }
        }
    }.changed;

    self.zoom_spinner.setValue(self.canvas.scale);
    self.zoom_spinner.min_value = CanvasWidget.min_scale;
    self.zoom_spinner.max_value = CanvasWidget.max_scale;
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

    configureToolbarButton(self.about_button, icons.iconAbout, showAboutDialog, "About Mini Pixel");

    // build menu bar
    try self.menu_bar.addButton(self.new_button);
    try self.menu_bar.addButton(self.open_button);
    try self.menu_bar.addButton(self.save_button);
    try self.menu_bar.addButton(self.saveas_button);
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
    try self.menu_bar.addButton(self.pixel_grid_button);
    try self.menu_bar.addButton(self.custom_grid_button);
    try self.menu_bar.addButton(self.snap_button);
    try self.menu_bar.addWidget(&self.custom_grid_x_spinner.widget);
    try self.menu_bar.addWidget(&self.custom_grid_y_spinner.widget);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addWidget(&self.zoom_label.widget);
    try self.menu_bar.addWidget(&self.zoom_spinner.widget);
    try self.menu_bar.addSeparator();
    try self.menu_bar.addButton(self.about_button);
}

pub fn deinit(self: *Self, vg: nvg) void {
    self.document.deinit(vg);
    if (self.document_file_path) |document_file_path| {
        self.allocator.free(document_file_path);
    }

    self.menu_bar.deinit();
    self.new_button.deinit();
    self.open_button.deinit();
    self.save_button.deinit();
    self.saveas_button.deinit();
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
    self.pixel_grid_button.deinit();
    self.custom_grid_button.deinit();
    self.snap_button.deinit();
    self.custom_grid_x_spinner.deinit();
    self.custom_grid_y_spinner.deinit();
    self.zoom_label.deinit();
    self.zoom_spinner.deinit();
    self.about_button.deinit();

    self.status_bar.deinit();
    self.help_status_label.deinit();
    self.tool_status_label.deinit();
    self.image_status_label.deinit();
    self.memory_status_label.deinit();

    self.message_box_widget.deinit();
    self.new_document_widget.deinit();
    self.about_dialog_widget.deinit();
    self.canvas.deinit(vg);
    self.palette_bar.deinit();
    self.palette_open_button.deinit();
    self.palette_save_button.deinit();
    self.palette_copy_button.deinit();
    self.palette_paste_button.deinit();
    self.palette_toggle_button.deinit();
    self.color_palette.deinit();
    self.color_picker.deinit();
    self.color_foreground_background.deinit(vg);
    self.blend_mode.deinit(vg);
    self.preview.deinit(vg);
    self.panel_right.deinit();
    self.timeline.deinit();

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
            .S => if (shift_held) self.trySaveAsDocument() else self.trySaveDocument(),
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
        const has_selection = self.document.selection != null;
        if (!has_selection) {
            switch (key_event.key) {
                .Left => self.document.gotoPrevFrame(),
                .Right => self.document.gotoNextFrame(),
                else => {},
            }
        }
        switch (key_event.key) {
            .C => self.setTool(.crop), // Crop
            .R => self.setTool(.select), // Rectangle select
            .N => self.setTool(.draw), // peNcil
            .B => self.setTool(.fill), // Bucket
            .X => self.color_foreground_background.swap(),
            .Hash => self.togglePixelGrid(),
            // .Space => self.document.togglePlayback(), // TODO
            else => key_event.event.ignore(),
        }
    } else {
        key_event.event.ignore();
    }
}

pub fn onUndoChanged(self: *Self, document: *Document) void {
    self.undo_button.widget.enabled = document.canUndo();
    self.undo_button.iconFn = if (self.undo_button.widget.enabled)
        icons.iconUndoEnabled
    else
        icons.iconUndoDisabled;
    self.redo_button.widget.enabled = document.canRedo();
    self.redo_button.iconFn = if (self.redo_button.widget.enabled)
        icons.iconRedoEnabled
    else
        icons.iconRedoDisabled;
    self.onDocumentChanged();
    self.updateImageStatus();
    self.has_unsaved_changes = true;
    self.updateWindowTitle();
}

fn onClipboardUpdate(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    self.checkClipboard();
}

fn checkClipboard(self: *Self) void {
    if (Clipboard.hasImage()) {
        self.paste_button.widget.enabled = true;
        self.paste_button.iconFn = icons.iconPasteEnabled;
    } else {
        self.paste_button.widget.enabled = false;
        self.paste_button.iconFn = icons.iconPasteDisabled;
    }

    if (self.color_palette.selected != null) {
        self.palette_copy_button.widget.enabled = true;
        self.palette_copy_button.iconFn = icons.iconCopyEnabled;
    } else {
        self.palette_copy_button.widget.enabled = false;
        self.palette_copy_button.iconFn = icons.iconCopyDisabled;
    }
    if (self.color_palette.selected != null and Clipboard.hasColor(self.allocator)) {
        self.palette_paste_button.widget.enabled = true;
        self.palette_paste_button.iconFn = icons.iconPasteEnabled;
    } else {
        self.palette_paste_button.widget.enabled = false;
        self.palette_paste_button.iconFn = icons.iconPasteDisabled;
    }
}

fn updateLayout(self: *Self) void {
    const rect = self.widget.relative_rect;
    const menu_bar_h = self.menu_bar.widget.relative_rect.h;
    const timeline_h = self.timeline.widget.relative_rect.h;
    const status_bar_h = self.status_bar.widget.relative_rect.h;
    const right_col_w = self.color_picker.widget.relative_rect.w;
    const canvas_w = rect.w - right_col_w;
    const canvas_h = rect.h - menu_bar_h - timeline_h - status_bar_h;

    self.canvas.widget.relative_rect.x = 0;
    self.palette_bar.widget.relative_rect.x = canvas_w;
    self.color_palette.widget.relative_rect.x = canvas_w;
    self.color_picker.widget.relative_rect.x = canvas_w;
    self.color_foreground_background.widget.relative_rect.x = canvas_w;
    self.blend_mode.widget.relative_rect.x = canvas_w + self.color_foreground_background.widget.relative_rect.w;
    self.preview.widget.relative_rect.x = canvas_w;
    self.panel_right.widget.relative_rect.x = canvas_w;

    var y: f32 = menu_bar_h;
    self.canvas.widget.relative_rect.y = y;
    self.palette_bar.widget.relative_rect.y = y;
    self.palette_bar.widget.relative_rect.h = menu_bar_h;
    y += self.palette_bar.widget.relative_rect.h;
    self.color_palette.widget.relative_rect.y = y;
    y += self.color_palette.widget.relative_rect.h;
    self.color_picker.widget.relative_rect.y = y;
    y += self.color_picker.widget.relative_rect.h;
    self.color_foreground_background.widget.relative_rect.y = y;
    self.blend_mode.widget.relative_rect.y = y;
    y += self.color_foreground_background.widget.relative_rect.h;
    self.preview.widget.relative_rect.y = y;
    y += self.preview.widget.relative_rect.h;
    self.panel_right.widget.relative_rect.y = y;
    self.timeline.widget.relative_rect.y = rect.h - timeline_h - status_bar_h;
    self.status_bar.widget.relative_rect.y = rect.h - status_bar_h;

    self.menu_bar.widget.setSize(rect.w, menu_bar_h);
    self.panel_right.widget.setSize(right_col_w, std.math.max(0, rect.h - self.panel_right.widget.relative_rect.y - status_bar_h));
    self.canvas.widget.setSize(canvas_w, canvas_h);
    self.timeline.widget.setSize(canvas_w, timeline_h);
    self.status_bar.widget.setSize(rect.w, menu_bar_h);
}

pub fn showErrorMessageBox(self: *Self, title: [:0]const u8, message: []const u8) void {
    self.message_box_widget.setSize(240, 100);
    self.message_box_widget.configure(.@"error", .ok, message);
    self.onMessageBoxResultFn = null;
    self.showMessageBox(title);
}

pub fn showUnsavedChangesDialog(self: *Self, onResultFn: ?std.meta.FnPtr(fn (usize, MessageBoxWidget.Result) void), result_context: usize) void {
    self.message_box_widget.setSize(280, 100);
    self.message_box_widget.configure(.question, .yes_no_cancel, "This file has been changed.\nWould you like to save those changes?");
    self.message_box_widget.yes_button.text = "Save";
    self.message_box_widget.no_button.text = "Discard";
    self.onMessageBoxResultFn = onResultFn;
    self.message_box_result_context = result_context;
    self.showMessageBox("Unsaved changes");
}

fn showMessageBox(self: *Self, title: [:0]const u8) void {
    if (self.widget.getWindow()) |parent_window| {
        var window_or_error = parent_window.createChildWindow(
            title,
            self.message_box_widget.widget.relative_rect.w,
            self.message_box_widget.widget.relative_rect.h,
            gui.Window.CreateOptions{ .resizable = false },
        );
        if (window_or_error) |window| {
            window.is_modal = true;
            window.setMainWidget(&self.message_box_widget.widget);
            self.message_box_widget.ok_button.widget.setFocus(true, .programmatic);
            self.message_box_widget.yes_button.widget.setFocus(true, .programmatic);
            window.closed_context = @ptrToInt(self);
            window.onClosedFn = onMessageBoxClosed;
        } else |_| {}
    }
}

fn onMessageBoxClosed(context: usize) void {
    const editor = @intToPtr(*EditorWidget, context);
    if (editor.onMessageBoxResultFn) |onMessageBoxResult| {
        onMessageBoxResult(editor.message_box_result_context, editor.message_box_widget.result);
    }
}

pub fn newDocument(self: *Self) void { // TODO
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

fn showAboutDialog(self: *Self) void {
    if (self.widget.getWindow()) |parent_window| {
        var window_or_error = parent_window.createChildWindow(
            "About",
            self.about_dialog_widget.widget.relative_rect.w,
            self.about_dialog_widget.widget.relative_rect.h,
            gui.Window.CreateOptions{ .resizable = false },
        );
        if (window_or_error) |window| {
            window.is_modal = true;
            window.setMainWidget(&self.about_dialog_widget.widget);
            self.about_dialog_widget.close_button.widget.setFocus(true, .programmatic);
        } else |_| {
            // TODO: show error
        }
    }
}

pub fn createNewDocument(self: *Self, width: u32, height: u32, bitmap_type: Document.BitmapType) !void {
    try self.document.createNew(width, height, bitmap_type);
    self.has_unsaved_changes = false;
    self.canvas.centerAndZoomDocument();
    self.updateImageStatus();
    try self.setDocumentFilePath(null);
}

fn loadDocument(self: *Self, file_path: []const u8) !void {
    try self.document.load(file_path);
    self.has_unsaved_changes = false;
    self.canvas.centerAndZoomDocument();
    self.updateImageStatus();
    try self.setDocumentFilePath(file_path);
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

            var png_file_path = try copyWithExtension(self.allocator, nfd_file_path, ".png");
            defer self.allocator.free(png_file_path);

            try self.document.save(png_file_path);
            self.has_unsaved_changes = false;
            try self.setDocumentFilePath(png_file_path);
        }
    } else if (self.document_file_path) |document_file_path| {
        try self.document.save(document_file_path);
        self.has_unsaved_changes = false;
        self.updateWindowTitle();
    }
}

pub fn trySaveDocument(self: *Self) void {
    self.saveDocument(false) catch {
        self.showErrorMessageBox("Save document", "Could not save document.");
    };
}

pub fn trySaveAsDocument(self: *Self) void {
    self.saveDocument(true) catch {
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
    const w = @intCast(i32, self.document.getWidth());
    const h = @intCast(i32, self.document.getHeight());
    self.document.makeSelection(Rect(i32).make(0, 0, w, h)) catch {}; // TODO
}

fn cutDocument(self: *Self) void {
    self.document.cut() catch {
        self.showErrorMessageBox("Cut image", "Could not cut to clipboard.");
        return;
    };
    self.checkClipboard();
}

fn copyDocument(self: *Self) void {
    self.document.copy() catch {
        self.showErrorMessageBox("Copy image", "Could not copy to clipboard.");
        return;
    };
    self.checkClipboard();
}

fn pasteDocument(self: *Self) void {
    self.document.paste() catch {
        self.showErrorMessageBox("Paste image", "Could not paste from clipboard.");
        return;
    };
    self.checkClipboard();
    self.setTool(.select);
}

fn fillDocument(self: *Self, color_layer: ColorLayer) void {
    self.document.fill(color_layer) catch {
        self.showErrorMessageBox("Fill image", "Could not fill the image.");
    };
}

fn mirrorHorizontallyDocument(self: *Self) void {
    self.document.mirrorHorizontally() catch {
        self.showErrorMessageBox("Mirror image", "Could not mirror the image.");
    };
}

fn mirrorVerticallyDocument(self: *Self) void {
    self.document.mirrorVertically() catch {
        self.showErrorMessageBox("Mirror image", "Could not mirror the image.");
    };
}

fn rotateDocumentCw(self: *Self) void {
    self.rotateDocument(true);
}

fn rotateDocumentCcw(self: *Self) void {
    self.rotateDocument(false);
}

fn rotateDocument(self: *Self, clockwise: bool) void {
    self.document.rotate(clockwise) catch {
        self.showErrorMessageBox("Rotate image", "Could not rotate the image.");
    };
}

fn setToolCrop(self: *Self) void {
    self.setTool(.crop);
}

fn setToolSelect(self: *Self) void {
    self.setTool(.select);
}

fn setToolDraw(self: *Self) void {
    self.setTool(.draw);
}

fn setToolFill(self: *Self) void {
    self.setTool(.fill);
}

fn setTool(self: *Self, tool: CanvasWidget.ToolType) void {
    self.canvas.setTool(tool);
    self.crop_tool_button.checked = tool == .crop;
    self.select_tool_button.checked = tool == .select;
    self.draw_tool_button.checked = tool == .draw;
    self.fill_tool_button.checked = tool == .fill;
    self.setHelpText(self.getToolHelpText());
}

fn togglePixelGrid(self: *Self) void {
    self.canvas.pixel_grid_enabled = !self.canvas.pixel_grid_enabled;
    self.pixel_grid_button.checked = self.canvas.pixel_grid_enabled;
}

fn toggleCustomGrid(self: *Self) void {
    self.canvas.custom_grid_enabled = !self.canvas.custom_grid_enabled;
    self.custom_grid_button.checked = self.canvas.custom_grid_enabled;
    self.snap_button.widget.enabled = self.canvas.custom_grid_enabled;
    self.snap_button.iconFn = if (self.canvas.custom_grid_enabled) icons.iconSnapEnabled else icons.iconSnapDisabled;
    self.custom_grid_x_spinner.widget.enabled = self.canvas.custom_grid_enabled;
    self.custom_grid_y_spinner.widget.enabled = self.canvas.custom_grid_enabled;
}

fn toggleGridSnapping(self: *Self) void {
    self.canvas.grid_snapping_enabled = !self.canvas.grid_snapping_enabled;
    self.snap_button.checked = self.canvas.grid_snapping_enabled;
}

fn openPalette(self: *Self) !void {
    if (try nfd.openFileDialog("pal", null)) |nfd_file_path| {
        defer nfd.freePath(nfd_file_path);
        try self.color_palette.loadPal(self.allocator, nfd_file_path);
        // TODO: ask for .map / .replace mode
        try self.updateDocumentPalette(.map);
    }
}

fn tryOpenPalette(self: *Self) void {
    self.openPalette() catch {
        self.showErrorMessageBox("Open palette", "Could not open palette.");
    };
}

fn savePalette(self: *Self) !void {
    if (try nfd.saveFileDialog("pal", null)) |nfd_file_path| {
        defer nfd.freePath(nfd_file_path);

        const pal_file_path = try copyWithExtension(self.allocator, nfd_file_path, ".pal");
        defer self.allocator.free(pal_file_path);

        try self.color_palette.writePal(pal_file_path);
    }
}

fn trySavePalette(self: *Self) void {
    self.savePalette() catch {
        self.showErrorMessageBox("Save palette", "Could not save palette.");
    };
}

fn tryCopyPalette(self: *Self) void {
    if (self.color_palette.selected) |selected| {
        const c = self.color_palette.colors[4 * @as(usize, selected) ..][0..4];
        Clipboard.setColor(self.allocator, .{ c[0], c[1], c[2], c[3] }) catch {
            self.showErrorMessageBox("Copy color", "Could not copy color.");
            return;
        };
        self.checkClipboard();
    }
}

fn tryPastePalette(self: *Self) void {
    if (Clipboard.getColor(self.allocator)) |color| {
        if (self.color_palette.selected) |selected| {
            std.mem.copy(u8, self.color_palette.colors[4 * @as(usize, selected) ..][0..4], &color);
            self.updateDocumentPaletteAt(selected);
        }
        self.color_foreground_background.setActiveRgba(&color);
    } else |_| {
        self.showErrorMessageBox("Paste color", "Could not paste color.");
    }
}

fn togglePalette(self: *Self) !void {
    if (self.palette_toggle_button.checked) {
        try self.document.convertToTruecolor();
    } else {
        if (try self.document.canLosslesslyConvertToIndexed()) {
            try self.document.convertToIndexed();
        } else {
            self.message_box_widget.setSize(190, 100);
            self.message_box_widget.configure(.warning, .ok_cancel, "Some colors will be lost\nduring conversion.");
            self.onMessageBoxResultFn = struct {
                fn onResult(context: usize, result: MessageBoxWidget.Result) void {
                    if (result == .ok) {
                        var editor = @intToPtr(*Self, context);
                        editor.document.convertToIndexed() catch {}; // TODO: Can't show message box because the widget is in use
                    }
                }
            }.onResult;
            self.message_box_result_context = @ptrToInt(self);
            std.debug.print("context {}\n", .{self.message_box_result_context});
            self.showMessageBox("Toggle color mode");
        }
    }
}

fn tryTogglePalette(self: *Self) void {
    self.togglePalette() catch {
        self.showErrorMessageBox("Toggle color mode", "Color conversion failed.");
    };
}

fn onDocumentChanged(self: *Self) void {
    // update GUI
    std.mem.copy(u8, &self.color_palette.colors, self.document.colormap);
    switch (self.document.getBitmapType()) {
        .color => {
            self.palette_toggle_button.checked = false;
            self.color_palette.selection_locked = false;
            std.mem.copy(u8, &self.document.foreground_color, &self.color_foreground_background.getRgba(.foreground));
            std.mem.copy(u8, &self.document.background_color, &self.color_foreground_background.getRgba(.background));
            self.blend_mode.widget.enabled = true;
        },
        .indexed => {
            self.palette_toggle_button.checked = true;

            // find nearest colors in colormap
            const fgc = self.color_foreground_background.getRgba(.foreground);
            var dfgc = self.document.colormap[4 * @as(usize, self.document.foreground_index) ..][0..4];
            if (!std.mem.eql(u8, &fgc, dfgc)) {
                self.document.foreground_index = @truncate(u8, col.findNearest(self.document.colormap, &fgc));
                dfgc = self.document.colormap[4 * @as(usize, self.document.foreground_index) ..][0..4];
                self.color_foreground_background.setRgba(.foreground, dfgc);
            }
            const bgc = self.color_foreground_background.getRgba(.background);
            var dbgc = self.document.colormap[4 * @as(usize, self.document.background_index) ..][0..4];
            if (!std.mem.eql(u8, &bgc, dbgc)) {
                self.document.background_index = @truncate(u8, col.findNearest(self.document.colormap, &bgc));
                dbgc = self.document.colormap[4 * @as(usize, self.document.background_index) ..][0..4];
                self.color_foreground_background.setRgba(.background, dbgc);
            }

            self.color_palette.selection_locked = true;
            switch (self.color_foreground_background.active) {
                .foreground => self.color_palette.setSelection(self.document.foreground_index),
                .background => self.color_palette.setSelection(self.document.background_index),
            }

            self.blend_mode.widget.enabled = false;
        },
    }
    self.timeline.onDocumentChanged();
}

fn updateDocumentPalette(self: *Self, mode: Document.PaletteUpdateMode) !void {
    try self.document.applyPalette(&self.color_palette.colors, mode);
}

fn updateDocumentPaletteAt(self: *Self, i: usize) void {
    std.mem.copy(u8, self.document.colormap[4 * i .. 4 * i + 4], self.color_palette.colors[4 * i .. 4 * i + 4]);
    self.document.need_texture_update = true;
}

fn setDocumentFilePath(self: *Self, maybe_file_path: ?[]const u8) !void {
    if (self.document_file_path) |document_file_path| {
        self.allocator.free(document_file_path);
    }
    if (maybe_file_path) |file_path| {
        self.document_file_path = try self.allocator.dupe(u8, file_path);
    } else {
        self.document_file_path = null;
    }

    self.updateWindowTitle();
}

var window_title_buffer: [1024]u8 = undefined;
fn updateWindowTitle(self: *Self) void {
    if (self.widget.getWindow()) |window| {
        const unsaved_changes_indicator = if (self.has_unsaved_changes) "● " else "";
        const document_title = if (self.document_file_path) |file_path|
            std.fs.path.basename(file_path)
        else
            "Untitled";
        const title = std.fmt.bufPrintZ(
            &window_title_buffer,
            "{s}{s} - Mini Pixel",
            .{ unsaved_changes_indicator, document_title },
        ) catch unreachable;
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
        "{d}x{d}@{d}",
        .{ self.document.getWidth(), self.document.getHeight(), self.document.getColorDepth() },
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

fn hasExtension(filename: []const u8, extension: []const u8) bool {
    return std.ascii.eqlIgnoreCase(std.fs.path.extension(filename), extension);
}

fn copyWithExtension(allocator: Allocator, filename: []const u8, extension: []const u8) ![]const u8 {
    return (if (!hasExtension(filename, extension))
        try std.mem.concat(allocator, u8, &.{ filename, extension })
    else
        try allocator.dupe(u8, filename));
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
