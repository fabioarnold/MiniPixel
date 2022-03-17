const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const EditorWidget = @import("EditorWidget.zig");
const Document = @import("Document.zig");

const Snapshot = []u8;

pub const Buffer = struct {
    allocator: Allocator,
    stack: ArrayList(Snapshot),
    index: usize = 0,

    editor: ?*EditorWidget = null,

    pub fn init(allocator: Allocator) !*Buffer {
        var self = try allocator.create(Buffer);
        self.* = Buffer{
            .allocator = allocator,
            .stack = ArrayList(Snapshot).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Buffer) void {
        for (self.stack.items) |snapshot| {
            self.allocator.free(snapshot);
        }
        self.stack.deinit();
        self.allocator.destroy(self);
    }

    pub fn clearAndFreeStack(self: *Buffer) void {
        for (self.stack.items) |snapshot| {
            self.allocator.free(snapshot);
        }
        self.stack.shrinkRetainingCapacity(0);
        self.index = 0;
    }

    pub fn reset(self: *Buffer, document: *Document) !void {
        self.clearAndFreeStack();
        try self.stack.append(try document.serialize());
        self.notifyChanged(document);
    }

    fn notifyChanged(self: Buffer, document: *Document) void {
        if (self.editor) |editor| editor.onUndoChanged(document);
    }

    pub fn canUndo(self: Buffer) bool {
        return self.index > 0;
    }

    pub fn undo(self: *Buffer, document: *Document) !void {
        if (!self.canUndo()) return;
        self.index -= 1;
        const snapshot = self.stack.items[self.index];
        try document.deserialize(snapshot);
        self.notifyChanged(document);
    }

    pub fn canRedo(self: Buffer) bool {
        return self.index + 1 < self.stack.items.len;
    }

    pub fn redo(self: *Buffer, document: *Document) !void {
        if (!self.canRedo()) return;
        self.index += 1;
        const snapshot = self.stack.items[self.index];
        try document.deserialize(snapshot);
        self.notifyChanged(document);
    }

    pub fn pushFrame(self: *Buffer, document: *Document) !void { // TODO: handle error cases
        // do comparison
        const top = self.stack.items[self.index];
        const snapshot = try document.serialize();
        if (std.mem.eql(u8, top, snapshot)) {
            document.allocator.free(snapshot);
            return;
        }

        self.index += 1;
        // clear redo stack
        for (self.stack.items[self.index..self.stack.items.len]) |snap| {
            document.allocator.free(snap);
        }
        self.stack.shrinkRetainingCapacity(self.index);

        try self.stack.append(snapshot);
        self.notifyChanged(document);
    }
};
