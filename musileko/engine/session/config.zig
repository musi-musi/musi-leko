

pub const config = struct {

    var _tick_rate: f32 = 40;


    pub fn tickRate() f32 {
        return _tick_rate;
    }

    pub fn tickDuration() f32 {
        return 1 / _tick_rate;
    }
};
