const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const gui = @import("gui");
const icons = @import("icons.zig");
const nvg = @import("nanovg");
const geometry = @import("gui/geometry.zig");
const Point = geometry.Point;
const Pointf = Point(f32);
const Pointi = Point(i32);
const Rect = geometry.Rect;
const Rectf = Rect(f32);
const Recti = Rect(i32);
const EditorWidget = @import("EditorWidget.zig");
const Document = @import("Document.zig");

fn itof(i: i32) f32 {
    return @intToFloat(f32, i);
}
fn ftoi(f: f32) i32 {
    return @floatToInt(i32, f);
}
fn ritof(rect: Recti) Rectf {
    return Rectf.make(itof(rect.x), itof(rect.y), itof(rect.w), itof(rect.h));
}

pub const ToolType = enum {
    crop,
    select,
    draw,
    fill,
};

const CropTool = struct {
    mouse_point: ?Pointf = null, // mouse cursor position in gui space
    edit_point: ?Pointi = null, // current cursor location in document space
    begin_point: ?Pointi = null, // selection begin in document space

    crop_rect: ?Recti = null,
    drag_offset: ?Pointf = null, // mouse cursor relative to dragged object
    drag_zone: ?u3 = null,

    const zone_size = 16;
    fn makeZones(rect: Rectf) [8]Rectf { // in gui space
        return [_]Rectf{
            makeZone(rect, 0),
            makeZone(rect, 1),
            makeZone(rect, 2),
            makeZone(rect, 3),
            makeZone(rect, 4),
            makeZone(rect, 5),
            makeZone(rect, 6),
            makeZone(rect, 7),
        };
    }
    fn makeZone(rect: Rectf, i: u3) Rectf {
        const zs = zone_size;
        return switch (i) {
            0 => Rectf.make(rect.x - zs, rect.y - zs, zs, zs),
            1 => Rectf.make(rect.x, rect.y - zs, rect.w, zs),
            2 => Rectf.make(rect.x + rect.w, rect.y - zs, zs, zs),
            3 => Rectf.make(rect.x - zs, rect.y, zs, rect.h),
            4 => Rectf.make(rect.x + rect.w, rect.y, zs, rect.h),
            5 => Rectf.make(rect.x - zs, rect.y + rect.h, zs, zs),
            6 => Rectf.make(rect.x, rect.y + rect.h, rect.w, zs),
            7 => Rectf.make(rect.x + rect.w, rect.y + rect.h, zs, zs),
        };
    }

    fn onStart(self: *CropTool) void {
        self.mouse_point = null;
        self.edit_point = null;
        self.begin_point = null;
        self.crop_rect = null;
        self.drag_offset = null;
        self.drag_zone = null;
    }

    fn onMouseMove(self: *CropTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        self.mouse_point = Pointf.make(event.x, event.y);
        const point = canvas.toDocumentSpace(event.x, event.y);
        var fx = @round(point.x);
        var fy = @round(point.y);
        canvas.snap(&fx, &fy);
        self.edit_point = Pointi.make(ftoi(fx), ftoi(fy));
        if (self.crop_rect) |*rect| {
            if (self.drag_offset) |drag_offset| { // drag
                fx = @round(point.x - drag_offset.x);
                fy = @round(point.y - drag_offset.y);
                canvas.snap(&fx, &fy);
                const x = ftoi(fx);
                const y = ftoi(fy);
                if (self.drag_zone) |drag_zone| {
                    if (drag_zone == 0 or drag_zone == 3 or drag_zone == 5) {
                        rect.w += rect.x - x;
                        rect.x = x;
                    }
                    if (drag_zone == 0 or drag_zone == 1 or drag_zone == 2) {
                        rect.h += rect.y - y;
                        rect.y = y;
                    }
                    if (drag_zone == 2 or drag_zone == 4 or drag_zone == 7) {
                        rect.w = x - rect.x;
                    }
                    if (drag_zone == 5 or drag_zone == 6 or drag_zone == 7) {
                        rect.h = y - rect.y;
                    }
                } else {
                    rect.x = x;
                    rect.y = y;
                }
            }
        }
    }

    fn onMouseDown(self: *CropTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        self.mouse_point = Pointf.make(event.x, event.y);
        const point = canvas.toDocumentSpace(event.x, event.y);
        const edit_point = Pointi.make(ftoi(@floor(point.x)), ftoi(@floor(point.y)));
        if (self.crop_rect) |rect| {
            if (event.button == .left) {
                self.edit_point = edit_point;
                if (rect.contains(edit_point)) {
                    self.drag_zone = null;
                    self.drag_offset = point.subtracted(Pointf.make(itof(rect.x), itof(rect.y)));
                } else {
                    const gui_point = Pointf.make(event.x, event.y);
                    const gui_rect = canvas.rectFromDocumentSpace(ritof(rect), false);
                    for (makeZones(gui_rect)) |zone, i| {
                        if (zone.contains(gui_point)) {
                            self.drag_zone = @intCast(u3, i);
                            self.drag_offset = point.subtracted(Pointf.make(itof(rect.x), itof(rect.y)));
                            if (i == 2 or i == 4 or i == 7) self.drag_offset.?.x -= itof(rect.w); // drag outer edges
                            if (i == 5 or i == 6 or i == 7) self.drag_offset.?.y -= itof(rect.h);
                            break;
                        }
                    }
                }
            }
        } else {
            if (event.button == .left) {
                self.begin_point = self.edit_point;
            }
        }
    }

    fn onMouseUp(self: *CropTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (self.crop_rect) |*rect| {
            if (event.button == .left) {
                self.drag_offset = null;
                self.drag_zone = null;
                // normalize rect
                if (rect.w < 0) {
                    rect.x += rect.w;
                    rect.w = -rect.w;
                }
                if (rect.h < 0) {
                    rect.y += rect.h;
                    rect.h = -rect.h;
                }

                if (event.click_count == 2) { // double click
                    if (self.edit_point) |edit_point| {
                        if (rect.contains(edit_point)) self.apply(canvas, rect.*);
                    }
                }
            } else if (event.button == .right) {
                self.cancel();
            }
        } else { // make new crop rect
            if (event.button == .left) {
                const edit_point = self.edit_point orelse return;
                const begin_point = self.begin_point orelse return;
                const rect = Recti.fromPoints(begin_point, edit_point);
                if (rect.w > 0 and rect.h > 0) {
                    self.crop_rect = rect;
                }
                self.begin_point = null;
            } else if (event.button == .right) {
                self.begin_point = null;
            }
        }
    }

    fn onKeyDown(self: *CropTool, canvas: *CanvasWidget, event: *gui.KeyEvent) void {
        if (event.modifiers == 0) {
            switch (event.key) {
                .Return => if (self.crop_rect) |crop_rect| {
                    self.apply(canvas, crop_rect);
                },
                .Escape => self.cancel(),
                else => event.event.ignore(),
            }
            return;
        }
        event.event.ignore();
    }

    fn apply(self: *CropTool, canvas: *CanvasWidget, crop_rect: Recti) void {
        if (crop_rect.w > 0 and crop_rect.h > 0) {
            canvas.document.crop(crop_rect) catch return; // TODO handle error

            canvas.updateImageStatus();

            if (self.edit_point) |*edit_point| {
                edit_point.x -= crop_rect.x;
                edit_point.y -= crop_rect.y;
            }
        }

        self.crop_rect = null;
        self.drag_offset = null;
    }

    fn cancel(self: *CropTool) void {
        self.crop_rect = null;
    }

    fn updateMousePreview(self: *CropTool, canvas: *CanvasWidget, mouse_x: f32, mouse_y: f32) void {
        const point = canvas.toDocumentSpace(mouse_x, mouse_y);
        self.edit_point = Pointi.make(ftoi(@round(point.x)), ftoi(@round(point.y)));
    }

    fn drawPreview(self: CropTool, canvas: *CanvasWidget) void {
        if (self.crop_rect) |rect| {
            const gui_rect = canvas.rectFromDocumentSpace(ritof(rect), true);
            const canvas_rect = canvas.widget.relative_rect;
            // draw vignette
            nvg.beginPath();
            nvg.rect(0, 0, canvas_rect.w, canvas_rect.h);
            nvg.pathWinding(.cw);
            nvg.rect(gui_rect.x, gui_rect.y, gui_rect.w, gui_rect.h);
            nvg.fillColor(nvg.rgbaf(0, 0, 0, 0.5));
            nvg.fill();

            // zones
            var draw_zone: ?Rectf = null;
            if (self.drag_zone) |drag_zone| {
                draw_zone = makeZone(gui_rect, drag_zone);
            } else { // check for hover
                if (self.mouse_point) |mouse_point| {
                    for (makeZones(gui_rect)) |zone| {
                        if (zone.contains(mouse_point)) {
                            draw_zone = zone;
                            break;
                        }
                    }
                }
            }
            {
                nvg.translate(0.5, 0.5);
                defer nvg.translate(-0.5, -0.5);
                if (draw_zone) |hz| {
                    nvg.beginPath();
                    nvg.rect(gui_rect.x, gui_rect.y, gui_rect.w, gui_rect.h);
                    nvg.rect(hz.x, hz.y, hz.w, hz.h);
                } else {
                    nvg.beginPath();
                    const gr = gui_rect;
                    const zs = zone_size;
                    nvg.moveTo(gr.x - zs, gr.y - zs);
                    nvg.lineTo(gr.x - zs, gr.y);
                    nvg.lineTo(gr.x + gr.w + zs, gr.y);
                    nvg.lineTo(gr.x + gr.w + zs, gr.y - zs);
                    nvg.lineTo(gr.x + gr.w, gr.y - zs);
                    nvg.lineTo(gr.x + gr.w, gr.y + gr.h + zs);
                    nvg.lineTo(gr.x + gr.w + zs, gr.y + gr.h + zs);
                    nvg.lineTo(gr.x + gr.w + zs, gr.y + gr.h);
                    nvg.lineTo(gr.x - zs, gr.y + gr.h);
                    nvg.lineTo(gr.x - zs, gr.y + gr.h + zs);
                    nvg.lineTo(gr.x, gr.y + gr.h + zs);
                    nvg.lineTo(gr.x, gr.y - zs);
                    nvg.closePath();
                }
                nvg.strokeColor(nvg.rgbaf(0, 0, 0, 0.5));
                nvg.strokeWidth(3);
                nvg.stroke();
                nvg.strokeWidth(1);
                nvg.strokeColor(nvg.rgbf(1, 1, 1));
                nvg.stroke();
            }
        } else {
            if (!canvas.hovered) return;
            const edit_point = self.edit_point orelse return;

            var center = canvas.fromDocumentSpace(
                @intToFloat(f32, edit_point.x),
                @intToFloat(f32, edit_point.y),
            );

            nvg.beginPath();
            nvg.rect(@trunc(center.x), 0, 1, canvas.widget.relative_rect.h);
            nvg.rect(0, @trunc(center.y), canvas.widget.relative_rect.w, 1);

            if (self.begin_point) |begin_point| {
                center = canvas.fromDocumentSpace(
                    @intToFloat(f32, begin_point.x),
                    @intToFloat(f32, begin_point.y),
                );
                nvg.rect(@trunc(center.x), 0, 1, canvas.widget.relative_rect.h);
                nvg.rect(0, @trunc(center.y), canvas.widget.relative_rect.w, 1);
            }

            nvg.fillPaint(nvg.imagePattern(0, 0, 4, 4, 0, canvas.grid_image, 1));
            nvg.fill();
        }
    }

    fn getCursor(self: CropTool) fn () void {
        if (self.crop_rect) |rect| {
            if (self.drag_offset != null) return icons.cursorMove; // TODO: grab cursor?
            if (self.edit_point) |edit_point| {
                if (rect.contains(edit_point)) return icons.cursorMove;
            }
        }
        return icons.cursorCrosshair;
    }

    fn getStatusText(self: CropTool, buf: []u8) [:0]const u8 {
        if (self.crop_rect) |rect| {
            return std.fmt.bufPrintZ(
                buf[0..],
                "[{d}, {d}, {d}, {d}]",
                .{ rect.x, rect.y, rect.w, rect.h },
            ) catch unreachable;
        }

        if (self.edit_point) |edit_point| {
            if (self.begin_point) |begin_point| {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d}, {d}, {d})",
                    .{
                        begin_point.x,
                        begin_point.y,
                        edit_point.x - begin_point.x,
                        edit_point.y - begin_point.y,
                    },
                ) catch unreachable;
            } else {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d})",
                    .{ edit_point.x, edit_point.y },
                ) catch unreachable;
            }
        } else {
            return std.fmt.bufPrintZ(buf[0..], "", .{}) catch unreachable;
        }
    }
};

const SelectTool = struct {
    edit_point: ?Pointi = null, // current cursor location in document space
    begin_point: ?Pointi = null, // selection begin

    drag_offset: ?Pointf = null, // mouse cursor relative to dragged object

    fn onStart(self: *SelectTool) void {
        self.edit_point = null;
        self.begin_point = null;
    }

    fn onExit(self: *SelectTool, canvas: *CanvasWidget) void {
        _ = self;
        if (canvas.document.selection != null) {
            canvas.document.clearSelection() catch {
                // TODO: show error
            };
        }
    }

    fn onMouseMove(self: *SelectTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        const point = canvas.toDocumentSpace(event.x, event.y);
        if (canvas.document.selection) |*selection| {
            self.edit_point = Pointi.make(ftoi(@floor(point.x)), ftoi(@floor(point.y)));
            if (self.drag_offset) |drag_offset| {
                var fx = @round(point.x - drag_offset.x);
                var fy = @round(point.y - drag_offset.y);
                canvas.snap(&fx, &fy);
                selection.rect.x = ftoi(fx);
                selection.rect.y = ftoi(fy);
            }
        } else {
            var fx = @round(point.x);
            var fy = @round(point.y);
            canvas.snap(&fx, &fy);
            self.edit_point = Pointi.make(ftoi(fx), ftoi(fy));
        }
    }

    fn onMouseDown(self: *SelectTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (canvas.document.selection) |selection| {
            if (event.button == .left) {
                const point = canvas.toDocumentSpace(event.x, event.y);
                const pointi = Pointi.make(@floatToInt(i32, point.x), @floatToInt(i32, point.y));
                if (selection.rect.contains(pointi)) {
                    self.drag_offset = point.subtracted(Pointf.make(itof(selection.rect.x), itof(selection.rect.y)));
                }
            }
        } else {
            if (event.button == .left) {
                self.begin_point = self.edit_point;
            }
        }
    }

    fn onMouseUp(self: *SelectTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (canvas.document.selection) |_| {
            if (event.button == .left) {
                self.drag_offset = null;
            } else if (event.button == .right) {
                canvas.document.clearSelection() catch {
                    // TODO: show error
                };
            }
        } else { // no selection
            if (event.button == .left) {
                const edit_point = self.edit_point orelse return;
                const begin_point = self.begin_point orelse return;
                const rect = Recti.fromPoints(begin_point, edit_point);
                if (rect.w > 0 and rect.h > 0) {
                    canvas.document.makeSelection(rect) catch {
                        // TODO: show error
                    };
                }
                self.begin_point = null;
            } else if (event.button == .right) {
                self.begin_point = null;
            }
        }
    }

    fn onKeyDown(self: *SelectTool, canvas: *CanvasWidget, event: *gui.KeyEvent) void {
        _ = self;
        if (canvas.document.selection) |*selection| {
            if (event.modifiers == 0) {
                switch (event.key) {
                    .Escape => canvas.document.clearSelection() catch {},
                    .Delete => canvas.document.deleteSelection() catch {},
                    .Left => selection.rect.x -= 1,
                    .Right => selection.rect.x += 1,
                    .Up => selection.rect.y -= 1,
                    .Down => selection.rect.y += 1,
                    else => event.event.ignore(),
                }
                return;
            }
        }
        event.event.ignore();
    }

    fn updateMousePreview(self: *SelectTool, canvas: *CanvasWidget, mouse_x: f32, mouse_y: f32) void {
        const point = canvas.toDocumentSpace(mouse_x, mouse_y);
        self.edit_point = Pointi.make(ftoi(@round(point.x)), ftoi(@round(point.y)));
    }

    fn drawPreview(self: SelectTool, canvas: *CanvasWidget) void {
        if (canvas.document.selection != null) return;
        if (!canvas.hovered) return;
        const edit_point = self.edit_point orelse return;

        var center = canvas.fromDocumentSpace(
            @intToFloat(f32, edit_point.x),
            @intToFloat(f32, edit_point.y),
        );

        nvg.beginPath();
        nvg.rect(@trunc(center.x), 0, 1, canvas.widget.relative_rect.h);
        nvg.rect(0, @trunc(center.y), canvas.widget.relative_rect.w, 1);

        if (self.begin_point) |begin_point| {
            center = canvas.fromDocumentSpace(
                @intToFloat(f32, begin_point.x),
                @intToFloat(f32, begin_point.y),
            );
            nvg.rect(@trunc(center.x), 0, 1, canvas.widget.relative_rect.h);
            nvg.rect(0, @trunc(center.y), canvas.widget.relative_rect.w, 1);
        }

        nvg.fillPaint(nvg.imagePattern(0, 0, 4, 4, 0, canvas.grid_image, 1));
        nvg.fill();
    }

    fn getCursor(self: SelectTool, canvas: *CanvasWidget) fn () void {
        if (canvas.document.selection) |selection| {
            if (self.drag_offset != null) return icons.cursorMove; // TODO: grab cursor?
            if (self.edit_point) |edit_point| {
                if (selection.rect.contains(edit_point)) return icons.cursorMove;
            }
        }
        return icons.cursorCrosshair;
    }

    fn getStatusText(self: SelectTool, canvas: CanvasWidget, buf: []u8) [:0]const u8 {
        if (canvas.document.selection) |selection| {
            return std.fmt.bufPrintZ(
                buf[0..],
                "[{d}, {d}, {d}, {d}]",
                .{
                    selection.rect.x,
                    selection.rect.y,
                    selection.rect.w,
                    selection.rect.h,
                },
            ) catch unreachable;
        }

        if (self.edit_point) |edit_point| {
            if (self.begin_point) |begin_point| {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d}, {d}, {d})",
                    .{
                        begin_point.x,
                        begin_point.y,
                        edit_point.x - begin_point.x,
                        edit_point.y - begin_point.y,
                    },
                ) catch unreachable;
            } else {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d})",
                    .{ edit_point.x, edit_point.y },
                ) catch unreachable;
            }
        } else {
            return std.fmt.bufPrintZ(buf[0..], "", .{}) catch unreachable;
        }
    }
};

const DrawTool = struct {
    edit_point: Pointi = Pointi{ .x = -1, .y = -1 },
    last_point: ?Pointi = null,
    drawing: bool = false,
    picking: bool = false,

    fn onExit(self: *DrawTool, canvas: *CanvasWidget) void {
        canvas.document.clearPreview();
        if (self.drawing) {
            canvas.document.endStroke() catch {}; // TODO: handle?
            self.drawing = false;
        }
        self.last_point = null;
    }

    fn onMouseMove(self: *DrawTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        const point = canvas.toDocumentSpace(event.x, event.y);
        self.edit_point.x = @floatToInt(i32, @floor(point.x));
        self.edit_point.y = @floatToInt(i32, @floor(point.y));

        if (event.isButtonPressed(.left) and self.drawing) {
            if (self.last_point) |last_point| {
                if (last_point.x != self.edit_point.x or last_point.y != self.edit_point.y) {
                    canvas.document.stroke(
                        last_point.x,
                        last_point.y,
                        self.edit_point.x,
                        self.edit_point.y,
                    );
                }
            }
            self.last_point = self.edit_point;
        } else if (event.isModifierPressed(.shift)) {
            if (self.last_point) |last_point| {
                canvas.document.previewStroke(
                    last_point.x,
                    last_point.y,
                    self.edit_point.x,
                    self.edit_point.y,
                );
            }
        } else if (!self.picking) {
            canvas.document.previewBrush(self.edit_point.x, self.edit_point.y);
        }
    }

    fn onMouseDown(self: *DrawTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (event.button == .left) {
            if (event.isModifierPressed(.shift) and self.last_point != null) {
                if (self.last_point) |last_point| {
                    canvas.document.stroke(
                        last_point.x,
                        last_point.y,
                        self.edit_point.x,
                        self.edit_point.y,
                    );
                }
            } else {
                canvas.document.beginStroke(self.edit_point.x, self.edit_point.y);
            }
            self.last_point = self.edit_point;
            self.drawing = true;
        } else if (event.button == .right) {
            self.picking = true;
            canvas.document.clearPreview();
        }
    }

    fn onMouseUp(self: *DrawTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (event.button == .left) {
            canvas.document.endStroke() catch {
                gui.showMessageBox(.err, "Stroke", "Out of memory"); // TODO: nicer error message
            };
            self.drawing = false;
        } else if (event.button == .right) {
            canvas.document.pick(self.edit_point.x, self.edit_point.y);
            canvas.notifyColorChanged();
            self.picking = false;
        }
    }

    fn onKeyDown(self: *DrawTool, canvas: *CanvasWidget, event: *gui.KeyEvent) void {
        switch (event.key) {
            .LShift, .RShift => {
                if (!event.repeat) {
                    //self.last_point = self.edit_point;

                    if (self.last_point) |last_point| {
                        canvas.document.previewStroke(
                            last_point.x,
                            last_point.y,
                            self.edit_point.x,
                            self.edit_point.y,
                        );
                    } else {
                        canvas.document.previewBrush(self.edit_point.x, self.edit_point.y);
                    }
                    return;
                }
            },
            else => {},
        }
        event.event.ignore();
    }

    fn onKeyUp(self: *DrawTool, canvas: *CanvasWidget, event: *gui.KeyEvent) void {
        switch (event.key) {
            .LShift, .RShift => {
                if (!event.repeat) {
                    canvas.document.previewBrush(self.edit_point.x, self.edit_point.y);
                    return;
                }
            },
            else => {},
        }
        event.event.ignore();
    }

    fn onLeave(self: *DrawTool, canvas: *CanvasWidget) void {
        _ = self;
        canvas.document.clearPreview();
    }

    fn updateMousePreview(self: *DrawTool, canvas: *CanvasWidget, mouse_x: f32, mouse_y: f32) void {
        const point = canvas.toDocumentSpace(mouse_x, mouse_y);
        self.edit_point.x = @floatToInt(i32, @floor(point.x));
        self.edit_point.y = @floatToInt(i32, @floor(point.y));
        canvas.document.previewBrush(self.edit_point.x, self.edit_point.y);
    }

    fn getCursor(self: DrawTool) fn () void {
        return if (self.picking) icons.cursorPipette else icons.cursorPen;
    }

    fn getStatusText(self: DrawTool, canvas: CanvasWidget, buf: []u8) [:0]const u8 {
        if (self.picking) {
            if (canvas.document.getColorAt(self.edit_point.x, self.edit_point.y)) |color| {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d}) R:{d:0>3} G:{d:0>3} B:{d:0>3} A:{d:0>3}",
                    .{
                        self.edit_point.x,
                        self.edit_point.y,
                        color[0],
                        color[1],
                        color[2],
                        color[3],
                    },
                ) catch unreachable;
            }
        }
        return std.fmt.bufPrintZ(
            buf[0..],
            "({d}, {d})",
            .{ self.edit_point.x, self.edit_point.y },
        ) catch unreachable;
    }
};

const FillTool = struct {
    edit_point: Pointi = Pointi{ .x = 0, .y = 0 },
    picking: bool = false,

    fn onMouseMove(self: *FillTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        _ = self;
        const point = canvas.toDocumentSpace(event.x, event.y);
        self.edit_point.x = @floatToInt(i32, @floor(point.x));
        self.edit_point.y = @floatToInt(i32, @floor(point.y));
    }

    fn onMouseDown(self: *FillTool, event: *const gui.MouseEvent) void {
        if (event.button == .right) {
            self.picking = true;
        }
    }

    fn onMouseUp(self: *FillTool, canvas: *CanvasWidget, event: *const gui.MouseEvent) void {
        if (event.button == .left) {
            canvas.document.floodFill(self.edit_point.x, self.edit_point.y) catch {
                gui.showMessageBox(.err, "Stroke", "Out of memory"); // TODO: nicer error message
            };
        } else if (event.button == .right) {
            canvas.document.pick(self.edit_point.x, self.edit_point.y);
            canvas.notifyColorChanged();
            self.picking = false;
        }
    }

    fn getCursor(self: FillTool) fn () void {
        return if (self.picking) icons.cursorPipette else icons.cursorBucket;
    }

    fn getStatusText(self: FillTool, canvas: CanvasWidget, buf: []u8) [:0]const u8 {
        if (self.picking) {
            if (canvas.document.getColorAt(self.edit_point.x, self.edit_point.y)) |color| {
                return std.fmt.bufPrintZ(
                    buf[0..],
                    "({d}, {d}) R:{d:0>3} G:{d:0>3} B:{d:0>3} A:{d:0>3}",
                    .{
                        self.edit_point.x,
                        self.edit_point.y,
                        color[0],
                        color[1],
                        color[2],
                        color[3],
                    },
                ) catch unreachable;
            }
        }
        return std.fmt.bufPrintZ(buf[0..], "({d}, {d})", .{ self.edit_point.x, self.edit_point.y }) catch unreachable;
    }
};

const CanvasWidget = @This();

widget: gui.Widget,
allocator: Allocator,

baseOnKeyDownFn: fn (*gui.Widget, *gui.KeyEvent) void,

tool: ToolType = .draw,
crop_tool: CropTool = CropTool{},
select_tool: SelectTool = SelectTool{},
draw_tool: DrawTool = DrawTool{},
fill_tool: FillTool = FillTool{},

document: *Document, // just a reference, owned by editor

horizontal_scrollbar: *gui.Scrollbar,
vertical_scrollbar: *gui.Scrollbar,

// view transform
translation: Pointf = Pointf.make(0, 0),
scale: f32 = 16,
pixel_grid_enabled: bool = false,
custom_grid_enabled: bool = false,
custom_grid_spacing_x: u32 = 8,
custom_grid_spacing_y: u32 = 8,
grid_snapping_enabled: bool = false,
document_background_image: nvg.Image,
grid_image: nvg.Image,
blue_grid_image: nvg.Image,

hovered: bool = false,
scroll_offset: ?Pointf = null, // in document space

onColorChangedFn: ?fn (*Self, [4]u8) void = null,
onScaleChangedFn: ?fn (*Self, f32) void = null,

pub const min_scale = 1.0 / 32.0;
pub const max_scale = 64.0;

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), document: *Document) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .baseOnKeyDownFn = undefined,
        .document = document,
        .horizontal_scrollbar = try gui.Scrollbar.init(allocator, Rect(f32).make(0, 160, 160, 16), .horizontal),
        .vertical_scrollbar = try gui.Scrollbar.init(allocator, Rect(f32).make(160, 0, 16, 160), .vertical),
        .document_background_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x66, 0x66, 0x66, 0xFF, 0x99, 0x99, 0x99, 0xFF,
            0x99, 0x99, 0x99, 0xFF, 0x66, 0x66, 0x66, 0xFF,
        }),
        .grid_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF,
        }),
        .blue_grid_image = nvg.createImageRgba(2, 2, .{ .repeat_x = true, .repeat_y = true, .nearest = true }, &.{
            0x00, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0xFF, 0xFF,
            0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF,
        }),
    };
    self.widget.focus_policy.keyboard = true;
    self.widget.focus_policy.mouse = true;

    self.widget.onResizeFn = onResize;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.onMouseWheelFn = onMouseWheel;
    self.widget.onTouchPanFn = onTouchPan;
    self.widget.onTouchZoomFn = onTouchZoom;
    self.baseOnKeyDownFn = self.widget.onKeyDownFn;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onKeyUpFn = onKeyUp;
    self.widget.onEnterFn = onEnter;
    self.widget.onLeaveFn = onLeave;
    self.widget.drawFn = draw;

    self.horizontal_scrollbar.onChangedFn = struct {
        fn changed(scrollbar: *gui.Scrollbar) void {
            const canvas = @fieldParentPtr(Self, "widget", scrollbar.widget.parent.?);
            const client_w = canvas.getClientRect().w;
            canvas.translation.x = @round(0.5 * client_w - scrollbar.value);
        }
    }.changed;
    self.vertical_scrollbar.onChangedFn = struct {
        fn changed(scrollbar: *gui.Scrollbar) void {
            const canvas = @fieldParentPtr(Self, "widget", scrollbar.widget.parent.?);
            const client_h = canvas.getClientRect().h;
            canvas.translation.y = @round(0.5 * client_h - scrollbar.value);
        }
    }.changed;

    try self.widget.addChild(&self.horizontal_scrollbar.widget);
    try self.widget.addChild(&self.vertical_scrollbar.widget);

    self.updateLayout();

    self.document.canvas = self;

    return self;
}

pub fn deinit(self: *Self) void {
    nvg.deleteImage(self.document_background_image);
    nvg.deleteImage(self.grid_image);
    nvg.deleteImage(self.blue_grid_image);
    self.horizontal_scrollbar.deinit();
    self.vertical_scrollbar.deinit();
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn setTool(self: *Self, tool: ToolType) void {
    if (self.tool != tool) {
        switch (self.tool) {
            .select => self.select_tool.onExit(self),
            .draw => self.draw_tool.onExit(self),
            else => {},
        }
        self.tool = tool;
        switch (self.tool) {
            .crop => self.crop_tool.onStart(),
            .select => self.select_tool.onStart(),
            else => {},
        }
    }
}

fn getClientRect(self: Self) Rectf {
    const rect = self.widget.getRect();
    return .{ .x = 0, .y = 0, .w = rect.w - gui.Scrollbar.button_size, .h = rect.h - gui.Scrollbar.button_size }; // without scrollbars
}

fn setTranslation(self: *Self, x: f32, y: f32) void {
    const client_rect = self.getClientRect();
    const document_w = self.scale * @intToFloat(f32, self.document.getWidth());
    const document_h = self.scale * @intToFloat(f32, self.document.getHeight());
    const min_x = 0.5 * client_rect.w - document_w;
    const min_y = 0.5 * client_rect.h - document_h;
    const max_x = 0.5 * client_rect.w;
    const max_y = 0.5 * client_rect.h;
    self.translation.x = @round(std.math.clamp(x, min_x, max_x));
    self.translation.y = @round(std.math.clamp(y, min_y, max_y));
    self.updateScrollbars();
}

pub fn translateByPixel(self: *Self, x: i32, y: i32) void {
    const dx = itof(x) * self.scale;
    const dy = itof(y) * self.scale;
    self.setTranslation(self.translation.x + dx, self.translation.y + dy);
}

fn updateScrollbars(self: *Self) void {
    const client_rect = self.getClientRect();
    const document_w = self.scale * @intToFloat(f32, self.document.getWidth());
    const document_h = self.scale * @intToFloat(f32, self.document.getHeight());
    const translation = self.translation;
    self.horizontal_scrollbar.setMaxValue(document_w);
    self.horizontal_scrollbar.setValue(0.5 * client_rect.w - translation.x);
    self.vertical_scrollbar.setMaxValue(document_h);
    self.vertical_scrollbar.setValue(0.5 * client_rect.h - translation.y);
}

pub fn centerDocument(self: *Self) void {
    const rect = self.widget.relative_rect;
    self.setTranslation(
        0.5 * (rect.w - self.scale * @intToFloat(f32, self.document.getWidth())),
        0.5 * (rect.h - self.scale * @intToFloat(f32, self.document.getHeight())),
    );
}

pub fn centerAndZoomDocument(self: *Self) void {
    const rect = self.widget.relative_rect;

    const fx = rect.w / @intToFloat(f32, self.document.getWidth());
    const fy = rect.h / @intToFloat(f32, self.document.getWidth());

    const visible_portion = 0.8;
    self.scale = visible_portion * std.math.min(fx, fy);
    self.scale = std.math.clamp(self.scale, min_scale, max_scale);
    self.notifyScaleChanged();

    self.centerDocument();
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = event;
    const self = @fieldParentPtr(Self, "widget", widget);
    self.updateLayout();
    self.updateScrollbars();
}

fn onMouseMove(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    // translate view
    if (event.isButtonPressed(.middle)) {
        if (self.scroll_offset) |scroll_offset| {
            const point = self.toDocumentSpace(event.x, event.y);
            const t = point.subtracted(scroll_offset);
            const gui_point = self.fromDocumentSpace(t.x, t.y);
            self.setTranslation(gui_point.x, gui_point.y);
        }
    }

    switch (self.tool) {
        .crop => self.crop_tool.onMouseMove(self, event),
        .select => self.select_tool.onMouseMove(self, event),
        .draw => self.draw_tool.onMouseMove(self, event),
        .fill => self.fill_tool.onMouseMove(self, event),
    }

    self.updateStatusBar();
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    if (event.isButtonPressed(.middle)) {
        self.scroll_offset = self.toDocumentSpace(event.x, event.y);
    }

    switch (self.tool) {
        .crop => self.crop_tool.onMouseDown(self, event),
        .select => self.select_tool.onMouseDown(self, event),
        .draw => self.draw_tool.onMouseDown(self, event),
        .fill => self.fill_tool.onMouseDown(event),
    }

    self.updateStatusBar();
}

fn onMouseUp(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);

    if (event.button == .middle) {
        self.scroll_offset = null;
    }

    switch (self.tool) {
        .crop => self.crop_tool.onMouseUp(self, event),
        .select => self.select_tool.onMouseUp(self, event),
        .draw => self.draw_tool.onMouseUp(self, event),
        .fill => self.fill_tool.onMouseUp(self, event),
    }

    self.updateStatusBar();
}

fn onMouseWheel(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    const zoom_factor = 1.25;
    const scroll_increment = 100;

    const up = event.wheel_y < 0;
    const down = event.wheel_y > 0;

    var self = @fieldParentPtr(Self, "widget", widget);

    if (event.isModifierPressed(.ctrl)) {
        if (up) {
            self.zoom(1.0 / zoom_factor, event.x, event.y);
        } else if (down) {
            self.zoom(zoom_factor, event.x, event.y);
        }
    } else if (event.isModifierPressed(.shift)) {
        if (up) {
            self.setTranslation(self.translation.x - scroll_increment, self.translation.y);
        } else if (down) {
            self.setTranslation(self.translation.x + scroll_increment, self.translation.y);
        }
    } else {
        if (up) {
            self.setTranslation(self.translation.x, self.translation.y - scroll_increment);
        } else if (down) {
            self.setTranslation(self.translation.x, self.translation.y + scroll_increment);
        }
    }
}

fn onTouchPan(widget: *gui.Widget, event: *const gui.TouchEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.setTranslation(self.translation.x + event.dx, self.translation.y + event.dy);
    self.updateToolMousePreview(event.x, event.y);
}

fn onTouchZoom(widget: *gui.Widget, event: *const gui.TouchEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    const factor = 1.0 + event.zoom;
    self.zoom(factor, event.x, event.y);
    self.updateToolMousePreview(event.x, event.y);
}

fn onKeyDown(widget: *gui.Widget, event: *gui.KeyEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.baseOnKeyDownFn(widget, event);
    if (event.event.is_accepted) return;
    switch (self.tool) {
        .crop => self.crop_tool.onKeyDown(self, event),
        .select => self.select_tool.onKeyDown(self, event),
        .draw => self.draw_tool.onKeyDown(self, event),
        else => event.event.ignore(),
    }
}

fn onKeyUp(widget: *gui.Widget, event: *gui.KeyEvent) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    switch (self.tool) {
        .draw => self.draw_tool.onKeyUp(self, event),
        else => event.event.ignore(),
    }
}

fn onEnter(widget: *gui.Widget) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.hovered = true;
}

fn onLeave(widget: *gui.Widget) void {
    var self = @fieldParentPtr(Self, "widget", widget);
    self.hovered = false;

    if (self.tool == .draw) self.draw_tool.onLeave(self);
}

fn updateLayout(self: *Self) void {
    const client_rect = self.getClientRect();
    self.horizontal_scrollbar.widget.setPosition(0, client_rect.h);
    self.horizontal_scrollbar.widget.setSize(client_rect.w + 1, gui.Scrollbar.button_size);
    self.vertical_scrollbar.widget.setPosition(client_rect.w, 0);
    self.vertical_scrollbar.widget.setSize(gui.Scrollbar.button_size, client_rect.h + 1);
    self.setTranslation(self.translation.x, self.translation.y); // update
}

fn updateToolMousePreview(self: *Self, mouse_x: f32, mouse_y: f32) void {
    switch (self.tool) {
        .crop => self.crop_tool.updateMousePreview(self, mouse_x, mouse_y),
        .select => self.select_tool.updateMousePreview(self, mouse_x, mouse_y),
        .draw => self.draw_tool.updateMousePreview(self, mouse_x, mouse_y),
        else => {},
    }
}

fn zoom(self: *Self, factor: f32, center_x: f32, center_y: f32) void {
    const prev_scale = self.scale;
    self.scale *= factor;
    self.scale = std.math.clamp(self.scale, min_scale, max_scale);
    if (self.scale != prev_scale) {
        self.notifyScaleChanged();

        // update translation
        const f = self.scale / prev_scale;
        const dx = self.translation.x - center_x;
        const dy = self.translation.y - center_y;
        self.setTranslation(
            self.translation.x + f * dx - dx,
            self.translation.y + f * dy - dy,
        );
    }
}

pub fn zoomToDocumentCenter(self: *Self, factor: f32) void {
    const center_x = self.translation.x + self.scale * 0.5 * @intToFloat(f32, self.document.getWidth());
    const center_y = self.translation.y + self.scale * 0.5 * @intToFloat(f32, self.document.getHeight());
    self.zoom(factor, center_x, center_y);
}

fn snap(self: Self, x: *f32, y: *f32) void {
    if (self.custom_grid_enabled and self.grid_snapping_enabled) {
        const fx = @intToFloat(f32, self.custom_grid_spacing_x);
        const fy = @intToFloat(f32, self.custom_grid_spacing_y);
        x.* = std.math.round(x.* / fx) * fx;
        y.* = std.math.round(y.* / fy) * fy;
    }
}

fn toDocumentSpace(self: Self, x: f32, y: f32) Pointf {
    return Pointf.make((x - self.translation.x) / self.scale, (y - self.translation.y) / self.scale);
}

fn fromDocumentSpace(self: Self, x: f32, y: f32) Pointf {
    return Pointf.make(x * self.scale + self.translation.x, y * self.scale + self.translation.y);
}

fn rectFromDocumentSpace(self: Self, rect: Rectf, snap_to_pixel: bool) Rectf {
    const p0 = self.fromDocumentSpace(rect.x, rect.y);
    const p1 = self.fromDocumentSpace(rect.x + rect.w, rect.y + rect.h);
    return if (snap_to_pixel)
        Rectf.make(@trunc(p0.x), @trunc(p0.y), @trunc(p1.x - p0.x), @trunc(p1.y - p0.y))
    else
        Rectf.make(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y);
}

fn notifyScaleChanged(self: *Self) void {
    if (self.onScaleChangedFn) |onScaleChanged| {
        onScaleChanged(self, self.scale);
    }
}

fn notifyColorChanged(self: *Self) void {
    if (self.onColorChangedFn) |onColorChanged| {
        onColorChanged(self, self.document.foreground_color);
    }
}

fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);
    const rect = widget.relative_rect;

    {
        nvg.save();
        defer nvg.restore();
        nvg.translate(rect.x, rect.y);
        nvg.scissor(0, 0, rect.w, rect.h);
        const client_rect = Rectf.make(0, 0, rect.w, rect.h);

        {
            nvg.save();
            defer nvg.restore();
            nvg.translate(self.translation.x, self.translation.y);

            self.drawDocumentBackground(Rectf.make(
                0,
                0,
                self.scale * @intToFloat(f32, self.document.getWidth()),
                self.scale * @intToFloat(f32, self.document.getHeight()),
            ));
            {
                // draw document
                nvg.save();
                defer nvg.restore();
                nvg.scale(self.scale, self.scale);
                self.document.draw();
            }

            if (self.document.selection) |selection| {
                self.drawSelection(selection, client_rect.translated(self.translation.scaled(-1)));
            } else {
                self.drawGrids();
            }
        }

        switch (self.tool) {
            .crop => self.crop_tool.drawPreview(self),
            .select => self.select_tool.drawPreview(self),
            else => {},
        }

        // set cursor
        if (widget.getWindow()) |window| {
            if (self.hovered) { // based on tool
                switch (self.tool) {
                    .crop => window.setCursor(self.crop_tool.getCursor()),
                    .select => window.setCursor(self.select_tool.getCursor(self)),
                    .draw => window.setCursor(self.draw_tool.getCursor()),
                    .fill => window.setCursor(self.fill_tool.getCursor()),
                }
            } else {
                window.setCursor(null);
            }
        }
    }

    nvg.beginPath();
    nvg.rect(rect.x + rect.w - 15, rect.y + rect.h - 15, 15, 15);
    nvg.fillColor(gui.theme_colors.background);
    nvg.fill();
    self.widget.drawChildren();
}

fn drawDocumentBackground(self: Self, rect: Rectf) void {
    nvg.beginPath();
    nvg.rect(rect.x, rect.y, rect.w, rect.h);
    nvg.fillPaint(nvg.imagePattern(0, 0, 8, 8, 0, self.document_background_image, 1));
    nvg.fill();
}

fn drawGrids(self: Self) void {
    if (self.pixel_grid_enabled and self.scale > 3) {
        nvg.beginPath();
        var x: u32 = 0;
        while (x <= self.document.getWidth()) : (x += 1) {
            const fx = @trunc(@intToFloat(f32, x) * self.scale);
            nvg.rect(fx, 0, 1, @intToFloat(f32, self.document.getHeight()) * self.scale);
        }
        var y: u32 = 0;
        while (y <= self.document.getHeight()) : (y += 1) {
            const fy = @trunc(@intToFloat(f32, y) * self.scale);
            nvg.rect(0, fy, @intToFloat(f32, self.document.getWidth()) * self.scale, 1);
        }
        nvg.fillPaint(nvg.imagePattern(0, 0, 2, 2, 0, self.grid_image, 0.5));
        nvg.fill();
    }

    if (self.custom_grid_enabled) {
        nvg.beginPath();
        if (self.scale * @intToFloat(f32, self.custom_grid_spacing_x) > 3) {
            var x: u32 = 0;
            while (x <= self.document.getWidth()) : (x += self.custom_grid_spacing_x) {
                const fx = @trunc(@intToFloat(f32, x) * self.scale);
                nvg.rect(fx, 0, 1, @intToFloat(f32, self.document.getHeight()) * self.scale);
            }
        }
        if (self.scale * @intToFloat(f32, self.custom_grid_spacing_y) > 3) {
            var y: u32 = 0;
            while (y <= self.document.getHeight()) : (y += self.custom_grid_spacing_y) {
                const fy = @trunc(@intToFloat(f32, y) * self.scale);
                nvg.rect(0, fy, @intToFloat(f32, self.document.getWidth()) * self.scale, 1);
            }
        }
        nvg.fillPaint(nvg.imagePattern(0, 0, 2, 2, 0, self.blue_grid_image, 0.5));
        nvg.fill();
    }
}

fn drawSelection(self: Self, selection: Document.Selection, rect: Rect(f32)) void {
    const document_rect = Rectf.make(0, 0, @intToFloat(f32, self.document.getWidth()), @intToFloat(f32, self.document.getHeight()));
    const selection_rect = Rectf.make(
        @intToFloat(f32, selection.rect.x),
        @intToFloat(f32, selection.rect.y),
        @intToFloat(f32, selection.rect.w),
        @intToFloat(f32, selection.rect.h),
    );
    const s = self.scale;
    const x0 = @trunc(selection_rect.x * s);
    const y0 = @trunc(selection_rect.y * s);
    const x1 = @trunc((selection_rect.x + selection_rect.w) * s);
    const y1 = @trunc((selection_rect.y + selection_rect.h) * s);
    {
        nvg.save();
        defer nvg.restore();
        if (self.document.blend_mode == .replace) {
            const intersection = rect.intersection(document_rect.intersection(selection_rect).scaled(s));
            nvg.scissor(intersection.x, intersection.y, intersection.w, intersection.h);
            self.drawDocumentBackground(selection_rect.scaled(s));
        }
        nvg.scale(s, s);
        const intersection = rect.scaled(1 / s).intersection(document_rect.intersection(selection_rect));
        nvg.scissor(intersection.x, intersection.y, intersection.w, intersection.h);
        nvg.beginPath();
        nvg.rect(selection_rect.x, selection_rect.y, selection_rect.w, selection_rect.h);
        nvg.fillPaint(nvg.imagePattern(selection_rect.x, selection_rect.y, selection_rect.w, selection_rect.h, 0, selection.texture, 1));
        nvg.fill();
    }

    self.drawGrids();

    // draw selection border on top of grid
    nvg.beginPath();
    nvg.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
    nvg.pathWinding(.cw);
    nvg.rect(x0 + 1, y0 + 1, x1 - x0 - 1, y1 - y0 - 1);
    nvg.pathWinding(.ccw);
    nvg.fillPaint(nvg.imagePattern(0, 0, 4, 4, 0, self.grid_image, 1));
    nvg.fill();
}

fn updateStatusBar(self: Self) void {
    if (self.widget.parent) |parent| {
        var editor = @fieldParentPtr(EditorWidget, "widget", parent);

        editor.tool_status_label.text = switch (self.tool) {
            .crop => self.crop_tool.getStatusText(editor.tool_text[0..]),
            .select => self.select_tool.getStatusText(self, editor.tool_text[0..]),
            .draw => self.draw_tool.getStatusText(self, editor.tool_text[0..]),
            .fill => self.fill_tool.getStatusText(self, editor.tool_text[0..]),
        };
    }
}

fn updateImageStatus(self: Self) void {
    if (self.widget.parent) |parent| {
        var editor = @fieldParentPtr(EditorWidget, "widget", parent);
        editor.updateImageStatus();
    }
}
