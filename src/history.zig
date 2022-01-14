const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const EditorWidget = @import("EditorWidget.zig");
const Document = @import("Document.zig");
const Bitmap = @import("Bitmap.zig");

pub const Snapshot = struct {
    x: i32,
    y: i32,
    bitmap: Bitmap,

    fn make(document: *Document) !Snapshot {
        return Snapshot{
            .x = document.x,
            .y = document.y,
            .bitmap = try document.bitmap.clone(),
        };
    }

    fn deinit(self: Snapshot) void {
        self.bitmap.deinit();
    }

    fn hasChanges(self: Snapshot, document: *Document) bool {
        return self.x != document.x or self.y != document.y or !self.bitmap.eql(document.bitmap);
    }
};

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
        for (self.stack.items) |step| {
            step.deinit();
        }
        self.stack.deinit();
        self.allocator.destroy(self);
    }

    pub fn clearAndFreeStack(self: *Buffer) void {
        for (self.stack.items) |step| {
            step.deinit();
        }
        self.stack.shrinkRetainingCapacity(0);
        self.index = 0;
    }

    pub fn reset(self: *Buffer, document: *Document) !void {
        self.clearAndFreeStack();
        try self.stack.append(try Snapshot.make(document));
        self.notifyChanged(document);
    }

    fn notifyChanged(self: Buffer, document: *Document) void {
        if (self.editor) |editor| editor.onUndoChanged(document);
    }

    pub fn canUndo(self: Buffer) bool {
        return self.index > 0;
    }

    pub fn undo(self: *Buffer, allocator: Allocator, document: *Document) !void {
        if (!self.canUndo()) return;
        self.index -= 1;
        const snapshot = self.stack.items[self.index];
        try document.restoreFromSnapshot(allocator, snapshot);
        self.notifyChanged(document);
    }

    pub fn canRedo(self: Buffer) bool {
        return self.index + 1 < self.stack.items.len;
    }

    pub fn redo(self: *Buffer, allocator: Allocator, document: *Document) !void {
        if (!self.canRedo()) return;
        self.index += 1;
        const snapshot = self.stack.items[self.index];
        try document.restoreFromSnapshot(allocator, snapshot);
        self.notifyChanged(document);
    }

    pub fn pushFrame(self: *Buffer, document: *Document) !void { // TODO: handle error cases
        // do comparison
        const top = self.stack.items[self.index];
        if (!top.hasChanges(document)) return;

        // create new step
        self.index += 1;
        for (self.stack.items[self.index..self.stack.items.len]) |step| {
            step.deinit();
        }
        self.stack.shrinkRetainingCapacity(self.index);
        try self.stack.append(try Snapshot.make(document));
        self.notifyChanged(document);
    }
};
