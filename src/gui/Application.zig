const std = @import("std");
const nvg = @import("nanovg");
const gui = @import("gui.zig");
usingnamespace @import("event.zig");
const Point = @import("geometry.zig").Point;

const Application = @This();

pub const SystemCallbacks = struct {
    // essential
    createWindow: fn ([:0]const u8, u32, u32, gui.Window.CreateOptions, *gui.Window) anyerror!u32,
    destroyWindow: fn (u32) void,
    setWindowTitle: fn (u32, [:0]const u8) void,

    // optional
    startTimer: ?fn (*gui.Timer, u32) u32 = null,
    cancelTimer: ?fn (u32) void = null,
    showCursor: ?fn (bool) void = null,
    getClipboardText: ?fn (std.mem.Allocator) anyerror!?[]const u8 = null,
    setClipboardText: ?fn (std.mem.Allocator, []const u8) anyerror!void = null,
};

// TODO: get rid of globals (Timer might need a reference to Application)
var startTimerFn: ?fn (*gui.Timer, u32) u32 = null;
var cancelTimerFn: ?fn (u32) void = null;

allocator: std.mem.Allocator,
system_callbacks: SystemCallbacks,
windows: std.ArrayList(*gui.Window),
//main_window: ?*gui.Window = null,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, system_callbacks: SystemCallbacks) !*Self {
    var self = try allocator.create(Application);
    self.* = Self{
        .allocator = allocator,
        .system_callbacks = system_callbacks,
        .windows = std.ArrayList(*gui.Window).init(allocator),
    };
    startTimerFn = system_callbacks.startTimer;
    cancelTimerFn = system_callbacks.cancelTimer;
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.windows.items) |window| {
        self.allocator.destroy(window);
    }
    self.windows.deinit();
    self.allocator.destroy(self);
}

pub fn createWindow(self: *Self, title: [:0]const u8, width: f32, height: f32, options: gui.Window.CreateOptions) !*gui.Window {
    var window = try gui.Window.init(self.allocator, self);
    errdefer self.allocator.destroy(window);

    const system_window_id = try self.system_callbacks.createWindow(
        title,
        @floatToInt(u32, width),
        @floatToInt(u32, height),
        options,
        window,
    );

    window.id = system_window_id;
    window.width = width;
    window.height = height;

    try self.windows.append(window);

    return window;
}

pub fn setWindowTitle(self: *Self, window_id: u32, title: [:0]const u8) void {
    self.system_callbacks.setWindowTitle(window_id, title);
}

pub fn requestWindowClose(self: *Self, window: *gui.Window) void {
    if (window.isBlockedByModal()) return;

    if (window.onCloseRequestFn) |onCloseRequest| {
        if (!onCloseRequest(window)) return; // request denied
    }

    self.system_callbacks.destroyWindow(window.id);

    if (std.mem.indexOfScalar(*gui.Window, self.windows.items, window)) |i| {
        _ = self.windows.swapRemove(i);
        window.setMainWidget(null); // also removes reference to this window in main_widget
        window.deinit();
    }
}

pub fn showCursor(self: Self, show: bool) void {
    if (self.system_callbacks.showCursor) |showCursorFn| {
        showCursorFn(show);
    }
}

pub fn setClipboardText(self: Self, allocator: std.mem.Allocator, text: []const u8) !void {
    if (self.system_callbacks.setClipboardText) |setClipboardTextFn| {
        try setClipboardTextFn(allocator, text);
    }
}

pub fn getClipboardText(self: Self, allocator: std.mem.Allocator) !?[]const u8 {
    if (self.system_callbacks.getClipboardText) |getClipboardTextFn| {
        return try getClipboardTextFn(allocator);
    }
    return null;
}

pub fn startTimer(timer: *gui.Timer, interval: u32) u32 {
    if (startTimerFn) |systemStartTimer| {
        return systemStartTimer(timer, interval);
    }
    return 0;
}

pub fn cancelTimer(id: u32) void {
    if (cancelTimerFn) |systemCancelTimer| {
        systemCancelTimer(id);
    }
}

pub fn broadcastEvent(self: *Self, event: *gui.Event) void {
    for (self.windows.items) |window| {
        window.handleEvent(event);
    }
}
