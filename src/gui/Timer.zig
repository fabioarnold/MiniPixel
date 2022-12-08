const std = @import("std");
const gui = @import("gui.zig");

const Timer = @This();

on_elapsed_fn: ?*const fn (usize) void = null,
ctx: usize, // passed to elapsed function
id: ?u32 = null,

const Self = @This();

pub fn start(self: *Self, interval: u32) void {
    if (self.id) |_| self.stop();
    self.id = gui.Application.startTimer(self, interval);
}

pub fn stop(self: *Self) void {
    if (self.id) |id| {
        gui.Application.cancelTimer(id);
        self.id = null;
    }
}

pub fn onElapsed(self: Self) void {
    if (self.on_elapsed_fn) |onElapsedFn| {
        onElapsedFn(self.ctx);
    }
}
