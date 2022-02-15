const nvg = @import("nanovg");

pub fn iconNew() void {
    nvg.beginPath();
    nvg.moveTo(2.5, 0.5);
    nvg.lineTo(2.5, 15.5);
    nvg.lineTo(13.5, 15.5);
    nvg.lineTo(13.5, 3.5);
    nvg.lineTo(10.5, 0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(8.5, 0.5);
    nvg.lineTo(8.5, 5.5);
    nvg.lineTo(13.5, 5.5);
    nvg.stroke();
}

pub fn iconOpen() void {
    nvg.beginPath();
    nvg.moveTo(1.5, 1.5);
    nvg.lineTo(0.5, 2.5);
    nvg.lineTo(0.5, 14.5);
    nvg.lineTo(12.5, 14.5);
    nvg.lineTo(13.5, 13.5);
    nvg.lineTo(15.5, 8.5);
    nvg.lineTo(15.5, 7.5);
    nvg.lineTo(13.5, 7.5);
    nvg.lineTo(13.5, 2.5);
    nvg.lineTo(6.5, 2.5);
    nvg.lineTo(5.5, 1.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(245, 218, 97));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(13.5, 7.5);
    nvg.lineTo(4.5, 7.5);
    nvg.lineTo(2.5, 12.5);
    nvg.stroke();
}

pub fn iconSave() void {
    nvg.beginPath();
    nvg.moveTo(0.5, 0.5);
    nvg.lineTo(0.5, 14.5);
    nvg.lineTo(1.5, 15.5);
    nvg.lineTo(15.5, 15.5);
    nvg.lineTo(15.5, 0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(40, 140, 200));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(3, 10);
    nvg.lineTo(3, 15);
    nvg.lineTo(13, 15);
    nvg.lineTo(13, 10);
    nvg.fillColor(nvg.rgb(171, 171, 171));
    nvg.fill();
    nvg.beginPath();
    nvg.moveTo(4, 11);
    nvg.lineTo(4, 14);
    nvg.lineTo(6, 14);
    nvg.lineTo(6, 11);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.moveTo(3, 1);
    nvg.lineTo(3, 8);
    nvg.lineTo(13, 8);
    nvg.lineTo(13, 1);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.beginPath();
    nvg.moveTo(3, 1);
    nvg.lineTo(3, 2);
    nvg.lineTo(13, 2);
    nvg.lineTo(13, 1);
    nvg.fillColor(nvg.rgb(250, 10, 0));
    nvg.fill();
    nvg.beginPath();
    nvg.moveTo(4, 3);
    nvg.lineTo(4, 5);
    nvg.lineTo(12, 5);
    nvg.lineTo(12, 3);
    nvg.moveTo(4, 6);
    nvg.lineTo(4, 7);
    nvg.lineTo(12, 7);
    nvg.lineTo(12, 6);
    nvg.fillColor(nvg.rgb(224, 224, 224));
    nvg.fill();
}

pub fn iconSaveAs() void {
    nvg.save();
    defer nvg.restore();
    iconSave();
    nvg.translate(1, 1);
    iconToolPen();
}

pub fn iconUndoEnabled() void {
    iconUndo(true);
}

pub fn iconUndoDisabled() void {
    iconUndo(false);
}

fn iconUndo(enabled: bool) void {
    nvg.beginPath();
    nvg.arc(8, 8, 6, -0.75 * nvg.Pi, 0.75 * nvg.Pi, .cw);
    nvg.lineCap(.round);
    nvg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    nvg.strokeWidth(4);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(0.5, 7.5);
    nvg.lineTo(0.5, 0.5);
    nvg.lineTo(1.5, 0.5);
    nvg.lineTo(7.5, 6.5);
    nvg.lineTo(7.5, 7.5);
    nvg.closePath();
    nvg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    nvg.fill();
    nvg.strokeWidth(1);
    nvg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.arc(8, 8, 6, -0.75 * nvg.Pi, 0.75 * nvg.Pi, .cw);
    nvg.strokeColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    nvg.strokeWidth(2);
    nvg.stroke();
    // reset
    nvg.lineCap(.butt);
    nvg.strokeWidth(1);
}

pub fn iconRedoEnabled() void {
    iconRedo(true);
}

pub fn iconRedoDisabled() void {
    iconRedo(false);
}

fn iconRedo(enabled: bool) void {
    nvg.beginPath();
    nvg.arc(8, 8, 6, -0.25 * nvg.Pi, 0.25 * nvg.Pi, .ccw);
    nvg.lineCap(.round);
    nvg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    nvg.strokeWidth(4);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(15.5, 7.5);
    nvg.lineTo(15.5, 0.5);
    nvg.lineTo(14.5, 0.5);
    nvg.lineTo(8.5, 6.5);
    nvg.lineTo(8.5, 7.5);
    nvg.closePath();
    nvg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    nvg.fill();
    nvg.strokeWidth(1);
    nvg.strokeColor(if (enabled) nvg.rgb(80, 80, 80) else nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.arc(8, 8, 6, -0.25 * nvg.Pi, 0.25 * nvg.Pi, .ccw);
    nvg.strokeColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(170, 170, 170));
    nvg.strokeWidth(2);
    nvg.stroke();
    // reset
    nvg.lineCap(.butt);
    nvg.strokeWidth(1);
}

pub fn iconCut() void {
    nvg.beginPath();
    nvg.ellipse(4, 13, 2, 2);
    nvg.ellipse(12, 13, 2, 2);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.strokeWidth(2);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(10, 10);
    nvg.lineTo(4.5, 0.5);
    nvg.lineTo(3.5, 0.5);
    nvg.lineTo(3.5, 3.5);
    nvg.lineTo(3.5, 3.5);
    nvg.lineTo(7, 10);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.strokeWidth(1);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(6, 10);
    nvg.lineTo(11.5, 0.5);
    nvg.lineTo(12.5, 0.5);
    nvg.lineTo(12.5, 3.5);
    nvg.lineTo(12.5, 3.5);
    nvg.lineTo(9, 10);
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(6, 9);
    nvg.lineTo(4.5, 10.5);
    nvg.lineTo(7, 13);
    nvg.lineTo(7, 11.5);
    nvg.lineTo(7.5, 11);
    nvg.lineTo(8.5, 11);
    nvg.lineTo(9, 11.5);
    nvg.lineTo(9, 13);
    nvg.lineTo(11.5, 10.5);
    nvg.lineTo(10, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconCopy() void {
    for ([_]u0{ 0, 0 }) |_| {
        nvg.beginPath();
        nvg.moveTo(2.5, 0.5);
        nvg.lineTo(2.5, 10.5);
        nvg.lineTo(10.5, 10.5);
        nvg.lineTo(10.5, 2.5);
        nvg.lineTo(8.5, 0.5);
        nvg.closePath();
        nvg.fillColor(nvg.rgb(255, 255, 255));
        nvg.fill();
        nvg.strokeColor(nvg.rgb(66, 66, 66));
        nvg.stroke();
        nvg.beginPath();
        nvg.moveTo(7.5, 0.5);
        nvg.lineTo(7.5, 3.5);
        nvg.lineTo(10.5, 3.5);
        nvg.stroke();
        nvg.translate(3, 5);
    }
}

pub fn iconPasteEnabled() void {
    iconPaste(true);
}

pub fn iconPasteDisabled() void {
    iconPaste(false);
}

pub fn iconPaste(enabled: bool) void {
    const stroke_color = if (enabled) nvg.rgb(66, 66, 66) else nvg.rgb(170, 170, 170);
    nvg.beginPath();
    nvg.roundedRect(1.5, 1.5, 13, 14, 1.5);
    nvg.fillColor(if (enabled) nvg.rgb(215, 162, 71) else stroke_color);
    nvg.fill();
    nvg.strokeColor(stroke_color);
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(3.5, 3.5, 9, 10);
    nvg.fillColor(if (enabled) nvg.rgb(255, 255, 255) else nvg.rgb(224, 224, 224)); // TODO: use gui constant or alpha
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(6.5, 0.5);
    nvg.lineTo(6.5, 1.5);
    nvg.lineTo(5.5, 2.5);
    nvg.lineTo(5.5, 4.5);
    nvg.lineTo(10.5, 4.5);
    nvg.lineTo(10.5, 2.5);
    nvg.lineTo(9.5, 1.5);
    nvg.lineTo(9.5, 0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(170, 170, 170));
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(5, 6, 6, 1);
    nvg.rect(5, 8, 4, 1);
    nvg.rect(5, 10, 5, 1);
    nvg.fillColor(stroke_color);
    nvg.fill();
}

pub fn iconToolCrop() void {
    nvg.fillColor(nvg.rgb(170, 170, 170));
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.beginPath();
    nvg.moveTo(2.5, 0.5);
    nvg.lineTo(2.5, 13.5);
    nvg.lineTo(15.5, 13.5);
    nvg.lineTo(15.5, 10.5);
    nvg.lineTo(5.5, 10.5);
    nvg.lineTo(5.5, 0.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(0.5, 5.5);
    nvg.lineTo(10.5, 5.5);
    nvg.lineTo(10.5, 15.5);
    nvg.lineTo(13.5, 15.5);
    nvg.lineTo(13.5, 2.5);
    nvg.lineTo(0.5, 2.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();
}

pub fn iconToolSelect() void {
    nvg.beginPath();
    nvg.moveTo(1.5, 4);
    nvg.lineTo(1.5, 1.5);
    nvg.lineTo(4, 1.5);
    nvg.moveTo(6, 1.5);
    nvg.lineTo(10, 1.5);
    nvg.moveTo(12, 1.5);
    nvg.lineTo(14.5, 1.5);
    nvg.lineTo(14.5, 4);
    nvg.moveTo(14.5, 6);
    nvg.lineTo(14.5, 10);
    nvg.moveTo(14.5, 12);
    nvg.lineTo(14.5, 14.5);
    nvg.lineTo(12, 14.5);
    nvg.moveTo(10, 14.5);
    nvg.lineTo(6, 14.5);
    nvg.moveTo(4, 14.5);
    nvg.lineTo(1.5, 14.5);
    nvg.lineTo(1.5, 12);
    nvg.moveTo(1.5, 10);
    nvg.lineTo(1.5, 6);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconToolLine() void {
    nvg.beginPath();
    nvg.moveTo(13, 1);
    nvg.lineTo(5, 5);
    nvg.lineTo(10, 10);
    nvg.lineTo(2, 14);
    nvg.lineCap(.Round);
    defer nvg.lineCap(.Butt);
    nvg.strokeWidth(2);
    defer nvg.strokeWidth(1);
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
}

pub fn iconToolPen() void {
    nvg.beginPath();
    nvg.moveTo(5.5, 14.5);
    nvg.lineTo(5.5, 12.5);
    nvg.lineTo(15.5, 2.5);
    nvg.lineTo(15.5, 4.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(68, 137, 26));
    nvg.fill();

    nvg.beginPath();
    nvg.moveTo(5.5, 12.5);
    nvg.lineTo(3.5, 10.5);
    nvg.lineTo(13.5, 0.5);
    nvg.lineTo(15.5, 2.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(163, 206, 39));
    nvg.fill();

    nvg.beginPath();
    nvg.moveTo(3.5, 10.5);
    nvg.lineTo(1.5, 10.5);
    nvg.lineTo(11.5, 0.5);
    nvg.lineTo(13.5, 0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(213, 228, 102));
    nvg.fill();

    nvg.lineJoin(.round);
    defer nvg.lineJoin(.miter);

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1.5, 10.5);
    nvg.lineTo(11.5, 0.5);
    nvg.lineTo(13.5, 0.5);
    nvg.lineTo(15.5, 2.5);
    nvg.lineTo(15.5, 4.5);
    nvg.lineTo(5.5, 14.5);
    nvg.closePath();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1.5, 10.5);
    nvg.lineTo(3.5, 10.5);
    nvg.lineTo(5.5, 12.5);
    nvg.lineTo(5.5, 14.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(217, 190, 138));
    nvg.fill();
    nvg.stroke();

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1, 13.5);
    nvg.lineTo(2.5, 15);
    nvg.closePath();
    nvg.stroke();
}

pub fn iconToolBucket() void {
    nvg.beginPath();
    nvg.moveTo(9.5, 2.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(8.5, 13.5);
    nvg.bezierTo(9.5, 14.5, 11.5, 14.5, 12.5, 13.5);
    nvg.lineTo(14.5, 11.5);
    nvg.bezierTo(15.5, 10.5, 15.5, 8.5, 14.5, 7.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(171, 171, 171));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(4.5, 9.5);
    nvg.lineTo(10.5, 3.5);
    nvg.stroke();
    nvg.beginPath();
    nvg.roundedRect(8.5, 0.5, 2, 9, 1);
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.ellipse(9.5, 8.5, 1, 1);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(3.5, 10.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(6.5, 5.5);
    nvg.lineTo(5, 5.5);
    nvg.bezierTo(2, 5.5, 0.5, 7, 0.5, 10.5);
    nvg.bezierTo(0.5, 12, 1, 12.5, 2, 12.5);
    nvg.bezierTo(3, 12.5, 3.5, 12, 3.5, 10.5);
    nvg.fillColor(nvg.rgb(210, 80, 60));
    nvg.fill();
    nvg.stroke();
}

pub fn iconMirrorHorizontally() void {
    nvg.beginPath();
    var y: f32 = 0;
    while (y < 16) : (y += 2) {
        nvg.moveTo(7.5, y + 0);
        nvg.lineTo(7.5, y + 1);
    }
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(5, 2);
    nvg.lineTo(5, 3);
    nvg.lineTo(9, 3);
    nvg.lineTo(9, 5);
    nvg.lineTo(11.5, 2.5);
    nvg.lineTo(9, 0);
    nvg.lineTo(9, 2);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(0.5, 5.5, 5, 5);
    nvg.strokeColor(nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(9.5, 5.5, 5, 5);
    nvg.fillColor(nvg.rgb(247, 226, 107));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(164, 100, 34));
    nvg.stroke();
}

pub fn iconMirrorVertically() void {
    nvg.save();
    defer nvg.restore();
    nvg.scale(-1, 1);
    nvg.rotate(0.5 * nvg.Pi);
    iconMirrorHorizontally();
}

pub fn iconRotateCw() void {
    nvg.beginPath();
    nvg.rect(1.5, 8.5, 14, 6);
    nvg.strokeColor(nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(9.5, 0.5, 6, 14);
    nvg.fillColor(nvg.rgb(247, 226, 107));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(164, 100, 34));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(3.5, 7);
    nvg.quadTo(3.5, 4.5, 6, 4.5);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(6, 7.5);
    nvg.lineTo(9, 4.5);
    nvg.lineTo(6, 1.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconRotateCcw() void {
    nvg.beginPath();
    nvg.rect(0.5, 8.5, 14, 6);
    nvg.strokeColor(nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(0.5, 0.5, 6, 14);
    nvg.fillColor(nvg.rgb(247, 226, 107));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(164, 100, 34));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(12.5, 7);
    nvg.quadTo(12.5, 4.5, 10, 4.5);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(10, 7.5);
    nvg.lineTo(7, 4.5);
    nvg.lineTo(10, 1.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconPixelGrid() void {
    nvg.beginPath();
    nvg.moveTo(0, 0.5);
    nvg.lineTo(16, 0.5);
    nvg.moveTo(0, 5.5);
    nvg.lineTo(16, 5.5);
    nvg.moveTo(0, 10.5);
    nvg.lineTo(16, 10.5);
    nvg.moveTo(0, 15.5);
    nvg.lineTo(16, 15.5);
    nvg.moveTo(0.5, 0);
    nvg.lineTo(0.5, 16);
    nvg.moveTo(5.5, 0);
    nvg.lineTo(5.5, 16);
    nvg.moveTo(10.5, 0);
    nvg.lineTo(10.5, 16);
    nvg.moveTo(15.5, 0);
    nvg.lineTo(15.5, 16);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconCustomGrid() void {
    nvg.beginPath();
    nvg.moveTo(1, 2.5);
    nvg.lineTo(4, 2.5);
    nvg.moveTo(5, 2.5);
    nvg.lineTo(7, 2.5);
    nvg.moveTo(8, 2.5);
    nvg.lineTo(10, 2.5);
    nvg.moveTo(11, 2.5);
    nvg.lineTo(14, 2.5);
    nvg.moveTo(1, 12.5);
    nvg.lineTo(4, 12.5);
    nvg.moveTo(5, 12.5);
    nvg.lineTo(7, 12.5);
    nvg.moveTo(8, 12.5);
    nvg.lineTo(10, 12.5);
    nvg.moveTo(11, 12.5);
    nvg.lineTo(14, 12.5);
    nvg.moveTo(2.5, 1);
    nvg.lineTo(2.5, 4);
    nvg.moveTo(2.5, 5);
    nvg.lineTo(2.5, 7);
    nvg.moveTo(2.5, 8);
    nvg.lineTo(2.5, 10);
    nvg.moveTo(2.5, 11);
    nvg.lineTo(2.5, 14);
    nvg.moveTo(12.5, 1);
    nvg.lineTo(12.5, 4);
    nvg.moveTo(12.5, 5);
    nvg.lineTo(12.5, 7);
    nvg.moveTo(12.5, 8);
    nvg.lineTo(12.5, 10);
    nvg.moveTo(12.5, 11);
    nvg.lineTo(12.5, 14);
    nvg.strokeColor(nvg.rgb(40, 140, 200));
    nvg.stroke();
}

pub fn iconSnapEnabled() void {
    iconSnap(true);
}

pub fn iconSnapDisabled() void {
    iconSnap(false);
}

pub fn iconSnap(enabled: bool) void {
    nvg.beginPath();
    nvg.moveTo(1.5, 0.5);
    nvg.lineTo(1.5, 12.5);
    nvg.lineTo(2.5, 14.5);
    nvg.lineTo(4.5, 15.5);
    nvg.lineTo(11.5, 15.5);
    nvg.lineTo(13.5, 14.5);
    nvg.lineTo(14.5, 12.5);
    nvg.lineTo(14.5, 0.5);
    nvg.lineTo(10.5, 0.5);
    nvg.lineTo(10.5, 10.5);
    nvg.lineTo(9.5, 11.5);
    nvg.lineTo(6.5, 11.5);
    nvg.lineTo(5.5, 10.5);
    nvg.lineTo(5.5, 0.5);
    nvg.closePath();
    nvg.fillColor(if (enabled) nvg.rgb(250, 8, 0) else nvg.rgb(170, 170, 170));
    nvg.fill();
    nvg.strokeColor(if (enabled) nvg.rgb(66, 66, 66) else nvg.rgb(170, 170, 170));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(2, 1);
    nvg.lineTo(2, 4);
    nvg.lineTo(5, 4);
    nvg.lineTo(5, 1);
    nvg.moveTo(11, 1);
    nvg.lineTo(11, 4);
    nvg.lineTo(14, 4);
    nvg.lineTo(14, 1);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconAbout() void {
    nvg.beginPath();
    nvg.ellipse(8, 8, 6.5, 6.5);
    nvg.fillColor(nvg.rgb(40, 140, 200));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();

    nvg.beginPath();
    nvg.ellipse(8, 5, 1, 1);
    nvg.moveTo(6, 12);
    nvg.lineTo(10, 12);
    nvg.lineTo(10, 11);
    nvg.lineTo(9, 11);
    nvg.lineTo(9, 7);
    nvg.lineTo(6, 7);
    nvg.lineTo(6, 8);
    nvg.lineTo(7, 8);
    nvg.lineTo(7, 11);
    nvg.lineTo(6, 11);
    nvg.closePath();
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
}

pub fn iconColorPalette() void {
    nvg.beginPath();
    nvg.moveTo(8, 1.5);
    nvg.bezierTo(12, 1.5, 15.5, 4, 15.5, 8);
    nvg.bezierTo(15.5, 12, 12, 14.5, 8, 14.5);
    nvg.bezierTo(4, 14.5, 4, 11.5, 3, 10.5);
    nvg.bezierTo(2, 9.5, 0.5, 10, 0.5, 8);
    nvg.bezierTo(0.5, 4, 4, 1.5, 8, 1.5);
    nvg.closePath();
    nvg.pathWinding(.ccw);
    nvg.circle(7, 11, 1.5);
    nvg.pathWinding(.cw);
    nvg.fillColor(nvg.rgb(245, 218, 97));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.circle(4, 7, 2);
    nvg.fillColor(nvg.rgb(250, 10, 0));
    nvg.fill();
    nvg.beginPath();
    nvg.circle(8, 5, 2);
    nvg.fillColor(nvg.rgb(30, 170, 15));
    nvg.fill();
    nvg.beginPath();
    nvg.circle(12, 7, 2);
    nvg.fillColor(nvg.rgb(40, 140, 200));
    nvg.fill();
}

pub fn iconPlus() void {
    nvg.beginPath();
    nvg.moveTo(10.5, 8.5);
    nvg.lineTo(10.5, 10.5);
    nvg.lineTo(8.5, 10.5);
    nvg.lineTo(8.5, 13.5);
    nvg.lineTo(10.5, 13.5);
    nvg.lineTo(10.5, 15.5);
    nvg.lineTo(13.5, 15.5);
    nvg.lineTo(13.5, 13.5);
    nvg.lineTo(15.5, 13.5);
    nvg.lineTo(15.5, 10.5);
    nvg.lineTo(13.5, 10.5);
    nvg.lineTo(13.5, 8.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(60, 175, 45));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconMinus() void {
    nvg.beginPath();
    nvg.moveTo(8.5, 10.5);
    nvg.lineTo(8.5, 13.5);
    nvg.lineTo(15.5, 13.5);
    nvg.lineTo(15.5, 10.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(250, 10, 0));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconDelete() void {
    nvg.beginPath();
    nvg.moveTo(7, 0.5);
    nvg.lineTo(6.5, 1);
    nvg.lineTo(6.5, 2.5);
    nvg.lineTo(3, 2.5);
    nvg.lineTo(2.5, 3);
    nvg.lineTo(2.5, 5.5);
    nvg.lineTo(3.5, 5.5);
    nvg.lineTo(3.5, 15);
    nvg.lineTo(4, 15.5);
    nvg.lineTo(12, 15.5);
    nvg.lineTo(12.5, 15);
    nvg.lineTo(12.5, 5.5);
    nvg.lineTo(13.5, 5.5);
    nvg.lineTo(13.5, 3);
    nvg.lineTo(13, 2.5);
    nvg.lineTo(9.5, 2.5);
    nvg.lineTo(9.5, 1);
    nvg.lineTo(9, 0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(170, 170, 170));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(6.5, 2.5);
    nvg.lineTo(9.5, 2.5);
    nvg.moveTo(3.5, 5.5);
    nvg.lineTo(12.5, 5.5);
    nvg.moveTo(6.5, 7);
    nvg.lineTo(6.5, 14);
    nvg.moveTo(9.5, 7);
    nvg.lineTo(9.5, 14);
    nvg.stroke();
}

pub fn iconMoveUp() void {
    nvg.beginPath();
    nvg.moveTo(8, 1);
    nvg.lineTo(1.5, 7.5);
    nvg.lineTo(1.5, 9.5);
    nvg.lineTo(4.5, 9.5);
    nvg.lineTo(4.5, 14.5);
    nvg.lineTo(11.5, 14.5);
    nvg.lineTo(11.5, 9.5);
    nvg.lineTo(14.5, 9.5);
    nvg.lineTo(14.5, 7.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconMoveDown() void {
    nvg.beginPath();
    nvg.moveTo(8, 15);
    nvg.lineTo(14.5, 8.5);
    nvg.lineTo(14.5, 6.5);
    nvg.lineTo(11.5, 6.5);
    nvg.lineTo(11.5, 1.5);
    nvg.lineTo(4.5, 1.5);
    nvg.lineTo(4.5, 6.5);
    nvg.lineTo(1.5, 6.5);
    nvg.lineTo(1.5, 8.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconCapButt() void {
    nvg.beginPath();
    nvg.rect(7, 0, 8, 15);
    nvg.rect(5, 5, 5, 5);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconCapRound() void {
    nvg.beginPath();
    nvg.rect(7.5, 0, 7.5, 15);
    nvg.circle(7.5, 7.5, 7.5);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconCapSquare() void {
    nvg.beginPath();
    nvg.rect(0, 0, 15, 15);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconJoinRound() void {
    nvg.beginPath();
    nvg.moveTo(15, 15);
    nvg.lineTo(15, 0);
    nvg.arcTo(0, 0, 0, 7.5, 7.5);
    nvg.lineTo(0, 15);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(7, 7, 1, 8);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconJoinBevel() void {
    nvg.beginPath();
    nvg.moveTo(15, 15);
    nvg.lineTo(15, 0);
    nvg.lineTo(7.5, 0);
    nvg.lineTo(0, 7.5);
    nvg.lineTo(0, 15);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(7, 7, 1, 8);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconJoinSquare() void {
    nvg.beginPath();
    nvg.rect(0, 0, 15, 15);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(7, 7, 8, 1);
    nvg.rect(7, 7, 1, 8);
    nvg.rect(6, 6, 3, 3);
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
}

pub fn iconCross() void {
    nvg.beginPath();
    nvg.moveTo(4, 4);
    nvg.lineTo(11, 11);
    nvg.moveTo(4, 11);
    nvg.lineTo(11, 4);
    nvg.lineCap(.Round);
    defer nvg.lineCap(.Butt);
    nvg.strokeWidth(2);
    defer nvg.strokeWidth(1);
    nvg.strokeColor(nvg.rgb(66, 66, 66));
    nvg.stroke();
}

pub fn iconTimelineBegin() void {
    nvg.beginPath();
    nvg.moveTo(11, 2);
    nvg.lineTo(11, 11);
    nvg.lineTo(2, 6.5);
    nvg.closePath();
    nvg.rect(2, 2, 1, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconTimelineLeft() void {
    nvg.beginPath();
    nvg.moveTo(6, 2);
    nvg.lineTo(6, 11);
    nvg.lineTo(1.5, 6.5);
    nvg.closePath();
    nvg.rect(7, 2, 2, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconTimelinePlay() void {
    nvg.beginPath();
    nvg.moveTo(2, 2);
    nvg.lineTo(2, 11);
    nvg.lineTo(11, 6.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconTimelinePause() void {
    nvg.beginPath();
    nvg.rect(4, 2, 2, 9);
    nvg.rect(7, 2, 2, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconTimelineRight() void {
    nvg.beginPath();
    nvg.moveTo(7, 2);
    nvg.lineTo(7, 11);
    nvg.lineTo(11.5, 6.5);
    nvg.closePath();
    nvg.rect(4, 2, 2, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconTimelineEnd() void {
    nvg.beginPath();
    nvg.moveTo(2, 2);
    nvg.lineTo(2, 11);
    nvg.lineTo(11, 6.5);
    nvg.closePath();
    nvg.rect(10, 2, 1, 9);
    nvg.fillColor(nvg.rgb(66, 66, 66));
    nvg.fill();
}

pub fn iconOnionSkinning() void {
    nvg.beginPath();
    nvg.rect(1.5, 1.5, 9, 9);
    nvg.fillColor(nvg.rgb(203, 219, 252));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(95, 205, 228));
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(5.5, 5.5, 9, 9);
    nvg.fillColor(nvg.rgb(99, 155, 255));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(48, 96, 130));
    nvg.stroke();
}

pub fn cursorArrow() void {
    nvg.beginPath();
    nvg.moveTo(-0.5, -0.5);
    nvg.lineTo(-0.5, 12.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(8.5, 8.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(255, 255, 255));
    nvg.stroke();
}

pub fn cursorArrowInverted() void {
    nvg.beginPath();
    nvg.moveTo(-0.5, -0.5);
    nvg.lineTo(-0.5, 12.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(8.5, 8.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgb(255, 255, 255));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
}

pub fn cursorCrosshair() void {
    nvg.beginPath();
    nvg.moveTo(-5.5, 0.5);
    nvg.lineTo(-2.5, 0.5);
    nvg.moveTo(3.5, 0.5);
    nvg.lineTo(6.5, 0.5);
    nvg.moveTo(0.5, -5.5);
    nvg.lineTo(0.5, -2.5);
    nvg.moveTo(0.5, 3.5);
    nvg.lineTo(0.5, 6.5);
    nvg.lineCap(.square);
    defer nvg.lineCap(.butt);
    nvg.strokeColor(nvg.rgbf(1, 1, 1));
    nvg.strokeWidth(2);
    nvg.stroke();
    nvg.strokeWidth(1);
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
    nvg.beginPath();
    nvg.rect(-0.5, -0.5, 2, 2);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.beginPath();
    nvg.rect(0, 0, 1, 1);
    nvg.fillColor(nvg.rgb(0, 0, 0));
    nvg.fill();
}

pub fn cursorPen() void {
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.save();
    nvg.scale(1, -1);
    nvg.translate(0, -16);
    nvg.lineJoin(.round);
    defer nvg.restore();

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1.5, 10.5);
    nvg.lineTo(11.5, 0.5);
    nvg.lineTo(13.5, 0.5);
    nvg.lineTo(15.5, 2.5);
    nvg.lineTo(15.5, 4.5);
    nvg.lineTo(5.5, 14.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1.5, 10.5);
    nvg.lineTo(3.5, 10.5);
    nvg.lineTo(5.5, 12.5);
    nvg.lineTo(5.5, 14.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();

    nvg.beginPath();
    nvg.moveTo(0.5, 15.5);
    nvg.lineTo(1, 13.5);
    nvg.lineTo(2.5, 15);
    nvg.closePath();
    nvg.stroke();
}

pub fn cursorBucket() void {
    cursorCrosshair();
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.save();
    defer nvg.restore();
    nvg.translate(3, -15);
    nvg.beginPath();
    nvg.moveTo(9.5, 2.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(8.5, 13.5);
    nvg.bezierTo(9.5, 14.5, 11.5, 14.5, 12.5, 13.5);
    nvg.lineTo(14.5, 11.5);
    nvg.bezierTo(15.5, 10.5, 15.5, 8.5, 14.5, 7.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(4.5, 9.5);
    nvg.lineTo(10.5, 3.5);
    nvg.stroke();
    nvg.beginPath();
    nvg.roundedRect(8.5, 0.5, 2, 9, 1);
    nvg.fill();
    nvg.stroke();
    nvg.beginPath();
    nvg.ellipse(9.5, 8.5, 1, 1);
    nvg.stroke();
    nvg.beginPath();
    nvg.moveTo(3.5, 10.5);
    nvg.lineTo(3.5, 8.5);
    nvg.lineTo(6.5, 5.5);
    nvg.lineTo(5, 5.5);
    nvg.bezierTo(2, 5.5, 0.5, 7, 0.5, 10.5);
    nvg.bezierTo(0.5, 12, 1, 12.5, 2, 12.5);
    nvg.bezierTo(3, 12.5, 3.5, 12, 3.5, 10.5);
    nvg.fill();
    nvg.stroke();
}

pub fn cursorPipette() void {
    nvg.save();
    defer nvg.restore();
    nvg.translate(0, -15);

    nvg.lineJoin(.round);
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.strokeColor(nvg.rgb(0, 0, 0));

    nvg.beginPath();
    nvg.moveTo(10.5, 3.5);
    nvg.lineTo(1.5, 12.5);
    nvg.lineTo(1.5, 13.5);
    nvg.lineTo(0.5, 14.5);
    nvg.lineTo(0.5, 15.5);
    nvg.lineTo(1.5, 15.5);
    nvg.lineTo(2.5, 14.5);
    nvg.lineTo(3.5, 14.5);
    nvg.lineTo(12.5, 5.5);
    nvg.fill();
    nvg.stroke();

    nvg.beginPath();
    nvg.moveTo(11.5, 6.5);
    nvg.lineTo(13.5, 6.5);
    nvg.lineTo(13.5, 4.5);
    nvg.lineTo(14.5, 3.5);
    nvg.lineTo(15.5, 3.5);
    nvg.lineTo(15.5, 1.5);
    nvg.lineTo(14.5, 0.5);
    nvg.lineTo(12.5, 0.5);
    nvg.lineTo(12.5, 1.5);
    nvg.lineTo(11.5, 2.5);
    nvg.lineTo(9.5, 2.5);
    nvg.lineTo(9.5, 4.5);
    nvg.lineTo(10.5, 4.5);
    nvg.lineTo(11.5, 5.5);
    nvg.closePath();
    nvg.fill();
    nvg.stroke();
}

pub fn cursorMove() void {
    nvg.beginPath();
    nvg.moveTo(-0.5, -0.5);
    nvg.lineTo(-0.5, -3.5);
    nvg.lineTo(-1.5, -3.5);
    nvg.lineTo(-1.5, -4);
    nvg.lineTo(0, -6.5);
    nvg.lineTo(1, -6.5);
    nvg.lineTo(2.5, -4);
    nvg.lineTo(2.5, -3.5);
    nvg.lineTo(1.5, -3.5);
    nvg.lineTo(1.5, -0.5);
    nvg.lineTo(4.5, -0.5);
    nvg.lineTo(4.5, -1.5);
    nvg.lineTo(5, -1.5);
    nvg.lineTo(7.5, 0);
    nvg.lineTo(7.5, 1);
    nvg.lineTo(5, 2.5);
    nvg.lineTo(4.5, 2.5);
    nvg.lineTo(4.5, 1.5);
    nvg.lineTo(1.5, 1.5);
    nvg.lineTo(1.5, 4.5);
    nvg.lineTo(2.5, 4.5);
    nvg.lineTo(2.5, 5);
    nvg.lineTo(1, 7.5);
    nvg.lineTo(0, 7.5);
    nvg.lineTo(-1.5, 5);
    nvg.lineTo(-1.5, 4.5);
    nvg.lineTo(-0.5, 4.5);
    nvg.lineTo(-0.5, 1.5);
    nvg.lineTo(-3.5, 1.5);
    nvg.lineTo(-3.5, 2.5);
    nvg.lineTo(-4, 2.5);
    nvg.lineTo(-6.5, 1);
    nvg.lineTo(-6.5, 0);
    nvg.lineTo(-4, -1.5);
    nvg.lineTo(-3.5, -1.5);
    nvg.lineTo(-3.5, -0.5);
    nvg.closePath();
    nvg.fillColor(nvg.rgbf(1, 1, 1));
    nvg.fill();
    nvg.strokeColor(nvg.rgb(0, 0, 0));
    nvg.stroke();
}
