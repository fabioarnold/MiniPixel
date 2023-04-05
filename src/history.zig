const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Recti = @import("gui").geometry.Rect(i32);

const EditorWidget = @import("EditorWidget.zig");
const Document = @import("Document.zig");
const Bitmap = @import("Bitmap.zig");

const Snapshot = []u8;

pub const EditType = enum(u8) {
    snapshot,
    region,
};

pub const SnapshotEdit = struct {
    document: Document,
};

pub const RegionEdit = struct {
    bitmap: Document.Bitmap,
    region: Recti,
};

pub const Edit = union(EditType) {
    snapshot: SnapshotEdit,
    region: RegionEdit,

    fn undo(self: Edit, document: *Document) void {
        switch (self) {
            inline else => |edit| edit.undo(document),
        }
    }

    fn redo(self: Edit, document: *Document) void {
        switch (self) {
            inline else => |edit| edit.redo(document),
        }
    }
};

pub const Buffer = struct {
    allocator: Allocator,
    stack: ArrayList(Edit),
    index: usize = 0,

    editor: ?*EditorWidget = null,

    pub fn init(allocator: Allocator) !*Buffer {
        var self = try allocator.create(Buffer);
        self.* = Buffer{
            .allocator = allocator,
            .stack = ArrayList(Edit).init(allocator),
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

    fn clearRedoStack(self: *Buffer, allocator: *Allocator) void {
        // clear redo stack
        for (self.stack.items[self.index..self.stack.items.len]) |snap| {
            allocator.free(snap);
        }
        self.stack.shrinkRetainingCapacity(self.index);
    }

    pub fn pushSnapshot(self: *Buffer, document: *Document) !void { // TODO: handle error cases
        // do comparison
        const top = self.stack.items[self.index];
        const snapshot = try document.serialize();
        if (std.mem.eql(u8, top, snapshot)) {
            document.allocator.free(snapshot);
            return;
        }

        self.index += 1;
        self.clearRedoStack(document.allocator);

        try self.stack.append(snapshot);
        self.notifyChanged(document);
    }

    pub fn pushRegion(self: *Buffer, document: *Document, layer: u32, frame: u32, region: Recti) !void {
        _ = frame;
        _ = layer;
        const allocator = document.allocator;
        self.index += 1;
        self.clearRedoStack(allocator);

        const bitmap = try Bitmap.init(allocator, region.w, region.h, document.bitmap_type);
        bitmap.copyRegion();

        const edit = Edit{
            .region = .{
                .bitmap = bitmap,
                .region = region,
            }
        };
        try self.stack.append(edit);
        self.notifyChanged(document);
    }
};
