pub const EventType = enum(u8) {
    Resize,
    MouseMove,
    MouseDown,
    MouseUp,
    MouseWheel,
    TouchPan,
    TouchZoom,
    KeyDown,
    KeyUp,
    TextInput,
    Focus,
    Blur,
    Enter,
    Leave,
    ClipboardUpdate,
};

pub const Event = struct {
    type: EventType,
    is_accepted: bool = true,

    pub fn accept(self: *Event) void {
        self.is_accepted = true;
    }

    pub fn ignore(self: *Event) void {
        self.is_accepted = false;
    }
};

pub const ResizeEvent = struct {
    event: Event = Event{ .type = .Resize },
    old_width: f32,
    old_height: f32,
    new_width: f32,
    new_height: f32,
};

pub const MouseButton = enum(u4) {
    none,
    left,
    middle,
    right,
    back,
    forward,
};

pub const Modifier = enum(u2) {
    alt,
    ctrl,
    shift,
    super,
};

pub const MouseEvent = struct {
    event: Event,
    button: MouseButton,
    click_count: u32,
    state: u32,
    modifiers: u4,
    x: f32,
    y: f32,
    wheel_x: i32,
    wheel_y: i32,

    pub fn isButtonPressed(self: MouseEvent, button: MouseButton) bool {
        if (button == .none) return false;
        const flag = @as(u32, 1) << (@intFromEnum(button) - 1);
        return (self.state & flag) != 0;
    }

    pub fn isModifierPressed(self: MouseEvent, modifier: Modifier) bool {
        const flag = @as(@TypeOf(self.modifiers), 1) << @intFromEnum(modifier);
        return (self.modifiers & flag) != 0;
    }
};

pub const TouchEvent = struct {
    event: Event,
    x: f32,
    y: f32,
    dx: f32,
    dy: f32,
    zoom: f32,
};

pub const KeyCode = enum(u8) {
    Return,
    D0,
    D1,
    D2,
    D3,
    D4,
    D5,
    D6,
    D7,
    D8,
    D9,
    Period,
    Comma,
    Escape,
    Backspace,
    Space,
    Plus,
    Minus,
    Asterisk,
    Slash,
    Percent,
    Home,
    End,
    Delete,
    Tab,
    LShift,
    RShift,
    LCtrl,
    RCtrl,
    LAlt,
    RAlt,
    Left,
    Right,
    Up,
    Down,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    Hash,
    Unknown,
};

pub const KeyEvent = struct {
    event: Event,
    key: KeyCode,
    down: bool,
    repeat: bool,
    modifiers: u4,

    pub fn isModifierPressed(self: KeyEvent, modifier: Modifier) bool {
        const flag = @as(@TypeOf(self.modifiers), 1) << @intFromEnum(modifier);
        return (self.modifiers & flag) != 0;
    }

    pub fn isSingleModifierPressed(self: KeyEvent, modifier: Modifier) bool {
        const flag = @as(@TypeOf(self.modifiers), 1) << @intFromEnum(modifier);
        return (self.modifiers & flag) == flag;
    }
};

pub const TextInputEvent = struct {
    event: Event = Event{ .type = .TextInput },
    text: []const u8,
};

pub const FocusSource = enum {
    programmatic,
    keyboard,
    mouse,
};

pub const FocusPolicy = struct {
    mouse: bool = false,
    keyboard: bool = false,

    pub fn none() FocusPolicy {
        return .{
            .mouse = false,
            .keyboard = false,
        };
    }

    pub fn accepts(self: FocusPolicy, source: FocusSource) bool {
        return switch (source) {
            .programmatic => self.keyboard or self.mouse,
            .keyboard => self.keyboard,
            .mouse => self.mouse,
        };
    }
};

pub const FocusEvent = struct {
    event: Event,
    source: FocusSource,
};
