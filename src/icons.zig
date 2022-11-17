const std = @import("std");
const nvg = @import("nanovg");

pub fn iconNew(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(2.5, 0.5);
    vg.lineTo(2.5, 15.5);
    vg.lineTo(13.5, 15.5);
    vg.lineTo(13.5, 3.5);
    vg.lineTo(10.5, 0.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(8.5, 0.5);
    vg.lineTo(8.5, 5.5);
    vg.lineTo(13.5, 5.5);
    vg.stroke();
}

pub fn iconOpen(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(1.5, 1.5);
    vg.lineTo(0.5, 2.5);
    vg.lineTo(0.5, 14.5);
    vg.lineTo(12.5, 14.5);
    vg.lineTo(13.5, 13.5);
    vg.lineTo(15.5, 8.5);
    vg.lineTo(15.5, 7.5);
    vg.lineTo(13.5, 7.5);
    vg.lineTo(13.5, 2.5);
    vg.lineTo(6.5, 2.5);
    vg.lineTo(5.5, 1.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(245, 218, 97));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(13.5, 7.5);
    vg.lineTo(4.5, 7.5);
    vg.lineTo(2.5, 12.5);
    vg.stroke();
}

pub fn iconSave(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(0.5, 0.5);
    vg.lineTo(0.5, 14.5);
    vg.lineTo(1.5, 15.5);
    vg.lineTo(15.5, 15.5);
    vg.lineTo(15.5, 0.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(40, 140, 200));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(3, 10);
    vg.lineTo(3, 15);
    vg.lineTo(13, 15);
    vg.lineTo(13, 10);
    vg.fillColor(nvg.rgb(171, 171, 171));
    vg.fill();
    vg.beginPath();
    vg.moveTo(4, 11);
    vg.lineTo(4, 14);
    vg.lineTo(6, 14);
    vg.lineTo(6, 11);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.moveTo(3, 1);
    vg.lineTo(3, 8);
    vg.lineTo(13, 8);
    vg.lineTo(13, 1);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.beginPath();
    vg.moveTo(3, 1);
    vg.lineTo(3, 2);
    vg.lineTo(13, 2);
    vg.lineTo(13, 1);
    vg.fillColor(nvg.rgb(250, 10, 0));
    vg.fill();
    vg.beginPath();
    vg.moveTo(4, 3);
    vg.lineTo(4, 5);
    vg.lineTo(12, 5);
    vg.lineTo(12, 3);
    vg.moveTo(4, 6);
    vg.lineTo(4, 7);
    vg.lineTo(12, 7);
    vg.lineTo(12, 6);
    vg.fillColor(nvg.rgb(224, 224, 224));
    vg.fill();
}

pub fn iconSaveAs(vg: nvg) void {
    vg.save();
    defer vg.restore();
    iconSave(vg);
    vg.translate(1, 1);
    iconToolPen(vg);
}

pub fn iconUndoEnabled(vg: nvg) void {
    iconUndo(vg, true);
}

pub fn iconUndoDisabled(vg: nvg) void {
    iconUndo(vg, false);
}

fn iconUndo(vg: nvg, enabled: bool) void {
    vg.beginPath();
    vg.arc(8, 8, 6, -0.75 * std.math.pi, 0.75 * std.math.pi, .cw);
    vg.lineCap(.round);
    vg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    vg.strokeWidth(4);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(0.5, 7.5);
    vg.lineTo(0.5, 0.5);
    vg.lineTo(1.5, 0.5);
    vg.lineTo(7.5, 6.5);
    vg.lineTo(7.5, 7.5);
    vg.closePath();
    vg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    vg.fill();
    vg.strokeWidth(1);
    vg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.arc(8, 8, 6, -0.75 * std.math.pi, 0.75 * std.math.pi, .cw);
    vg.strokeColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    vg.strokeWidth(2);
    vg.stroke();
    // reset
    vg.lineCap(.butt);
    vg.strokeWidth(1);
}

pub fn iconRedoEnabled(vg: nvg) void {
    iconRedo(vg, true);
}

pub fn iconRedoDisabled(vg: nvg) void {
    iconRedo(vg, false);
}

fn iconRedo(vg: nvg, enabled: bool) void {
    vg.beginPath();
    vg.arc(8, 8, 6, -0.25 * std.math.pi, 0.25 * std.math.pi, .ccw);
    vg.lineCap(.round);
    vg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    vg.strokeWidth(4);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(15.5, 7.5);
    vg.lineTo(15.5, 0.5);
    vg.lineTo(14.5, 0.5);
    vg.lineTo(8.5, 6.5);
    vg.lineTo(8.5, 7.5);
    vg.closePath();
    vg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    vg.fill();
    vg.strokeWidth(1);
    vg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.arc(8, 8, 6, -0.25 * std.math.pi, 0.25 * std.math.pi, .ccw);
    vg.strokeColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    vg.strokeWidth(2);
    vg.stroke();
    // reset
    vg.lineCap(.butt);
    vg.strokeWidth(1);
}

pub fn iconCut(vg: nvg) void {
    vg.beginPath();
    vg.ellipse(4, 13, 2, 2);
    vg.ellipse(12, 13, 2, 2);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.strokeWidth(2);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(10, 10);
    vg.lineTo(4.5, 0.5);
    vg.lineTo(3.5, 0.5);
    vg.lineTo(3.5, 3.5);
    vg.lineTo(3.5, 3.5);
    vg.lineTo(7, 10);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.strokeWidth(1);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(6, 10);
    vg.lineTo(11.5, 0.5);
    vg.lineTo(12.5, 0.5);
    vg.lineTo(12.5, 3.5);
    vg.lineTo(12.5, 3.5);
    vg.lineTo(9, 10);
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.moveTo(6, 9);
    vg.lineTo(4.5, 10.5);
    vg.lineTo(7, 13);
    vg.lineTo(7, 11.5);
    vg.lineTo(7.5, 11);
    vg.lineTo(8.5, 11);
    vg.lineTo(9, 11.5);
    vg.lineTo(9, 13);
    vg.lineTo(11.5, 10.5);
    vg.lineTo(10, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconCopyEnabled(vg: nvg) void {
    iconCopy(vg, true);
}

pub fn iconCopyDisabled(vg: nvg) void {
    iconCopy(vg, false);
}

pub fn iconCopy(vg: nvg, enabled: bool) void {
    for ([_]u0{ 0, 0 }) |_| {
        vg.beginPath();
        vg.moveTo(2.5, 0.5);
        vg.lineTo(2.5, 10.5);
        vg.lineTo(10.5, 10.5);
        vg.lineTo(10.5, 2.5);
        vg.lineTo(8.5, 0.5);
        vg.closePath();
        vg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(224, 224, 224));
        vg.fill();
        vg.strokeColor(if (enabled) nvg.rgb(66, 66, 66) else nvg.rgb(170, 170, 170));
        vg.stroke();
        vg.beginPath();
        vg.moveTo(7.5, 0.5);
        vg.lineTo(7.5, 3.5);
        vg.lineTo(10.5, 3.5);
        vg.stroke();
        vg.translate(3, 5);
    }
}

pub fn iconPasteEnabled(vg: nvg) void {
    iconPaste(vg, true);
}

pub fn iconPasteDisabled(vg: nvg) void {
    iconPaste(vg, false);
}

pub fn iconPaste(vg: nvg, enabled: bool) void {
    const stroke_color = if (enabled) nvg.rgb(66, 66, 66) else nvg.rgb(170, 170, 170);
    vg.beginPath();
    vg.roundedRect(1.5, 1.5, 13, 14, 1.5);
    vg.fillColor(if (enabled) nvg.rgb(215, 162, 71) else stroke_color);
    vg.fill();
    vg.strokeColor(stroke_color);
    vg.stroke();
    vg.beginPath();
    vg.rect(3.5, 3.5, 9, 10);
    vg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(224, 224, 224)); // TODO: use gui constant or alpha
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.moveTo(6.5, 0.5);
    vg.lineTo(6.5, 1.5);
    vg.lineTo(5.5, 2.5);
    vg.lineTo(5.5, 4.5);
    vg.lineTo(10.5, 4.5);
    vg.lineTo(10.5, 2.5);
    vg.lineTo(9.5, 1.5);
    vg.lineTo(9.5, 0.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(170, 170, 170));
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.rect(5, 6, 6, 1);
    vg.rect(5, 8, 4, 1);
    vg.rect(5, 10, 5, 1);
    vg.fillColor(stroke_color);
    vg.fill();
}

pub fn iconToolCrop(vg: nvg) void {
    vg.fillColor(nvg.rgb(170, 170, 170));
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.beginPath();
    vg.moveTo(2.5, 0.5);
    vg.lineTo(2.5, 13.5);
    vg.lineTo(15.5, 13.5);
    vg.lineTo(15.5, 10.5);
    vg.lineTo(5.5, 10.5);
    vg.lineTo(5.5, 0.5);
    vg.closePath();
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.moveTo(0.5, 5.5);
    vg.lineTo(10.5, 5.5);
    vg.lineTo(10.5, 15.5);
    vg.lineTo(13.5, 15.5);
    vg.lineTo(13.5, 2.5);
    vg.lineTo(0.5, 2.5);
    vg.closePath();
    vg.fill();
    vg.stroke();
}

pub fn iconToolSelect(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(1.5, 4);
    vg.lineTo(1.5, 1.5);
    vg.lineTo(4, 1.5);
    vg.moveTo(6, 1.5);
    vg.lineTo(10, 1.5);
    vg.moveTo(12, 1.5);
    vg.lineTo(14.5, 1.5);
    vg.lineTo(14.5, 4);
    vg.moveTo(14.5, 6);
    vg.lineTo(14.5, 10);
    vg.moveTo(14.5, 12);
    vg.lineTo(14.5, 14.5);
    vg.lineTo(12, 14.5);
    vg.moveTo(10, 14.5);
    vg.lineTo(6, 14.5);
    vg.moveTo(4, 14.5);
    vg.lineTo(1.5, 14.5);
    vg.lineTo(1.5, 12);
    vg.moveTo(1.5, 10);
    vg.lineTo(1.5, 6);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconToolLine(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(13, 1);
    vg.lineTo(5, 5);
    vg.lineTo(10, 10);
    vg.lineTo(2, 14);
    vg.lineCap(.Round);
    defer vg.lineCap(.Butt);
    vg.strokeWidth(2);
    defer vg.strokeWidth(1);
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
}

pub fn iconToolPen(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(5.5, 14.5);
    vg.lineTo(5.5, 12.5);
    vg.lineTo(15.5, 2.5);
    vg.lineTo(15.5, 4.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(68, 137, 26));
    vg.fill();

    vg.beginPath();
    vg.moveTo(5.5, 12.5);
    vg.lineTo(3.5, 10.5);
    vg.lineTo(13.5, 0.5);
    vg.lineTo(15.5, 2.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(163, 206, 39));
    vg.fill();

    vg.beginPath();
    vg.moveTo(3.5, 10.5);
    vg.lineTo(1.5, 10.5);
    vg.lineTo(11.5, 0.5);
    vg.lineTo(13.5, 0.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(213, 228, 102));
    vg.fill();

    vg.lineJoin(.round);
    defer vg.lineJoin(.miter);

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1.5, 10.5);
    vg.lineTo(11.5, 0.5);
    vg.lineTo(13.5, 0.5);
    vg.lineTo(15.5, 2.5);
    vg.lineTo(15.5, 4.5);
    vg.lineTo(5.5, 14.5);
    vg.closePath();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1.5, 10.5);
    vg.lineTo(3.5, 10.5);
    vg.lineTo(5.5, 12.5);
    vg.lineTo(5.5, 14.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(217, 190, 138));
    vg.fill();
    vg.stroke();

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1, 13.5);
    vg.lineTo(2.5, 15);
    vg.closePath();
    vg.stroke();
}

pub fn iconToolBucket(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(9.5, 2.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(8.5, 13.5);
    vg.bezierTo(9.5, 14.5, 11.5, 14.5, 12.5, 13.5);
    vg.lineTo(14.5, 11.5);
    vg.bezierTo(15.5, 10.5, 15.5, 8.5, 14.5, 7.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(171, 171, 171));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(4.5, 9.5);
    vg.lineTo(10.5, 3.5);
    vg.stroke();
    vg.beginPath();
    vg.roundedRect(8.5, 0.5, 2, 9, 1);
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.ellipse(9.5, 8.5, 1, 1);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(3.5, 10.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(6.5, 5.5);
    vg.lineTo(5, 5.5);
    vg.bezierTo(2, 5.5, 0.5, 7, 0.5, 10.5);
    vg.bezierTo(0.5, 12, 1, 12.5, 2, 12.5);
    vg.bezierTo(3, 12.5, 3.5, 12, 3.5, 10.5);
    vg.fillColor(nvg.rgb(210, 80, 60));
    vg.fill();
    vg.stroke();
}

pub fn iconMirrorHorizontally(vg: nvg) void {
    vg.beginPath();
    var y: f32 = 0;
    while (y < 16) : (y += 2) {
        vg.moveTo(7.5, y + 0);
        vg.lineTo(7.5, y + 1);
    }
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(5, 2);
    vg.lineTo(5, 3);
    vg.lineTo(9, 3);
    vg.lineTo(9, 5);
    vg.lineTo(11.5, 2.5);
    vg.lineTo(9, 0);
    vg.lineTo(9, 2);
    vg.closePath();
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(0.5, 5.5, 5, 5);
    vg.strokeColor(nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.rect(9.5, 5.5, 5, 5);
    vg.fillColor(nvg.rgb(247, 226, 107));
    vg.fill();
    vg.strokeColor(nvg.rgb(164, 100, 34));
    vg.stroke();
}

pub fn iconMirrorVertically(vg: nvg) void {
    vg.save();
    defer vg.restore();
    vg.scale(-1, 1);
    vg.rotate(0.5 * std.math.pi);
    iconMirrorHorizontally(vg);
}

pub fn iconRotateCw(vg: nvg) void {
    vg.beginPath();
    vg.rect(1.5, 8.5, 14, 6);
    vg.strokeColor(nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.rect(9.5, 0.5, 6, 14);
    vg.fillColor(nvg.rgb(247, 226, 107));
    vg.fill();
    vg.strokeColor(nvg.rgb(164, 100, 34));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(3.5, 7);
    vg.quadTo(3.5, 4.5, 6, 4.5);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(6, 7.5);
    vg.lineTo(9, 4.5);
    vg.lineTo(6, 1.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconRotateCcw(vg: nvg) void {
    vg.beginPath();
    vg.rect(0.5, 8.5, 14, 6);
    vg.strokeColor(nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.rect(0.5, 0.5, 6, 14);
    vg.fillColor(nvg.rgb(247, 226, 107));
    vg.fill();
    vg.strokeColor(nvg.rgb(164, 100, 34));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(12.5, 7);
    vg.quadTo(12.5, 4.5, 10, 4.5);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(10, 7.5);
    vg.lineTo(7, 4.5);
    vg.lineTo(10, 1.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconPixelGrid(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(0, 0.5);
    vg.lineTo(16, 0.5);
    vg.moveTo(0, 5.5);
    vg.lineTo(16, 5.5);
    vg.moveTo(0, 10.5);
    vg.lineTo(16, 10.5);
    vg.moveTo(0, 15.5);
    vg.lineTo(16, 15.5);
    vg.moveTo(0.5, 0);
    vg.lineTo(0.5, 16);
    vg.moveTo(5.5, 0);
    vg.lineTo(5.5, 16);
    vg.moveTo(10.5, 0);
    vg.lineTo(10.5, 16);
    vg.moveTo(15.5, 0);
    vg.lineTo(15.5, 16);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconCustomGrid(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(1, 2.5);
    vg.lineTo(4, 2.5);
    vg.moveTo(5, 2.5);
    vg.lineTo(7, 2.5);
    vg.moveTo(8, 2.5);
    vg.lineTo(10, 2.5);
    vg.moveTo(11, 2.5);
    vg.lineTo(14, 2.5);
    vg.moveTo(1, 12.5);
    vg.lineTo(4, 12.5);
    vg.moveTo(5, 12.5);
    vg.lineTo(7, 12.5);
    vg.moveTo(8, 12.5);
    vg.lineTo(10, 12.5);
    vg.moveTo(11, 12.5);
    vg.lineTo(14, 12.5);
    vg.moveTo(2.5, 1);
    vg.lineTo(2.5, 4);
    vg.moveTo(2.5, 5);
    vg.lineTo(2.5, 7);
    vg.moveTo(2.5, 8);
    vg.lineTo(2.5, 10);
    vg.moveTo(2.5, 11);
    vg.lineTo(2.5, 14);
    vg.moveTo(12.5, 1);
    vg.lineTo(12.5, 4);
    vg.moveTo(12.5, 5);
    vg.lineTo(12.5, 7);
    vg.moveTo(12.5, 8);
    vg.lineTo(12.5, 10);
    vg.moveTo(12.5, 11);
    vg.lineTo(12.5, 14);
    vg.strokeColor(nvg.rgb(40, 140, 200));
    vg.stroke();
}

pub fn iconSnapEnabled(vg: nvg) void {
    iconSnap(vg, true);
}

pub fn iconSnapDisabled(vg: nvg) void {
    iconSnap(vg, false);
}

pub fn iconSnap(vg: nvg, enabled: bool) void {
    vg.beginPath();
    vg.moveTo(1.5, 0.5);
    vg.lineTo(1.5, 12.5);
    vg.lineTo(2.5, 14.5);
    vg.lineTo(4.5, 15.5);
    vg.lineTo(11.5, 15.5);
    vg.lineTo(13.5, 14.5);
    vg.lineTo(14.5, 12.5);
    vg.lineTo(14.5, 0.5);
    vg.lineTo(10.5, 0.5);
    vg.lineTo(10.5, 10.5);
    vg.lineTo(9.5, 11.5);
    vg.lineTo(6.5, 11.5);
    vg.lineTo(5.5, 10.5);
    vg.lineTo(5.5, 0.5);
    vg.closePath();
    vg.fillColor(if (enabled) nvg.rgb(250, 8, 0) else nvg.rgb(170, 170, 170));
    vg.fill();
    vg.strokeColor(if (enabled) nvg.rgb(66, 66, 66) else nvg.rgb(170, 170, 170));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(2, 1);
    vg.lineTo(2, 4);
    vg.lineTo(5, 4);
    vg.lineTo(5, 1);
    vg.moveTo(11, 1);
    vg.lineTo(11, 4);
    vg.lineTo(14, 4);
    vg.lineTo(14, 1);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconAbout(vg: nvg) void {
    vg.beginPath();
    vg.ellipse(8, 8, 6.5, 6.5);
    vg.fillColor(nvg.rgb(40, 140, 200));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();

    vg.beginPath();
    vg.ellipse(8, 5, 1, 1);
    vg.moveTo(6, 12);
    vg.lineTo(10, 12);
    vg.lineTo(10, 11);
    vg.lineTo(9, 11);
    vg.lineTo(9, 7);
    vg.lineTo(6, 7);
    vg.lineTo(6, 8);
    vg.lineTo(7, 8);
    vg.lineTo(7, 11);
    vg.lineTo(6, 11);
    vg.closePath();
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
}

pub fn iconColorPalette(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(8, 1.5);
    vg.bezierTo(12, 1.5, 15.5, 4, 15.5, 8);
    vg.bezierTo(15.5, 12, 12, 14.5, 8, 14.5);
    vg.bezierTo(4, 14.5, 4, 11.5, 3, 10.5);
    vg.bezierTo(2, 9.5, 0.5, 10, 0.5, 8);
    vg.bezierTo(0.5, 4, 4, 1.5, 8, 1.5);
    vg.closePath();
    vg.pathWinding(.ccw);
    vg.circle(7, 11, 1.5);
    vg.pathWinding(.cw);
    vg.fillColor(nvg.rgb(245, 218, 97));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.circle(4, 7, 2);
    vg.fillColor(nvg.rgb(250, 10, 0));
    vg.fill();
    vg.beginPath();
    vg.circle(8, 5, 2);
    vg.fillColor(nvg.rgb(30, 170, 15));
    vg.fill();
    vg.beginPath();
    vg.circle(12, 7, 2);
    vg.fillColor(nvg.rgb(40, 140, 200));
    vg.fill();
}

pub fn iconPlus(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(10.5, 8.5);
    vg.lineTo(10.5, 10.5);
    vg.lineTo(8.5, 10.5);
    vg.lineTo(8.5, 13.5);
    vg.lineTo(10.5, 13.5);
    vg.lineTo(10.5, 15.5);
    vg.lineTo(13.5, 15.5);
    vg.lineTo(13.5, 13.5);
    vg.lineTo(15.5, 13.5);
    vg.lineTo(15.5, 10.5);
    vg.lineTo(13.5, 10.5);
    vg.lineTo(13.5, 8.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(60, 175, 45));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconMinus(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(8.5, 10.5);
    vg.lineTo(8.5, 13.5);
    vg.lineTo(15.5, 13.5);
    vg.lineTo(15.5, 10.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(250, 10, 0));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconDelete(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(7, 0.5);
    vg.lineTo(6.5, 1);
    vg.lineTo(6.5, 2.5);
    vg.lineTo(3, 2.5);
    vg.lineTo(2.5, 3);
    vg.lineTo(2.5, 5.5);
    vg.lineTo(3.5, 5.5);
    vg.lineTo(3.5, 15);
    vg.lineTo(4, 15.5);
    vg.lineTo(12, 15.5);
    vg.lineTo(12.5, 15);
    vg.lineTo(12.5, 5.5);
    vg.lineTo(13.5, 5.5);
    vg.lineTo(13.5, 3);
    vg.lineTo(13, 2.5);
    vg.lineTo(9.5, 2.5);
    vg.lineTo(9.5, 1);
    vg.lineTo(9, 0.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(170, 170, 170));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.moveTo(6.5, 2.5);
    vg.lineTo(9.5, 2.5);
    vg.moveTo(3.5, 5.5);
    vg.lineTo(12.5, 5.5);
    vg.moveTo(6.5, 7);
    vg.lineTo(6.5, 14);
    vg.moveTo(9.5, 7);
    vg.lineTo(9.5, 14);
    vg.stroke();
}

pub fn iconMoveUp(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(8, 1);
    vg.lineTo(1.5, 7.5);
    vg.lineTo(1.5, 9.5);
    vg.lineTo(4.5, 9.5);
    vg.lineTo(4.5, 14.5);
    vg.lineTo(11.5, 14.5);
    vg.lineTo(11.5, 9.5);
    vg.lineTo(14.5, 9.5);
    vg.lineTo(14.5, 7.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconMoveDown(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(8, 15);
    vg.lineTo(14.5, 8.5);
    vg.lineTo(14.5, 6.5);
    vg.lineTo(11.5, 6.5);
    vg.lineTo(11.5, 1.5);
    vg.lineTo(4.5, 1.5);
    vg.lineTo(4.5, 6.5);
    vg.lineTo(1.5, 6.5);
    vg.lineTo(1.5, 8.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconCapButt(vg: nvg) void {
    vg.beginPath();
    vg.rect(7, 0, 8, 15);
    vg.rect(5, 5, 5, 5);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconCapRound(vg: nvg) void {
    vg.beginPath();
    vg.rect(7.5, 0, 7.5, 15);
    vg.circle(7.5, 7.5, 7.5);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconCapSquare(vg: nvg) void {
    vg.beginPath();
    vg.rect(0, 0, 15, 15);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconJoinRound(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(15, 15);
    vg.lineTo(15, 0);
    vg.arcTo(0, 0, 0, 7.5, 7.5);
    vg.lineTo(0, 15);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(7, 7, 1, 8);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconJoinBevel(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(15, 15);
    vg.lineTo(15, 0);
    vg.lineTo(7.5, 0);
    vg.lineTo(0, 7.5);
    vg.lineTo(0, 15);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(7, 7, 1, 8);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconJoinSquare(vg: nvg) void {
    vg.beginPath();
    vg.rect(0, 0, 15, 15);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.rect(7, 7, 8, 1);
    vg.rect(7, 7, 1, 8);
    vg.rect(6, 6, 3, 3);
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
}

pub fn iconCross(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(4, 4);
    vg.lineTo(11, 11);
    vg.moveTo(4, 11);
    vg.lineTo(11, 4);
    vg.lineCap(.Round);
    defer vg.lineCap(.Butt);
    vg.strokeWidth(2);
    defer vg.strokeWidth(1);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn iconTimelineBegin(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(11, 2);
    vg.lineTo(11, 11);
    vg.lineTo(2, 6.5);
    vg.closePath();
    vg.rect(2, 2, 1, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconTimelineLeft(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(6, 2);
    vg.lineTo(6, 11);
    vg.lineTo(1.5, 6.5);
    vg.closePath();
    vg.rect(7, 2, 2, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconTimelinePlay(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(2, 2);
    vg.lineTo(2, 11);
    vg.lineTo(11, 6.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconTimelinePause(vg: nvg) void {
    vg.beginPath();
    vg.rect(4, 2, 2, 9);
    vg.rect(7, 2, 2, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconTimelineRight(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(7, 2);
    vg.lineTo(7, 11);
    vg.lineTo(11.5, 6.5);
    vg.closePath();
    vg.rect(4, 2, 2, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconTimelineEnd(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(2, 2);
    vg.lineTo(2, 11);
    vg.lineTo(11, 6.5);
    vg.closePath();
    vg.rect(10, 2, 1, 9);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
}

pub fn iconOnionSkinning(vg: nvg) void {
    vg.beginPath();
    vg.rect(1.5, 1.5, 9, 9);
    vg.fillColor(nvg.rgb(203, 219, 252));
    vg.fill();
    vg.strokeColor(nvg.rgb(95, 205, 228));
    vg.stroke();
    vg.beginPath();
    vg.rect(5.5, 5.5, 9, 9);
    vg.fillColor(nvg.rgb(99, 155, 255));
    vg.fill();
    vg.strokeColor(nvg.rgb(48, 96, 130));
    vg.stroke();
}

pub fn iconEyeOpen(vg: nvg) void {
    vg.lineJoin(.round);
    defer vg.lineJoin(.miter);
    vg.beginPath();
    vg.moveTo(0.5, 8);
    vg.bezierTo(5.5, 3, 10.5, 3, 15.5, 8);
    vg.bezierTo(10.5, 13, 5.5, 13, 0.5, 8);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.ellipse(8, 8, 3.5, 3.5);
    vg.fillColor(nvg.rgb(30, 170, 15));
    vg.fill();
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
    vg.beginPath();
    vg.ellipse(8, 8, 2, 2);
    vg.fillColor(nvg.rgb(66, 66, 66));
    vg.fill();
    vg.beginPath();
    vg.ellipse(9, 7, 1, 1);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
}

pub fn iconEyeClosed(vg: nvg) void {
    vg.lineCap(.round);
    defer vg.lineCap(.butt);
    vg.beginPath();
    vg.moveTo(15.5, 8);
    vg.bezierTo(10.5, 13, 5.5, 13, 0.5, 8);
    vg.strokeColor(nvg.rgb(66, 66, 66));
    vg.stroke();
}

pub fn cursorArrow(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(-0.5, -0.5);
    vg.lineTo(-0.5, 12.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(8.5, 8.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
    vg.strokeColor(nvg.rgb(255, 255, 255));
    vg.stroke();
}

pub fn cursorArrowInverted(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(-0.5, -0.5);
    vg.lineTo(-0.5, 12.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(8.5, 8.5);
    vg.closePath();
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fill();
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
}

pub fn cursorCrosshair(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(-5.5, 0.5);
    vg.lineTo(-2.5, 0.5);
    vg.moveTo(3.5, 0.5);
    vg.lineTo(6.5, 0.5);
    vg.moveTo(0.5, -5.5);
    vg.lineTo(0.5, -2.5);
    vg.moveTo(0.5, 3.5);
    vg.lineTo(0.5, 6.5);
    vg.lineCap(.square);
    defer vg.lineCap(.butt);
    vg.strokeColor(nvg.rgbf(1, 1, 1));
    vg.strokeWidth(2);
    vg.stroke();
    vg.strokeWidth(1);
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
    vg.beginPath();
    vg.rect(-0.5, -0.5, 2, 2);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
    vg.beginPath();
    vg.rect(0, 0, 1, 1);
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fill();
}

pub fn cursorPen(vg: nvg) void {
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.save();
    vg.scale(1, -1);
    vg.translate(0, -16);
    vg.lineJoin(.round);
    defer vg.restore();

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1.5, 10.5);
    vg.lineTo(11.5, 0.5);
    vg.lineTo(13.5, 0.5);
    vg.lineTo(15.5, 2.5);
    vg.lineTo(15.5, 4.5);
    vg.lineTo(5.5, 14.5);
    vg.closePath();
    vg.fill();
    vg.stroke();

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1.5, 10.5);
    vg.lineTo(3.5, 10.5);
    vg.lineTo(5.5, 12.5);
    vg.lineTo(5.5, 14.5);
    vg.closePath();
    vg.fill();
    vg.stroke();

    vg.beginPath();
    vg.moveTo(0.5, 15.5);
    vg.lineTo(1, 13.5);
    vg.lineTo(2.5, 15);
    vg.closePath();
    vg.stroke();
}

pub fn cursorBucket(vg: nvg) void {
    cursorCrosshair(vg);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.save();
    defer vg.restore();
    vg.translate(3, -15);
    vg.beginPath();
    vg.moveTo(9.5, 2.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(8.5, 13.5);
    vg.bezierTo(9.5, 14.5, 11.5, 14.5, 12.5, 13.5);
    vg.lineTo(14.5, 11.5);
    vg.bezierTo(15.5, 10.5, 15.5, 8.5, 14.5, 7.5);
    vg.closePath();
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.moveTo(4.5, 9.5);
    vg.lineTo(10.5, 3.5);
    vg.stroke();
    vg.beginPath();
    vg.roundedRect(8.5, 0.5, 2, 9, 1);
    vg.fill();
    vg.stroke();
    vg.beginPath();
    vg.ellipse(9.5, 8.5, 1, 1);
    vg.stroke();
    vg.beginPath();
    vg.moveTo(3.5, 10.5);
    vg.lineTo(3.5, 8.5);
    vg.lineTo(6.5, 5.5);
    vg.lineTo(5, 5.5);
    vg.bezierTo(2, 5.5, 0.5, 7, 0.5, 10.5);
    vg.bezierTo(0.5, 12, 1, 12.5, 2, 12.5);
    vg.bezierTo(3, 12.5, 3.5, 12, 3.5, 10.5);
    vg.fill();
    vg.stroke();
}

pub fn cursorPipette(vg: nvg) void {
    vg.save();
    defer vg.restore();
    vg.translate(0, -15);

    vg.lineJoin(.round);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.strokeColor(nvg.rgb(0, 0, 0));

    vg.beginPath();
    vg.moveTo(10.5, 3.5);
    vg.lineTo(1.5, 12.5);
    vg.lineTo(1.5, 13.5);
    vg.lineTo(0.5, 14.5);
    vg.lineTo(0.5, 15.5);
    vg.lineTo(1.5, 15.5);
    vg.lineTo(2.5, 14.5);
    vg.lineTo(3.5, 14.5);
    vg.lineTo(12.5, 5.5);
    vg.fill();
    vg.stroke();

    vg.beginPath();
    vg.moveTo(11.5, 6.5);
    vg.lineTo(13.5, 6.5);
    vg.lineTo(13.5, 4.5);
    vg.lineTo(14.5, 3.5);
    vg.lineTo(15.5, 3.5);
    vg.lineTo(15.5, 1.5);
    vg.lineTo(14.5, 0.5);
    vg.lineTo(12.5, 0.5);
    vg.lineTo(12.5, 1.5);
    vg.lineTo(11.5, 2.5);
    vg.lineTo(9.5, 2.5);
    vg.lineTo(9.5, 4.5);
    vg.lineTo(10.5, 4.5);
    vg.lineTo(11.5, 5.5);
    vg.closePath();
    vg.fill();
    vg.stroke();
}

pub fn cursorMove(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(-0.5, -0.5);
    vg.lineTo(-0.5, -3.5);
    vg.lineTo(-1.5, -3.5);
    vg.lineTo(-1.5, -4);
    vg.lineTo(0, -6.5);
    vg.lineTo(1, -6.5);
    vg.lineTo(2.5, -4);
    vg.lineTo(2.5, -3.5);
    vg.lineTo(1.5, -3.5);
    vg.lineTo(1.5, -0.5);
    vg.lineTo(4.5, -0.5);
    vg.lineTo(4.5, -1.5);
    vg.lineTo(5, -1.5);
    vg.lineTo(7.5, 0);
    vg.lineTo(7.5, 1);
    vg.lineTo(5, 2.5);
    vg.lineTo(4.5, 2.5);
    vg.lineTo(4.5, 1.5);
    vg.lineTo(1.5, 1.5);
    vg.lineTo(1.5, 4.5);
    vg.lineTo(2.5, 4.5);
    vg.lineTo(2.5, 5);
    vg.lineTo(1, 7.5);
    vg.lineTo(0, 7.5);
    vg.lineTo(-1.5, 5);
    vg.lineTo(-1.5, 4.5);
    vg.lineTo(-0.5, 4.5);
    vg.lineTo(-0.5, 1.5);
    vg.lineTo(-3.5, 1.5);
    vg.lineTo(-3.5, 2.5);
    vg.lineTo(-4, 2.5);
    vg.lineTo(-6.5, 1);
    vg.lineTo(-6.5, 0);
    vg.lineTo(-4, -1.5);
    vg.lineTo(-3.5, -1.5);
    vg.lineTo(-3.5, -0.5);
    vg.closePath();
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
}

pub fn cursorMoveHorizontally(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(4.5, -0.5);
    vg.lineTo(4.5, -1.5);
    vg.lineTo(5, -1.5);
    vg.lineTo(7.5, 0);
    vg.lineTo(7.5, 1);
    vg.lineTo(5, 2.5);
    vg.lineTo(4.5, 2.5);
    vg.lineTo(4.5, 1.5);
    vg.lineTo(-3.5, 1.5);
    vg.lineTo(-3.5, 2.5);
    vg.lineTo(-4, 2.5);
    vg.lineTo(-6.5, 1);
    vg.lineTo(-6.5, 0);
    vg.lineTo(-4, -1.5);
    vg.lineTo(-3.5, -1.5);
    vg.lineTo(-3.5, -0.5);
    vg.closePath();
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
}

pub fn cursorMoveVertically(vg: nvg) void {
    vg.beginPath();
    vg.moveTo(-0.5, -3.5);
    vg.lineTo(-1.5, -3.5);
    vg.lineTo(-1.5, -4);
    vg.lineTo(0, -6.5);
    vg.lineTo(1, -6.5);
    vg.lineTo(2.5, -4);
    vg.lineTo(2.5, -3.5);
    vg.lineTo(1.5, -3.5);
    vg.lineTo(1.5, 4.5);
    vg.lineTo(2.5, 4.5);
    vg.lineTo(2.5, 5);
    vg.lineTo(1, 7.5);
    vg.lineTo(0, 7.5);
    vg.lineTo(-1.5, 5);
    vg.lineTo(-1.5, 4.5);
    vg.lineTo(-0.5, 4.5);
    vg.closePath();
    vg.fillColor(nvg.rgbf(1, 1, 1));
    vg.fill();
    vg.strokeColor(nvg.rgb(0, 0, 0));
    vg.stroke();
}
