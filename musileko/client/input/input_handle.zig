const std = @import("std");

const client = @import("../.zig");
const window = client.window;


const KeyCode = window.KeyCode;
const KeyState = window.KeyState;

pub const InputHandle = struct {

    is_active: bool = true,

    const Self = @This();


    pub fn keyState(self: Self, key: KeyCode) KeyState {
        if (self.is_active) {
            return window.KeyState(key);
        }
        else {
            return KeyState.up;
        }
    }

    pub fn keyIsDown(self: Self, key: KeyCode) bool {
        return self.is_active and window.keyIsDown(key);
    }

    pub fn keyIsUp(self: Self, key: KeyCode) bool {
        return self.is_active and window.keyIsUp(key);
    }

    pub fn keyWasPressed(self: Self, key: KeyCode) bool {
        return self.is_active and window.keyWasPressed(key);
    }

    pub fn keyWasReleased(self: Self, key: KeyCode) bool {
        return self.is_active and window.keyWasReleased(key);
    }

};