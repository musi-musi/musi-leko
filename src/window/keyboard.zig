const std = @import("std");
const c = @import("c");
const window = @import("window.zig");

var states: [2]State = .{.{}, .{}};
var curr_state: u32 = 0;
var prev_state: u32 = 1;

pub fn update() void {
    if (curr_state == 0) {
        curr_state = 1;
        prev_state = 0;
    }
    else {
        curr_state = 0;
        prev_state = 1;
    }
    states[curr_state].poll();
}

pub const exports = struct {

    pub fn keyState(key: KeyCode) KeyState {
        return states[curr_state].get(key);
    }

    pub fn keyIsDown(key: KeyCode) bool {
        return states[curr_state].get(key) == .down;
    }

    pub fn keyIsUp(key: KeyCode) bool {
        return states[curr_state].get(key) == .up;
    }

    pub fn keyWasPressed(key: KeyCode) bool {
        return (
            states[curr_state].get(key) == .down and
            states[prev_state].get(key) == .up
        );
    }

    pub fn keyWasReleased(key: KeyCode) bool {
        return (
            states[curr_state].get(key) == .up and
            states[prev_state].get(key) == .down
        );
    }

};

const State = struct {

    key_states: KeyStates = blk: {
        var result: KeyStates = undefined;
        std.mem.set(KeyState, &result, .up);
        break :blk result;
    },

    const KeyStates = [std.enums.values(KeyCode).len]KeyState;

    const Self = @This();

    fn get(self: Self, key: KeyCode) KeyState {
        return self.key_states[@enumToInt(key)];
    }

    fn poll(self: *Self) void {
        @setEvalBranchQuota(100000);
        inline for(comptime std.enums.values(KeyCode)) |key, i| {
            const glfw_key = comptime @enumToInt(GlfwKeyCode.fromKeyCode(key));
            self.key_states[i] = @intToEnum(KeyState, c.glfwGetKey(window.handle, glfw_key));
        }
    }

};

pub const KeyState = enum(c_int) {
    down = c.GLFW_PRESS,
    up = c.GLFW_RELEASE,
};

const KeyCode = blk: {
    const glfw_fields = std.enums.values(GlfwKeyCode);
    var fields: [glfw_fields.len]std.builtin.TypeInfo.EnumField = undefined;
    for (glfw_fields) |gf, i| {
        fields[i] = .{
            .name = @tagName(gf),
            .value = i,
        };
    }
    break :blk @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = u8,
            .fields = &fields,
            .decls = &.{},
            .is_exhaustive = true,
        }
    });
};

const GlfwKeyCode = enum(c_int) {
    
    fn fromKeyCode(key: KeyCode) GlfwKeyCode {
        return std.enums.values(GlfwKeyCode)[@enumToInt(key)];
    }

    space = c.GLFW_KEY_SPACE,
    apostrophe = c.GLFW_KEY_APOSTROPHE,
    comma = c.GLFW_KEY_COMMA,
    minus = c.GLFW_KEY_MINUS,
    period = c.GLFW_KEY_PERIOD,
    slash = c.GLFW_KEY_SLASH,
    alpha_0 = c.GLFW_KEY_0,
    alpha_1 = c.GLFW_KEY_1,
    alpha_2 = c.GLFW_KEY_2,
    alpha_3 = c.GLFW_KEY_3,
    alpha_4 = c.GLFW_KEY_4,
    alpha_5 = c.GLFW_KEY_5,
    alpha_6 = c.GLFW_KEY_6,
    alpha_7 = c.GLFW_KEY_7,
    alpha_8 = c.GLFW_KEY_8,
    alpha_9 = c.GLFW_KEY_9,
    semicolon = c.GLFW_KEY_SEMICOLON,
    equal = c.GLFW_KEY_EQUAL,
    a = c.GLFW_KEY_A,
    b = c.GLFW_KEY_B,
    c = c.GLFW_KEY_C,
    d = c.GLFW_KEY_D,
    e = c.GLFW_KEY_E,
    f = c.GLFW_KEY_F,
    g = c.GLFW_KEY_G,
    h = c.GLFW_KEY_H,
    i = c.GLFW_KEY_I,
    j = c.GLFW_KEY_J,
    k = c.GLFW_KEY_K,
    l = c.GLFW_KEY_L,
    m = c.GLFW_KEY_M,
    n = c.GLFW_KEY_N,
    o = c.GLFW_KEY_O,
    p = c.GLFW_KEY_P,
    q = c.GLFW_KEY_Q,
    r = c.GLFW_KEY_R,
    s = c.GLFW_KEY_S,
    t = c.GLFW_KEY_T,
    u = c.GLFW_KEY_U,
    v = c.GLFW_KEY_V,
    w = c.GLFW_KEY_W,
    x = c.GLFW_KEY_X,
    y = c.GLFW_KEY_Y,
    z = c.GLFW_KEY_Z,
    left_bracket = c.GLFW_KEY_LEFT_BRACKET,
    backslash = c.GLFW_KEY_BACKSLASH,
    right_bracket = c.GLFW_KEY_RIGHT_BRACKET,
    grave = c.GLFW_KEY_GRAVE_ACCENT,
    world_1 = c.GLFW_KEY_WORLD_1,
    world_2 = c.GLFW_KEY_WORLD_2,
    escape = c.GLFW_KEY_ESCAPE,
    enter = c.GLFW_KEY_ENTER,
    tab = c.GLFW_KEY_TAB,
    backspace = c.GLFW_KEY_BACKSPACE,
    insert = c.GLFW_KEY_INSERT,
    delete = c.GLFW_KEY_DELETE,
    right = c.GLFW_KEY_RIGHT,
    left = c.GLFW_KEY_LEFT,
    down = c.GLFW_KEY_DOWN,
    up = c.GLFW_KEY_UP,
    page_up = c.GLFW_KEY_PAGE_UP,
    page_down = c.GLFW_KEY_PAGE_DOWN,
    home = c.GLFW_KEY_HOME,
    end = c.GLFW_KEY_END,
    caps_lock = c.GLFW_KEY_CAPS_LOCK,
    scroll_lock = c.GLFW_KEY_SCROLL_LOCK,
    num_lock = c.GLFW_KEY_NUM_LOCK,
    print_screen = c.GLFW_KEY_PRINT_SCREEN,
    pause = c.GLFW_KEY_PAUSE,
    f_1 = c.GLFW_KEY_F1,
    f_2 = c.GLFW_KEY_F2,
    f_3 = c.GLFW_KEY_F3,
    f_4 = c.GLFW_KEY_F4,
    f_5 = c.GLFW_KEY_F5,
    f_6 = c.GLFW_KEY_F6,
    f_7 = c.GLFW_KEY_F7,
    f_8 = c.GLFW_KEY_F8,
    f_9 = c.GLFW_KEY_F9,
    f_10 = c.GLFW_KEY_F10,
    f_11 = c.GLFW_KEY_F11,
    f_12 = c.GLFW_KEY_F12,
    f_13 = c.GLFW_KEY_F13,
    f_14 = c.GLFW_KEY_F14,
    f_15 = c.GLFW_KEY_F15,
    f_16 = c.GLFW_KEY_F16,
    f_17 = c.GLFW_KEY_F17,
    f_18 = c.GLFW_KEY_F18,
    f_19 = c.GLFW_KEY_F19,
    f_20 = c.GLFW_KEY_F20,
    f_21 = c.GLFW_KEY_F21,
    f_22 = c.GLFW_KEY_F22,
    f_23 = c.GLFW_KEY_F23,
    f_24 = c.GLFW_KEY_F24,
    f_25 = c.GLFW_KEY_F25,
    kp_0 = c.GLFW_KEY_KP_0,
    kp_1 = c.GLFW_KEY_KP_1,
    kp_2 = c.GLFW_KEY_KP_2,
    kp_3 = c.GLFW_KEY_KP_3,
    kp_4 = c.GLFW_KEY_KP_4,
    kp_5 = c.GLFW_KEY_KP_5,
    kp_6 = c.GLFW_KEY_KP_6,
    kp_7 = c.GLFW_KEY_KP_7,
    kp_8 = c.GLFW_KEY_KP_8,
    kp_9 = c.GLFW_KEY_KP_9,
    kp_decimal = c.GLFW_KEY_KP_DECIMAL,
    kp_divide = c.GLFW_KEY_KP_DIVIDE,
    kp_multiply = c.GLFW_KEY_KP_MULTIPLY,
    kp_subtract = c.GLFW_KEY_KP_SUBTRACT,
    kp_add = c.GLFW_KEY_KP_ADD,
    kp_enter = c.GLFW_KEY_KP_ENTER,
    kp_equal = c.GLFW_KEY_KP_EQUAL,
    left_shift = c.GLFW_KEY_LEFT_SHIFT,
    left_control = c.GLFW_KEY_LEFT_CONTROL,
    left_alt = c.GLFW_KEY_LEFT_ALT,
    left_super = c.GLFW_KEY_LEFT_SUPER,
    right_shift = c.GLFW_KEY_RIGHT_SHIFT,
    right_control = c.GLFW_KEY_RIGHT_CONTROL,
    right_alt = c.GLFW_KEY_RIGHT_ALT,
    right_super = c.GLFW_KEY_RIGHT_SUPER,
    menu = c.GLFW_KEY_MENU,
    unknown = c.GLFW_KEY_UNKNOWN,
};