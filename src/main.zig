const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const win32 = @import("win32");
const foundation = win32.foundation;
const windows = win32.ui.windows_and_messaging;
const mem = std.mem;
const Allocator = mem.Allocator;

const c = @import("c.zig");
const nvg = @import("nanovg");
const gui = @import("gui");
const Rect = @import("gui/geometry.zig").Rect;
const Clipboard = @import("Clipboard.zig");
const EditorWidget = @import("EditorWidget.zig");
const MessageBoxWidget = @import("MessageBoxWidget.zig");
const info = @import("info.zig");
const automated_testing = @import("automated_testing.zig");

extern fn gladLoadGL() callconv(.C) c_int; // init OpenGL function pointers on Windows and Linux
extern fn SetProcessDPIAware() callconv(.C) c_int;
extern fn enableAppleMomentumScroll() callconv(.C) void;

// export fn WinMain() callconv(.C) c_int {
//     main() catch return 1; // TODO report error
//     return 0;
// }

var vg: nvg = undefined;

var window_config_file_path: ?[]u8 = null;
var has_touch_mouse: bool = false;
var touch_window_id: c_uint = 0;
var is_touch_panning: bool = false;
var is_touch_zooming: bool = false;

const SdlWindow = struct {
    handle: *c.SDL_Window,
    context: c.SDL_GLContext, // TODO: shared gl context

    window: *gui.Window,
    dirty: bool = true,

    windowed_width: f32, // size when not maximized
    windowed_height: f32,

    video_width: f32,
    video_height: f32,
    video_scale: f32 = 1,

    fn create(title: [:0]const u8, width: u32, height: u32, options: gui.Window.CreateOptions, window: *gui.Window) !SdlWindow {
        var self: SdlWindow = SdlWindow{
            .windowed_width = @intToFloat(f32, width),
            .windowed_height = @intToFloat(f32, height),
            .video_width = @intToFloat(f32, width),
            .video_height = @intToFloat(f32, height),
            .handle = undefined,
            .context = undefined,
            .window = window,
        };

        var display_index: c_uint = 0;
        if (options.parent_id) |parent_id| {
            const parent_window = c.SDL_GetWindowFromID(parent_id);
            const result = c.SDL_GetWindowDisplayIndex(parent_window);
            if (result >= 0) {
                display_index = @intCast(c_uint, result);
            }
        }

        var window_flags: c_uint = c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_HIDDEN;
        if (options.resizable) window_flags |= c.SDL_WINDOW_RESIZABLE;
        var window_width: c_int = undefined;
        var window_height: c_int = undefined;
        if (builtin.os.tag == .macos) {
            window_width = @floatToInt(c_int, self.video_width);
            window_height = @floatToInt(c_int, self.video_height);
        } else {
            window_width = @floatToInt(c_int, self.video_scale * self.video_width);
            window_height = @floatToInt(c_int, self.video_scale * self.video_height);
        }
        const maybe_window = c.SDL_CreateWindow(
            title,
            @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_DISPLAY(display_index)),
            @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_DISPLAY(display_index)),
            window_width,
            window_height,
            window_flags,
        );
        if (maybe_window) |sdl_window| {
            self.handle = sdl_window;
        } else {
            c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
            return error.SDLCreateWindowFailed;
        }
        errdefer c.SDL_DestroyWindow(self.handle);

        self.context = c.SDL_GL_CreateContext(self.handle);
        if (self.context == null) {
            c.SDL_Log("Unable to create gl context: %s", c.SDL_GetError());
            return error.SDLCreateGLContextFailed;
        }

        if (!options.resizable) {
            var sys_info: c.SDL_SysWMinfo = undefined;
            c.SDL_GetVersion(&sys_info.version);
            _ = c.SDL_GetWindowWMInfo(self.handle, &sys_info);
            if (builtin.os.tag == .windows) {
                if (sys_info.subsystem == c.SDL_SYSWM_WINDOWS) {
                    const hwnd = @ptrCast(foundation.HWND, sys_info.info.win.window);
                    const style = windows.GetWindowLong(hwnd, windows.GWL_STYLE);
                    const no_minimizebox = ~@bitCast(i32, @enumToInt(windows.WS_MINIMIZEBOX));
                    _ = windows.SetWindowLong(hwnd, windows.GWL_STYLE, style & no_minimizebox);
                }
            }
        }

        return self;
    }

    fn destroy(self: SdlWindow) void {
        c.SDL_GL_DeleteContext(self.context);
        c.SDL_DestroyWindow(self.handle);
    }

    fn getId(self: SdlWindow) u32 {
        return c.SDL_GetWindowID(self.handle);
    }

    fn getDisplayIndex(self: SdlWindow) i32 {
        return c.SDL_GetWindowDisplayIndex(self.handle);
    }

    fn isMaximized(self: SdlWindow) bool {
        return c.SDL_GetWindowFlags(self.handle) & c.SDL_WINDOW_MAXIMIZED != 0;
    }

    fn maximize(self: *SdlWindow) void {
        c.SDL_MaximizeWindow(self.handle);
    }

    fn setSize(self: *SdlWindow, width: i32, height: i32) void {
        self.video_width = @intToFloat(f32, width);
        self.video_height = @intToFloat(f32, height);
        self.window.setSize(self.video_width, self.video_height);
        switch (builtin.os.tag) {
            .windows, .linux => {
                self.updateVideoScale();
                const scaled_width = self.video_scale * self.video_width;
                const scaled_height = self.video_scale * self.video_height;
                c.SDL_SetWindowSize(self.handle, @floatToInt(c_int, scaled_width), @floatToInt(c_int, scaled_height));
            },
            .macos => c.SDL_SetWindowSize(self.handle, width, height),
            else => unreachable, // unsupported
        }
    }

    fn setDisplay(self: SdlWindow, display_index: i32) void {
        const pos = @bitCast(i32, c.SDL_WINDOWPOS_CENTERED_DISPLAY(@bitCast(u32, display_index)));
        c.SDL_SetWindowPosition(self.handle, pos, pos);
    }

    fn beginDraw(self: SdlWindow) void {
        _ = c.SDL_GL_MakeCurrent(self.handle, self.context);
    }

    fn updateVideoScale(self: *SdlWindow) void {
        switch (builtin.os.tag) {
            .windows, .linux => {
                const default_dpi: f32 = 96;
                const dpi = self.getLogicalDpi();
                self.video_scale = dpi / default_dpi;
            },
            .macos => {
                var drawable_width: i32 = undefined;
                var drawable_height: i32 = undefined;
                c.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);
                var window_width: i32 = undefined;
                var window_height: i32 = undefined;
                c.SDL_GetWindowSize(self.handle, &window_width, &window_height);
                self.video_scale = @intToFloat(f32, drawable_width) / @intToFloat(f32, window_width);
            },
            else => unreachable,
        }
    }

    fn getLogicalDpi(self: SdlWindow) f32 {
        if (builtin.os.tag == .linux) { // SDL_GetDisplayDPI returns physical DPI on Linux/X11
            var sys_info: c.SDL_SysWMinfo = undefined;
            c.SDL_GetVersion(&sys_info.version);
            _ = c.SDL_GetWindowWMInfo(self.handle, &sys_info);
            if (sys_info.subsystem == c.SDL_SYSWM_X11) {
                const str = c.XGetDefault(sys_info.info.x11.display, "Xft", "dpi");
                const dpi_or_error = std.fmt.parseFloat(f32, std.mem.sliceTo(str, 0));
                if (dpi_or_error) |dpi| {
                    return dpi;
                } else |_| {} // fall through to SDL2 default implementation
            }
        }

        const display = self.getDisplayIndex();
        var dpi: f32 = undefined;
        _ = c.SDL_GetDisplayDPI(display, &dpi, null, null);
        return dpi;
    }

    fn setupFrame(self: *SdlWindow) void {
        var drawable_width: i32 = undefined;
        var drawable_height: i32 = undefined;
        c.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);

        switch (builtin.os.tag) {
            .windows, .linux => {
                const default_dpi: f32 = 96;
                const dpi = self.getLogicalDpi();
                const new_video_scale = dpi / default_dpi;
                if (new_video_scale != self.video_scale) { // detect DPI change
                    //std.debug.print("new_video_scale {} {}\n", .{ new_video_scale, dpi });
                    self.video_scale = new_video_scale;
                    const window_width = @floatToInt(i32, self.video_scale * self.video_width);
                    const window_height = @floatToInt(i32, self.video_scale * self.video_height);
                    c.SDL_SetWindowSize(self.handle, window_width, window_height);
                    c.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);
                }
            },
            .macos => {
                var window_width: i32 = undefined;
                var window_height: i32 = undefined;
                c.SDL_GetWindowSize(self.handle, &window_width, &window_height);
                self.video_scale = @intToFloat(f32, drawable_width) / @intToFloat(f32, window_width);
            },
            else => unreachable, // unsupported
        }

        c.glViewport(0, 0, drawable_width, drawable_height);

        // only when window is resizable
        self.video_width = @intToFloat(f32, drawable_width) / self.video_scale;
        self.video_height = @intToFloat(f32, drawable_height) / self.video_scale;
        self.window.setSize(self.video_width, self.video_height);
    }

    pub fn draw(self: *SdlWindow) void {
        self.beginDraw();
        self.setupFrame();

        c.glClearColor(0.5, 0.5, 0.5, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(self.video_width, self.video_height, self.video_scale);
        self.window.draw(vg);
        vg.endFrame();

        c.glFlush();
        if (c.SDL_GetWindowFlags(self.handle) & c.SDL_WINDOW_HIDDEN != 0) {
            c.SDL_ShowWindow(self.handle);
        }
        c.SDL_GL_SwapWindow(self.handle);
        self.dirty = false;
    }
};

var sdl_windows: std.ArrayList(SdlWindow) = undefined;

var app: *gui.Application = undefined;
var editor_widget: *EditorWidget = undefined;

fn findSdlWindow(id: u32) ?*SdlWindow {
    for (sdl_windows.items) |*sdl_window| {
        if (sdl_window.getId() == id) return sdl_window;
    }
    return null;
}

fn markAllWindowsAsDirty() void {
    for (sdl_windows.items) |*sdl_window| {
        sdl_window.dirty = true;
    }
}

fn sdlProcessWindowEvent(window_event: c.SDL_WindowEvent) void {
    if (findSdlWindow(window_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        switch (window_event.event) {
            c.SDL_WINDOWEVENT_EXPOSED => {
                if (sdl_window.window.isBlockedByModal()) {
                    // TODO: find all modal windows
                    for (sdl_window.window.children.items) |child| {
                        if (child.is_modal) {
                            if (findSdlWindow(child.id)) |child_sdl_window| {
                                c.SDL_RaiseWindow(child_sdl_window.handle);
                            }
                        }
                    }
                }
            },
            c.SDL_WINDOWEVENT_ENTER => {
                var enter_event = gui.Event{ .type = .Enter };
                sdl_window.window.handleEvent(&enter_event);
            },
            c.SDL_WINDOWEVENT_LEAVE => {
                var leave_event = gui.Event{ .type = .Leave };
                sdl_window.window.handleEvent(&leave_event);
            },
            c.SDL_WINDOWEVENT_FOCUS_GAINED => {
                sdl_window.window.is_active = true;
            },
            c.SDL_WINDOWEVENT_FOCUS_LOST => {
                sdl_window.window.is_active = false;
                var leave_event = gui.Event{ .type = .Leave };
                sdl_window.window.handleEvent(&leave_event);
            },
            c.SDL_WINDOWEVENT_MINIMIZED => {
                if (sdl_window.window.isBlockedByModal()) {
                    c.SDL_RestoreWindow(sdl_window.handle);
                }
            },
            c.SDL_WINDOWEVENT_SIZE_CHANGED => {
                if (!sdl_window.isMaximized()) {
                    sdl_window.windowed_width = sdl_window.video_width;
                    sdl_window.windowed_height = sdl_window.video_height;
                }
            },
            c.SDL_WINDOWEVENT_CLOSE => app.requestWindowClose(sdl_window.window),
            else => {},
        }
    }
}

fn sdlQueryModState() u4 {
    var modifiers: u4 = 0;
    const sdl_mod_state = c.SDL_GetModState();
    if ((sdl_mod_state & c.KMOD_ALT) != 0) modifiers |= @as(u4, 1) << @enumToInt(gui.Modifier.alt);
    if ((sdl_mod_state & c.KMOD_CTRL) != 0) modifiers |= @as(u4, 1) << @enumToInt(gui.Modifier.ctrl);
    if ((sdl_mod_state & c.KMOD_SHIFT) != 0) modifiers |= @as(u4, 1) << @enumToInt(gui.Modifier.shift);
    if ((sdl_mod_state & c.KMOD_GUI) != 0) modifiers |= @as(u4, 1) << @enumToInt(gui.Modifier.super);
    return modifiers;
}

fn sdlProcessMouseMotion(motion_event: c.SDL_MouseMotionEvent) void {
    if (findSdlWindow(motion_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        if (motion_event.which == c.SDL_TOUCH_MOUSEID) {} else {
            var mx: f32 = @intToFloat(f32, motion_event.x);
            var my: f32 = @intToFloat(f32, motion_event.y);
            if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
                mx /= sdl_window.video_scale;
                my /= sdl_window.video_scale;
            }
            var me = gui.MouseEvent{
                .event = gui.Event{ .type = .MouseMove },
                .button = .none,
                .click_count = 0,
                .state = motion_event.state,
                .modifiers = sdlQueryModState(),
                .x = mx,
                .y = my,
                .wheel_x = 0,
                .wheel_y = 0,
            };
            sdl_window.window.handleEvent(&me.event);
        }
    }
}

fn sdlProcessMouseButton(button_event: c.SDL_MouseButtonEvent) void {
    if (is_touch_panning) return; // reject accidental button presses
    if (findSdlWindow(button_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        var mx: f32 = @intToFloat(f32, button_event.x);
        var my: f32 = @intToFloat(f32, button_event.y);
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }
        var me = gui.MouseEvent{
            .event = gui.Event{
                .type = if (button_event.state == c.SDL_PRESSED)
                    .MouseDown
                else
                    .MouseUp,
            },
            .button = switch (button_event.button) {
                c.SDL_BUTTON_LEFT => .left,
                c.SDL_BUTTON_MIDDLE => .middle,
                c.SDL_BUTTON_RIGHT => .right,
                c.SDL_BUTTON_X1 => .back,
                c.SDL_BUTTON_X2 => .forward,
                else => .none,
            },
            .click_count = button_event.clicks,
            .state = c.SDL_GetMouseState(null, null),
            .modifiers = sdlQueryModState(),
            .x = mx,
            .y = my,
            .wheel_x = 0,
            .wheel_y = 0,
        };
        sdl_window.window.handleEvent(&me.event);

        // TODO maybe if app gains focus?
        _ = c.SDL_CaptureMouse(if (button_event.state == c.SDL_PRESSED) c.SDL_TRUE else c.SDL_FALSE);
    }
}

fn sdlProcessMouseWheel(wheel_event: c.SDL_MouseWheelEvent) void {
    if (findSdlWindow(wheel_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;

        var x: i32 = undefined;
        var y: i32 = undefined;
        const state = c.SDL_GetMouseState(&x, &y);
        var mx: f32 = @intToFloat(f32, x);
        var my: f32 = @intToFloat(f32, y);
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }

        if (wheel_event.which == @bitCast(c_int, c.SDL_TOUCH_MOUSEID) or has_touch_mouse) {
            is_touch_panning = true;
            const magic_factor = 4; // TODO: we need floating point resolution
            var se = gui.TouchEvent{
                .event = gui.Event{ .type = .TouchPan },
                .x = mx,
                .y = my,
                .dx = magic_factor * @intToFloat(f32, wheel_event.x),
                .dy = magic_factor * @intToFloat(f32, wheel_event.y),
                .zoom = 0,
            };
            if (wheel_event.direction == c.SDL_MOUSEWHEEL_FLIPPED) {
                se.dx *= -1;
            }
            sdl_window.window.handleEvent(&se.event);
        } else {
            var me = gui.MouseEvent{
                .event = gui.Event{ .type = .MouseWheel },
                .button = .none,
                .click_count = 0,
                .state = state,
                .modifiers = sdlQueryModState(),
                .x = mx,
                .y = my,
                .wheel_x = wheel_event.x,
                .wheel_y = wheel_event.y, // TODO: swap if direction is inverse?
            };
            sdl_window.window.handleEvent(&me.event);
        }
    }
}

fn sdlProcessTouchFinger(finger_event: c.SDL_TouchFingerEvent) void {
    if (finger_event.touchId == @bitCast(c_int, c.SDL_TOUCH_MOUSEID)) {
        // has_touch_mouse = true; // doesn't work on windows
    }
    touch_window_id = finger_event.windowID;
    if (finger_event.type == c.SDL_FINGERUP) {
        // reset touch gestures
        is_touch_panning = false;
        is_touch_zooming = false;
    }
    // std.debug.print("touchId: {}\n", .{finger_event.touchId});
}

fn translateSdlKey(sym: c.SDL_Keycode) gui.KeyCode {
    return switch (sym) {
        c.SDLK_RETURN, c.SDLK_KP_ENTER => .Return,
        c.SDLK_0, c.SDLK_KP_0 => .D0,
        c.SDLK_1, c.SDLK_KP_1 => .D1,
        c.SDLK_2, c.SDLK_KP_2 => .D2,
        c.SDLK_3, c.SDLK_KP_3 => .D3,
        c.SDLK_4, c.SDLK_KP_4 => .D4,
        c.SDLK_5, c.SDLK_KP_5 => .D5,
        c.SDLK_6, c.SDLK_KP_6 => .D6,
        c.SDLK_7, c.SDLK_KP_7 => .D7,
        c.SDLK_8, c.SDLK_KP_8 => .D8,
        c.SDLK_9, c.SDLK_KP_9 => .D9,
        c.SDLK_PERIOD, c.SDLK_KP_DECIMAL => .Period,
        c.SDLK_COMMA => .Comma,
        c.SDLK_ESCAPE => .Escape,
        c.SDLK_BACKSPACE => .Backspace,
        c.SDLK_SPACE => .Space,
        c.SDLK_PLUS, c.SDLK_KP_PLUS => .Plus,
        c.SDLK_MINUS, c.SDLK_KP_MINUS => .Minus,
        c.SDLK_ASTERISK, c.SDLK_KP_MULTIPLY => .Asterisk,
        c.SDLK_SLASH, c.SDLK_KP_DIVIDE => .Slash,
        c.SDLK_PERCENT => .Percent,
        c.SDLK_DELETE => .Delete,
        c.SDLK_HOME => .Home,
        c.SDLK_END => .End,
        c.SDLK_TAB => .Tab,
        c.SDLK_LSHIFT => .LShift,
        c.SDLK_RSHIFT => .RShift,
        c.SDLK_LCTRL => .LCtrl,
        c.SDLK_RCTRL => .RCtrl,
        c.SDLK_LALT => .LAlt,
        c.SDLK_RALT => .RAlt,
        c.SDLK_LEFT => .Left,
        c.SDLK_RIGHT => .Right,
        c.SDLK_UP => .Up,
        c.SDLK_DOWN => .Down,
        c.SDLK_a...c.SDLK_z => @intToEnum(gui.KeyCode, @enumToInt(gui.KeyCode.A) + @intCast(u8, sym - c.SDLK_a)),
        c.SDLK_HASH => .Hash,
        else => .Unknown,
    };
}

fn sdlProcessKey(key_event: c.SDL_KeyboardEvent) void {
    if (findSdlWindow(key_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        var ke = gui.KeyEvent{
            .event = gui.Event{ .type = if (key_event.type == c.SDL_KEYDOWN) .KeyDown else .KeyUp },
            .key = translateSdlKey(key_event.keysym.sym),
            .down = key_event.state == c.SDL_PRESSED,
            .repeat = key_event.repeat > 0,
            .modifiers = sdlQueryModState(),
        };
        sdl_window.window.handleEvent(&ke.event);
    }
}

var first_surrogate_half: ?u16 = null;

fn sdlProcessTextInput(text_event: c.SDL_TextInputEvent) void {
    if (findSdlWindow(text_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        const text = mem.sliceTo(std.meta.assumeSentinel(&text_event.text, 0), 0);

        if (std.unicode.utf8ValidateSlice(text)) {
            var te = gui.TextInputEvent{
                .text = text,
            };
            sdl_window.window.handleEvent(&te.event);
        } else if (text.len == 3) {
            _ = std.unicode.utf8Decode(text) catch |err| switch (err) {
                error.Utf8EncodesSurrogateHalf => {
                    var codepoint: u21 = text[0] & 0b00001111;
                    codepoint <<= 6;
                    codepoint |= text[1] & 0b00111111;
                    codepoint <<= 6;
                    codepoint |= text[2] & 0b00111111;
                    const surrogate = @intCast(u16, codepoint);

                    if (first_surrogate_half) |first_surrogate0| {
                        const utf16 = [_]u16{ first_surrogate0, surrogate };
                        var utf8 = [_]u8{0} ** 4;
                        _ = std.unicode.utf16leToUtf8(&utf8, &utf16) catch unreachable;
                        first_surrogate_half = null;

                        var te = gui.TextInputEvent{
                            .text = &utf8,
                        };
                        sdl_window.window.handleEvent(&te.event);
                    } else {
                        first_surrogate_half = surrogate;
                    }
                },
                else => {},
            };
        }
    }
}

fn sdlEventWatch(userdata: ?*anyopaque, sdl_event_ptr: [*c]c.SDL_Event) callconv(.C) c_int {
    _ = userdata; // unused
    const sdl_event = sdl_event_ptr[0];
    if (sdl_event.type == c.SDL_WINDOWEVENT) {
        if (sdl_event.window.event == c.SDL_WINDOWEVENT_RESIZED) {
            if (findSdlWindow(sdl_event.window.windowID)) |sdl_window| {
                sdl_window.draw();
            }
            return 0;
        }
    }
    return 1; // unhandled
}

// fn sdlShowMessageBox(icon: gui.MessageBoxIcon, title: [:0]const u8, message: [:0]const u8) void {
//     const sdl_icon = @intCast(u32, switch (icon) {
//         .err => c.SDL_MESSAGEBOX_ERROR,
//         .warn => c.SDL_MESSAGEBOX_WARNING,
//         .info => c.SDL_MESSAGEBOX_INFORMATION,
//     });
//     _ = c.SDL_ShowSimpleMessageBox(sdl_icon, title, message, main_window.handle);
// }

fn sdlAddTimer(timer: *gui.Timer, interval: u32) u32 {
    const res = c.SDL_AddTimer(interval, sdlTimerCallback, timer);
    if (res == 0) {
        std.debug.print("SDL_AddTimer failed: {s}", .{c.SDL_GetError()});
    }
    return @intCast(u32, res);
}

fn sdlCancelTimer(timer_id: u32) void {
    _ = c.SDL_RemoveTimer(@intCast(c_int, timer_id));
    //if (!res) std.debug.print("SDL_RemoveTimer failed: {}", .{c.SDL_GetError()});
}

const SDL_USEREVENT_TIMER = 1;

fn sdlTimerCallback(interval: u32, param: ?*anyopaque) callconv(.C) u32 {
    var userevent: c.SDL_UserEvent = undefined;
    userevent.type = c.SDL_USEREVENT;
    userevent.code = SDL_USEREVENT_TIMER;
    userevent.data1 = param;

    var event: c.SDL_Event = undefined;
    event.type = c.SDL_USEREVENT;
    event.user = userevent;

    _ = c.SDL_PushEvent(&event);

    return interval;
}

fn sdlProcessUserEvent(user_event: c.SDL_UserEvent) void {
    markAllWindowsAsDirty();
    switch (user_event.code) {
        SDL_USEREVENT_TIMER => {
            var timer = @ptrCast(*gui.Timer, @alignCast(@sizeOf(usize), user_event.data1));
            timer.onElapsed();
        },
        else => {},
    }
}

fn sdlProcessDropFile(drop_event: c.SDL_DropEvent) void {
    markAllWindowsAsDirty();
    const file_path = std.mem.sliceTo(drop_event.file, 0);
    editor_widget.tryLoadDocument(file_path);
    c.SDL_free(drop_event.file);
}

fn sdlProcessClipboardUpdate() void {
    markAllWindowsAsDirty();
    var event = gui.Event{ .type = .ClipboardUpdate };
    app.broadcastEvent(&event);
}

fn sdlProcessMultiGesture(gesture_event: c.SDL_MultiGestureEvent) void {
    if (gesture_event.numFingers != 2 or is_touch_panning) return;
    if (@fabs(gesture_event.dDist) > 0.004) {
        is_touch_zooming = true;
    }
    if (!is_touch_zooming) return;
    // there's no window id :( -> broadcast to all windows
    for (sdl_windows.items) |*sdl_window| {
        sdl_window.dirty = true;
        var x: i32 = undefined;
        var y: i32 = undefined;
        _ = c.SDL_GetMouseState(&x, &y);
        var mx: f32 = @intToFloat(f32, x);
        var my: f32 = @intToFloat(f32, y);
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }

        const magic_factor = 4;
        var se = gui.TouchEvent{
            .event = gui.Event{ .type = .TouchZoom },
            .x = mx,
            .y = my,
            .dx = 0,
            .dy = 0,
            .zoom = magic_factor * gesture_event.dDist,
        };
        sdl_window.window.handleEvent(&se.event);
    }
}

fn sdlShowCursor(enable: bool) void {
    _ = c.SDL_ShowCursor(if (enable) c.SDL_ENABLE else c.SDL_DISABLE);
}

fn sdlCreateWindow(title: [:0]const u8, width: u32, height: u32, options: gui.Window.CreateOptions, window: *gui.Window) !u32 {
    const sdl_window = try SdlWindow.create(title, width, height, options, window);
    try sdl_windows.append(sdl_window);
    return sdl_window.getId();
}

fn sdlDestroyWindow(id: u32) void {
    var i: usize = 0;
    while (i < sdl_windows.items.len) {
        if (sdl_windows.items[i].getId() == id) {
            sdl_windows.items[i].destroy();
            _ = sdl_windows.swapRemove(i);
        } else i += 1;
    }
}

fn sdlSetWindowTitle(window_id: u32, title: [:0]const u8) void {
    if (findSdlWindow(window_id)) |window| {
        c.SDL_SetWindowTitle(window.handle, title);
    }
}

pub fn sdlHasClipboardText() bool {
    return c.SDL_HasClipboardText() == c.SDL_TRUE;
}

pub fn sdlGetClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
    const sdl_text = c.SDL_GetClipboardText();
    if (sdl_text == null) return null;
    var text = try allocator.dupe(u8, std.mem.sliceTo(sdl_text, 0));
    c.SDL_free(sdl_text);
    return text;
}

pub fn sdlSetClipboardText(allocator: std.mem.Allocator, text: []const u8) !void {
    const sdl_text = try allocator.dupeZ(u8, text);
    defer allocator.free(sdl_text);
    if (c.SDL_SetClipboardText(sdl_text) != 0) {
        return error.SdlSetClipboardTextFailed;
    }
    sdlProcessClipboardUpdate(); // broadcasts a gui.ClipboardUpdate event to all windows
}

fn sdlHandleEvent(sdl_event: c.SDL_Event) void {
    switch (sdl_event.type) {
        c.SDL_WINDOWEVENT => sdlProcessWindowEvent(sdl_event.window),
        c.SDL_MOUSEMOTION => sdlProcessMouseMotion(sdl_event.motion),
        c.SDL_MOUSEBUTTONDOWN, c.SDL_MOUSEBUTTONUP => sdlProcessMouseButton(sdl_event.button),
        c.SDL_MOUSEWHEEL => sdlProcessMouseWheel(sdl_event.wheel),
        c.SDL_FINGERMOTION, c.SDL_FINGERDOWN, c.SDL_FINGERUP => sdlProcessTouchFinger(sdl_event.tfinger),
        c.SDL_KEYDOWN, c.SDL_KEYUP => sdlProcessKey(sdl_event.key),
        c.SDL_TEXTINPUT => sdlProcessTextInput(sdl_event.text),
        c.SDL_USEREVENT => sdlProcessUserEvent(sdl_event.user),
        c.SDL_DROPFILE => sdlProcessDropFile(sdl_event.drop),
        c.SDL_CLIPBOARDUPDATE => sdlProcessClipboardUpdate(),
        c.SDL_MULTIGESTURE => sdlProcessMultiGesture(sdl_event.mgesture),
        else => {},
    }
}

const MainloopType = enum {
    wait_event, // updates only when an event occurs
    regular_interval, // runs at monitor refresh rate
};
var mainloop_type: MainloopType = .wait_event;

var gpa = std.heap.GeneralPurposeAllocator(.{
    .enable_memory_limit = true,
}){};

pub fn main() !void {
    defer {
        if (builtin.mode == .Debug) {
            const leaked = gpa.deinit();
            if (leaked) @panic("Memory leak :(");
        }
    }
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    defer Clipboard.deinit();

    if (builtin.os.tag == .windows) {
        _ = SetProcessDPIAware();
    }
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    if (builtin.os.tag == .macos) {
        enableAppleMomentumScroll();
    }

    if (c.SDL_GetPrefPath(info.org_name, info.app_name)) |sdl_pref_path| {
        defer c.SDL_free(sdl_pref_path);
        const user_pref_path = std.mem.sliceTo(sdl_pref_path, 0);
        window_config_file_path = try std.fs.path.join(allocator, &.{ user_pref_path, "window.json" });
    }
    defer {
        if (window_config_file_path) |path| allocator.free(path);
    }

    // enable multitouch gestures from touchpads
    _ = c.SDL_SetHint(c.SDL_HINT_MOUSE_TOUCH_EVENTS, "1");

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);

    sdl_windows = std.ArrayList(SdlWindow).init(allocator);
    defer {
        // TODO: destroy all windows
        sdl_windows.deinit();
    }

    app = try gui.Application.init(allocator, .{
        .createWindow = sdlCreateWindow,
        .destroyWindow = sdlDestroyWindow,
        .setWindowTitle = sdlSetWindowTitle,
        .startTimer = sdlAddTimer,
        .cancelTimer = sdlCancelTimer,
        .showCursor = sdlShowCursor,
        .hasClipboardText = sdlHasClipboardText,
        .getClipboardText = sdlGetClipboardText,
        .setClipboardText = sdlSetClipboardText,
    });
    defer app.deinit();
    var main_window = try app.createWindow("Untitled - Mini Pixel", 800, 600, .{});
    // if (findSdlWindow(main_window.id)) |main_sdl_window| {
    //     c.SDL_SetWindowMinimumSize(main_sdl_window.handle, 400, 200);
    // }

    if (builtin.os.tag == .linux or builtin.os.tag == .macos or true) {
        mainloop_type = .regular_interval;
        _ = c.SDL_GL_SetSwapInterval(0); // disable VSync
    }

    _ = gladLoadGL();

    c.SDL_AddEventWatch(sdlEventWatch, null);
    _ = c.SDL_EventState(c.SDL_DROPFILE, c.SDL_ENABLE); // allow drop events

    vg = try nvg.gl.init(allocator, .{});
    defer vg.deinit();

    gui.init(vg);
    defer gui.deinit(vg);

    const roboto_regular = @embedFile("../data/fonts/Roboto-Regular.ttf");
    const roboto_bold = @embedFile("../data/fonts/Roboto-Bold.ttf");
    _ = vg.createFontMem("guifont", roboto_regular);
    _ = vg.createFontMem("guifontbold", roboto_bold);

    const rect = Rect(f32).make(0, 0, main_window.width, main_window.height);
    editor_widget = try EditorWidget.init(allocator, rect, vg);
    defer editor_widget.deinit(vg);
    main_window.setMainWidget(&editor_widget.widget);
    main_window.close_request_context = @ptrToInt(main_window);
    main_window.onCloseRequestFn = onMainWindowCloseRequest;
    if (window_config_file_path) |file_path| {
        loadAndApplyWindowConfig(allocator, main_window, file_path) catch {}; // don't care
        editor_widget.canvas.centerDocument(); // Window size might have changed recenter document
    }

    // parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    if (args.len > 1) {
        editor_widget.tryLoadDocument(args[1]);
    }
    std.process.argsFree(allocator, args);

    if (build_options.automated_testing) {
        main_window.setSize(800, 600);
        main_window.onCloseRequestFn = null;
        defer main_window.close();
        try automated_testing.runTests(main_window);
    }

    // quit app when there are no more windows open
    while (app.windows.items.len > 0) {
        var sdl_event: c.SDL_Event = undefined;
        switch (mainloop_type) {
            .wait_event => if (c.SDL_WaitEvent(&sdl_event) == 0) {
                c.SDL_Log("SDL_WaitEvent failed: %s", c.SDL_GetError());
            } else {
                sdlHandleEvent(sdl_event);
            },
            .regular_interval => while (c.SDL_PollEvent(&sdl_event) != 0) {
                sdlHandleEvent(sdl_event);
            },
        }

        editor_widget.setMemoryUsageInfo(gpa.total_requested_bytes);
        for (sdl_windows.items) |*sdl_window| {
            if (sdl_window.dirty or mainloop_type == .regular_interval) sdl_window.draw();
        }
    }
}

pub fn automatedTestLoopIteration() void {
    var sdl_event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&sdl_event) != 0) {}
    editor_widget.setMemoryUsageInfo(gpa.total_requested_bytes);
    for (sdl_windows.items) |*sdl_window| {
        sdl_window.draw();
    }
}

fn onMainWindowCloseRequest(context: usize) bool {
    if (editor_widget.has_unsaved_changes) {
        editor_widget.showUnsavedChangesDialog(onUnsavedChangesDialogResult, context);
        return false;
    }
    const window = @intToPtr(*gui.Window, context);
    if (window_config_file_path) |file_path| {
        writeWindowConfig(window, file_path) catch {}; // don't care
    }
    return true;
}

fn onUnsavedChangesDialogResult(result_context: usize, result: MessageBoxWidget.Result) void {
    if (result == .no) {
        editor_widget.has_unsaved_changes = false; // HACK: close will succeed when there are no unsaved changes
        const main_window = @intToPtr(*gui.Window, result_context);
        main_window.close();
    } else if (result == .yes) {
        editor_widget.trySaveAsDocument(); // TODO: if success, continue closing app
    }
}

const WindowConfig = struct {
    display_index: i32,
    windowed_width: i32,
    windowed_height: i32,
    is_maximized: bool,
};

fn writeWindowConfig(window: *gui.Window, file_path: []const u8) !void {
    const sdl_window = findSdlWindow(window.id) orelse return;

    const config = WindowConfig{
        .display_index = sdl_window.getDisplayIndex(),
        .windowed_width = @floatToInt(i32, sdl_window.windowed_width),
        .windowed_height = @floatToInt(i32, sdl_window.windowed_height),
        .is_maximized = sdl_window.isMaximized(),
    };

    var file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try std.json.stringify(config, .{}, file.writer());
}

fn loadAndApplyWindowConfig(allocator: std.mem.Allocator, window: *gui.Window, file_path: []const u8) !void {
    const sdl_window = findSdlWindow(window.id) orelse return;

    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    const json = try file.readToEndAlloc(allocator, 1_000_000);
    defer allocator.free(json);
    var stream = std.json.TokenStream.init(json);
    const config = try std.json.parse(WindowConfig, &stream, .{});

    sdl_window.setSize(config.windowed_width, config.windowed_height);
    sdl_window.setDisplay(config.display_index);
    if (config.is_maximized) {
        sdl_window.maximize();
    }
}
