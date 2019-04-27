// in this example a weird sound plays when you hit a key

const std = @import("std");
const zang = @import("zang");
const common = @import("common.zig");
const c = @import("common/sdl.zig");

pub const AUDIO_FORMAT = zang.AudioFormat.S16LSB;
pub const AUDIO_SAMPLE_RATE = 48000;
pub const AUDIO_BUFFER_SIZE = 1024;
pub const AUDIO_CHANNELS = 1;

pub const MyNoteParams = CurvePlayer.Params;
pub const MyNotes = zang.Notes(MyNoteParams);

const CurvePlayer = struct {
    pub const NumOutputs = 1;
    pub const NumInputs = 0;
    pub const NumTemps = 2;
    pub const Params = struct {
        freq: f32,
    };

    carrier_curve: zang.Curve,
    carrier: zang.Oscillator,
    modulator_curve: zang.Curve,
    modulator: zang.Oscillator,
    trigger: zang.Notes(Params).Trigger(CurvePlayer),

    fn init() CurvePlayer {
        return CurvePlayer {
            .carrier_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
                zang.CurveNode{ .t = 0.0, .value = 440.0 },
                zang.CurveNode{ .t = 0.5, .value = 880.0 },
                zang.CurveNode{ .t = 1.0, .value = 110.0 },
                zang.CurveNode{ .t = 1.5, .value = 660.0 },
                zang.CurveNode{ .t = 2.0, .value = 330.0 },
                zang.CurveNode{ .t = 3.9, .value = 20.0 },
            }),
            .carrier = zang.Oscillator.init(.Sine),
            .modulator_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
                zang.CurveNode{ .t = 0.0, .value = 110.0 },
                zang.CurveNode{ .t = 1.5, .value = 55.0 },
                zang.CurveNode{ .t = 3.0, .value = 220.0 },
            }),
            .modulator = zang.Oscillator.init(.Sine),
            .trigger = zang.Notes(Params).Trigger(CurvePlayer).init(),
        };
    }

    fn reset(self: *CurvePlayer) void {
        self.carrier_curve.reset();
        self.modulator_curve.reset();
    }

    fn paintSpan(self: *CurvePlayer, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
        const out = outputs[0];
        const freq_mul = params.freq / 440.0;

        zang.zero(temps[0]);
        self.modulator_curve.paint(sample_rate, temps[0], freq_mul);
        zang.zero(temps[1]);
        self.modulator.paintControlledFrequency(sample_rate, temps[1], temps[0]);
        zang.zero(temps[0]);
        self.carrier_curve.paint(sample_rate, temps[0], freq_mul);
        self.carrier.paintControlledPhaseAndFrequency(sample_rate, out, temps[1], temps[0]);
    }

    pub fn paint(self: *CurvePlayer, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, impulses: ?*const zang.Notes(Params).Impulse) void {
        self.trigger.paintFromImpulses(self, sample_rate, outputs, inputs, temps, impulses);
    }
};

var g_buffers: struct {
    buf0: [AUDIO_BUFFER_SIZE]f32,
    buf1: [AUDIO_BUFFER_SIZE]f32,
    buf2: [AUDIO_BUFFER_SIZE]f32,
} = undefined;

pub const MainModule = struct {
    iq: MyNotes.ImpulseQueue,
    curve_player: CurvePlayer,

    pub fn init() MainModule {
        return MainModule{
            .iq = MyNotes.ImpulseQueue.init(),
            .curve_player = CurvePlayer.init(),
        };
    }

    pub fn paint(self: *MainModule, sample_rate: f32) [AUDIO_CHANNELS][]const f32 {
        const out = g_buffers.buf0[0..];
        const tmp0 = g_buffers.buf1[0..];
        const tmp1 = g_buffers.buf2[0..];

        zang.zero(out);

        self.curve_player.paint(sample_rate, [1][]f32{out}, [0][]f32{}, [2][]f32{tmp0, tmp1}, self.iq.consume());

        return [AUDIO_CHANNELS][]const f32 {
            out,
        };
    }

    pub fn keyEvent(self: *MainModule, key: i32, down: bool, out_iq: **MyNotes.ImpulseQueue, out_params: *MyNoteParams) bool {
        if (down) {
            if (common.freqForKey(key)) |freq| {
                out_iq.* = &self.iq;
                out_params.* = MyNoteParams{ .freq = freq };
                return true;
            }
        }
        return false;
    }
};
