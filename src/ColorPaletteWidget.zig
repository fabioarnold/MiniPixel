const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("gui");
const nvg = @import("nanovg");
const Rect = @import("gui/geometry.zig").Rect;

const ColorPaletteWidget = @This();

widget: gui.Widget,
allocator: Allocator,
colors: [256][3]u8 = [_][3]u8{[_]u8{ 0, 0, 0 }} ** 256,
selected: ?u8 = null,

onSelectionChangedFn: ?fn (*Self) void = null,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
    };

    self.widget.onMouseDownFn = onMouseDown;

    self.widget.drawFn = draw;

    return self;
}

pub fn deinit(self: *Self) void {
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn eql(index0: ?u8, index1: ?u8) bool {
    if (index0 == null and index1 == null) return true;
    if (index0 == null or index1 == null) return false;
    return index0.? == index1.?;
}

pub fn setSelection(self: *Self, selected: ?u8) void {
    if (!eql(self.selected, selected)) {
        self.selected = selected;
        if (self.onSelectionChangedFn) |onSelectionChanged| onSelectionChanged(self);
    }
}

pub fn clearSelection(self: *Self) void {
    self.setSelection(null);
}

pub fn loadPal(self: *Self, allocator: Allocator, filename: []const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(contents);

    try self.loadPalContents(contents);
}

const pal_header = "JASC-PAL";
const pal_version = "0100";
const line_ending = "\r\n";

pub fn loadPalContents(self: *Self, contents: []const u8) !void {
    var lines = std.mem.tokenize(u8, contents, line_ending);
    const header = lines.next() orelse return error.UnexpectedEnd;
    if (!std.mem.eql(u8, header, pal_header)) return error.InvalidHeader;

    const version = lines.next() orelse return error.UnexpectedEnd;
    if (!std.mem.eql(u8, version, pal_version)) return error.InvalidVersion;

    const count_string = lines.next() orelse return error.UnexpectedEnd;
    const count = try std.fmt.parseUnsigned(u32, count_string, 10);
    if (count > 256) return error.TooManyColors;

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const line = lines.next() orelse return error.UnexpectedEnd;
        var components = std.mem.tokenize(u8, line, " ");
        const red_string = components.next() orelse return error.UnexpectedEndOfLine;
        const green_string = components.next() orelse return error.UnexpectedEndOfLine;
        const blue_string = components.next() orelse return error.UnexpectedEndOfLine;
        const red = try std.fmt.parseUnsigned(u8, red_string, 10);
        const green = try std.fmt.parseUnsigned(u8, green_string, 10);
        const blue = try std.fmt.parseUnsigned(u8, blue_string, 10);
        self.colors[i][0] = red;
        self.colors[i][1] = green;
        self.colors[i][2] = blue;
    }
    while (i < self.colors.len) : (i += 1) {
        self.colors[i] = [_]u8{0} ** 3;
    }
}

pub fn writePal(self: Self, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const palette = self.trimBlackColorsRight();

    var writer = file.writer();
    _ = try writer.write(pal_header ++ line_ending);
    _ = try writer.write(pal_version ++ line_ending);
    _ = try writer.print("{}" ++ line_ending, .{palette.len});

    var i: usize = 0;
    while (i < palette.len) : (i += 1) {
        const color = palette[i];
        _ = try writer.print("{} {} {}" ++ line_ending, .{ color[0], color[1], color[2] });
    }
}

fn trimBlackColorsRight(self: Self) []const [3]u8 {
    var len = self.colors.len;
    while (len > 0) : (len -= 1) {
        const color = self.colors[len - 1];
        if (color[0] != 0 or color[1] != 0 or color[2] != 0) break;
    }
    return self.colors[0..len];
}

fn onMouseDown(widget: *gui.Widget, event: *const gui.MouseEvent) void {
    if (event.button == .left) {
        const self = @fieldParentPtr(Self, "widget", widget);
        const rect = widget.relative_rect;
        const ix = std.math.clamp(@floatToInt(u8, 16 * event.x / rect.w), 0, 15);
        const iy = std.math.clamp(@floatToInt(u8, 16 * event.y / rect.h), 0, 15);
        const i = 16 * iy + ix;
        if (self.selected) |selected| {
            self.setSelection(if (selected != i) i else null);
        } else {
            self.setSelection(i);
        }
    }
}

pub fn draw(widget: *gui.Widget) void {
    const self = @fieldParentPtr(Self, "widget", widget);

    const rect = widget.relative_rect;
    gui.drawPanel(rect.x, rect.y, rect.w, rect.h, 1, false, false);

    const pad: f32 = 2;
    const tile_w = (rect.w - pad - (pad - 1)) / 16;
    const tile_h = (rect.h - pad - (pad - 1)) / 16;

    for (self.colors) |color, i| {
        const x = @intToFloat(f32, i % 16);
        const y = @intToFloat(f32, i / 16);
        nvg.beginPath();
        nvg.rect(rect.x + pad + x * tile_w, rect.y + pad + y * tile_h, tile_w - 1, tile_h - 1);
        nvg.fillColor(nvg.rgb(color[0], color[1], color[2]));
        nvg.fill();
    }

    if (self.selected) |selected| {
        const x = @intToFloat(f32, selected % 16);
        const y = @intToFloat(f32, selected / 16);
        nvg.beginPath();
        nvg.rect(rect.x + pad + x * tile_w - 0.5, rect.y + pad + y * tile_h - 0.5, tile_w, tile_h);
        nvg.strokeColor(nvg.rgbf(1, 1, 1));
        nvg.stroke();
        nvg.beginPath();
        nvg.rect(rect.x + pad + x * tile_w - 1.5, rect.y + pad + y * tile_h - 1.5, tile_w + 2, tile_h + 2);
        nvg.strokeColor(nvg.rgbf(0, 0, 0));
        nvg.stroke();
    }
}
