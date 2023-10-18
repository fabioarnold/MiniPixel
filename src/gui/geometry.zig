const std = @import("std");

pub fn Point(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        const Self = @This();

        pub fn make(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn translate(self: *Self, point: Self) void {
            self.x += point.x;
            self.y += point.y;
        }

        pub fn translated(self: Self, point: Self) Self {
            return .{ .x = self.x + point.x, .y = self.y + point.y };
        }

        const add = translate;
        const added = translated;

        pub fn subtract(self: *Self, point: Self) void {
            self.x -= point.x;
            self.y -= point.y;
        }

        pub fn subtracted(self: Self, point: Self) Self {
            return .{ .x = self.x - point.x, .y = self.y - point.y };
        }

        pub fn scaled(self: Self, s: T) Self {
            return .{ .x = self.x * s, .y = self.y * s };
        }

        pub fn dot(self: Self, point: Self) T {
            return self.x * point.x + self.y * point.y;
        }

        pub fn lengthSquared(self: Self) T {
            return self.dot(self);
        }

        pub fn length(self: Self) T {
            return std.math.sqrt(self.lengthSquared());
        }

        pub fn angle(self: Self) T {
            return std.math.atan2(T, self.y, self.x);
        }

        pub fn eql(self: Self, point: Self) bool {
            return self.x == point.x and self.y == point.y;
        }

        pub fn lerp(a: Self, b: Self, t: T) Self {
            return .{ .x = mix(a.x, b.x, t), .y = mix(a.y, b.y, t) };
        }

        fn mix(a: T, b: T, t: T) T {
            return (1 - t) * a + t * b;
        }

        pub fn min(a: Self, b: Self) Self {
            return .{ .x = @min(a.x, b.x), .y = @min(a.y, b.y) };
        }

        pub fn max(a: Self, b: Self) Self {
            return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
        }
    };
}

pub fn Rect(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        w: T,
        h: T,

        const Self = @This();

        pub fn make(x: T, y: T, w: T, h: T) Self {
            return .{ .x = x, .y = y, .w = w, .h = h };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y and self.w == other.w and self.h == other.h;
        }

        pub fn fromPoints(p0: Point(T), p1: Point(T)) Self {
            return .{
                .x = @min(p0.x, p1.x),
                .y = @min(p0.y, p1.y),
                .w = if (p1.x > p0.x) p1.x - p0.x else p0.x - p1.x,
                .h = if (p1.y > p0.y) p1.y - p0.y else p0.y - p1.y,
            };
        }

        pub fn getPosition(self: Self) Point(T) {
            return .{ .x = self.x, .y = self.y };
        }

        pub fn getSize(self: Self) Point(T) {
            return .{ .x = self.w, .y = self.h };
        }

        pub fn translated(self: Self, point: Point(T)) Self {
            return .{ .x = self.x + point.x, .y = self.y + point.y, .w = self.w, .h = self.h };
        }

        pub fn scaled(self: Self, s: T) Rect(T) {
            return .{ .x = self.x * s, .y = self.y * s, .w = self.w * s, .h = self.h * s };
        }

        pub fn contains(self: Self, point: Point(T)) bool {
            return point.x >= self.x and point.x < self.x + self.w and point.y >= self.y and point.y < self.y + self.h;
        }

        pub fn overlaps(self: Self, other: Rect(T)) bool {
            return self.x < other.x + other.w and self.x + self.w > other.x and self.y < other.y + other.h and self.y + self.h > other.y;
        }

        pub fn intersection(self: Self, other: Rect(T)) Rect(T) {
            return .{
                .x = @max(self.x, other.x),
                .y = @max(self.y, other.y),
                .w = @min(self.x + self.w, other.x + other.w) - @max(self.x, other.x),
                .h = @min(self.y + self.h, other.y + other.h) - @max(self.y, other.y),
            };
        }
    };
}
