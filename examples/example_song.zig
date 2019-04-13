// in this example a canned melody is played

const std = @import("std");
const zang = @import("zang");
const common = @import("common.zig");
const c = @import("common/sdl.zig");

pub const AUDIO_FORMAT = zang.AudioFormat.S16LSB;
pub const AUDIO_SAMPLE_RATE = 48000;
pub const AUDIO_BUFFER_SIZE = 4096;
pub const AUDIO_CHANNELS = 1;

const Note = common.Note;
const f = zang.note_frequencies;
const track1Init = []Note{
    Note{ .freq = f.A4, .dur = 1 },
    Note{ .freq = f.G4, .dur = 1 },
    Note{ .freq = f.A4, .dur = 12 },
    Note{ .freq = f.G4, .dur = 1 },
    Note{ .freq = f.F4, .dur = 1 },
    Note{ .freq = f.E4, .dur = 1 },
    Note{ .freq = f.D4, .dur = 1 },
    Note{ .freq = f.Cs4, .dur = 8 },
    Note{ .freq = f.D4, .dur = 10 },
    Note{ .freq = null, .dur = 4 },

    Note{ .freq = f.A3, .dur = 1 },
    Note{ .freq = f.G3, .dur = 1 },
    Note{ .freq = f.A3, .dur = 12 },
    Note{ .freq = f.E3, .dur = 3 },
    Note{ .freq = f.F3, .dur = 3 },
    Note{ .freq = f.Cs3, .dur = 3 },
    Note{ .freq = f.D3, .dur = 10 },
    Note{ .freq = null, .dur = 4 },

    Note{ .freq = f.A2, .dur = 1 },
    Note{ .freq = f.G2, .dur = 1 },
    Note{ .freq = f.A2, .dur = 10 },
    Note{ .freq = f.G2, .dur = 1 },
    Note{ .freq = f.F2, .dur = 1 },
    Note{ .freq = f.E2, .dur = 1 },
    Note{ .freq = f.D2, .dur = 1 },
    Note{ .freq = f.Cs2, .dur = 8 },
    Note{ .freq = f.D2, .dur = 12 },
    Note{ .freq = null, .dur = 2 },

    Note{ .freq = f.D1, .dur = 128 },
};
const track2Init = []Note{
    Note{ .freq = f.A5, .dur = 1 },
    Note{ .freq = f.G5, .dur = 1 },
    Note{ .freq = f.A5, .dur = 12 },
    Note{ .freq = f.G5, .dur = 1 },
    Note{ .freq = f.F5, .dur = 1 },
    Note{ .freq = f.E5, .dur = 1 },
    Note{ .freq = f.D5, .dur = 1 },
    Note{ .freq = f.Cs5, .dur = 8 },
    Note{ .freq = f.D5, .dur = 10 },
    Note{ .freq = null, .dur = 4 },

    Note{ .freq = f.A4, .dur = 1 },
    Note{ .freq = f.G4, .dur = 1 },
    Note{ .freq = f.A4, .dur = 12 },
    Note{ .freq = f.E4, .dur = 3 },
    Note{ .freq = f.F4, .dur = 3 },
    Note{ .freq = f.Cs4, .dur = 3 },
    Note{ .freq = f.D4, .dur = 10 },
    Note{ .freq = null, .dur = 4 },

    Note{ .freq = f.A3, .dur = 1 },
    Note{ .freq = f.G3, .dur = 1 },
    Note{ .freq = f.A3, .dur = 10 },
    Note{ .freq = f.G3, .dur = 1 },
    Note{ .freq = f.F3, .dur = 1 },
    Note{ .freq = f.E3, .dur = 1 },
    Note{ .freq = f.D3, .dur = 1 },
    Note{ .freq = f.Cs3, .dur = 8 },
    Note{ .freq = f.D3, .dur = 12 },
    Note{ .freq = null, .dur = 2 },
};
const ofs = 130;
const A = 6;
const B = 6;
const C = 5;
const D = 4;
const E = 4;
const track3Init = []Note{
    Note{ .freq = null, .dur = ofs },
    Note{ .freq = f.Cs2, .dur = A + B + C + D + E + 30 },
    Note{ .freq = f.D2, .dur = 14 + (14 + 30) },
};
const track4Init = []Note{
    Note{ .freq = null, .dur = ofs + A },
    Note{ .freq = f.E2, .dur = B + C + D + E + 30 },
};
const track5Init = []Note{
    Note{ .freq = null, .dur = ofs + A + B },
    Note{ .freq = f.G2, .dur = C + D + E + 30 + (14) },
    Note{ .freq = f.E2, .dur = 14 },
    Note{ .freq = f.Fs2, .dur = 30 },
};
const track6Init = []Note{
    Note{ .freq = null, .dur = ofs + A + B + C },
    Note{ .freq = f.Bb2, .dur = D + E + 30 },
    Note{ .freq = f.A2, .dur = 14 + (14 + 30) },
};
const track7Init = []Note{
    Note{ .freq = null, .dur = ofs + A + B + C + D },
    Note{ .freq = f.Cs3, .dur = E + 30 },
};
const track8Init = []Note{
    Note{ .freq = null, .dur = ofs + A + B + C + D + E },
    Note{ .freq = f.E3, .dur = 30 },
    Note{ .freq = f.D3, .dur = 14 + (14 + 30) },
};

const NUM_TRACKS = 8;
const NOTE_DURATION = 0.08;

const tracks = [NUM_TRACKS][]const zang.Impulse {
    common.compileSong(track1Init.len, track1Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track2Init.len, track2Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track3Init.len, track3Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track4Init.len, track4Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track5Init.len, track5Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track6Init.len, track6Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track7Init.len, track7Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
    common.compileSong(track8Init.len, track8Init, AUDIO_SAMPLE_RATE, NOTE_DURATION),
};

// an example of a custom "module"
const PulseModOscillator = struct {
    carrier: zang.Oscillator,
    modulator: zang.Oscillator,
    dc: zang.DC,
    // ratio: the carrier oscillator will use whatever frequency you give the
    // PulseModOscillator. the modulator oscillator will multiply the frequency
    // by this ratio. for example, a ratio of 0.5 means that the modulator
    // oscillator will always play at half the frequency of the carrier
    // oscillator
    ratio: f32,
    // multiplier: the modulator oscillator's output is multiplied by this
    // before it is fed in to the phase input of the carrier oscillator.
    multiplier: f32,

    fn init(ratio: f32, multiplier: f32) PulseModOscillator {
        return PulseModOscillator{
            .carrier = zang.Oscillator.init(.Sine),
            .modulator = zang.Oscillator.init(.Sine),
            .dc = zang.DC.init(),
            .ratio = ratio,
            .multiplier = multiplier,
        };
    }

    fn paintFromImpulses(
        self: *PulseModOscillator,
        sample_rate: u32,
        out: []f32,
        track: []const zang.Impulse,
        tmp0: []f32,
        tmp1: []f32,
        tmp2: []f32,
        frame_index: usize,
    ) void {
        std.debug.assert(out.len == tmp0.len);
        std.debug.assert(out.len == tmp1.len);
        std.debug.assert(out.len == tmp2.len);

        zang.zero(tmp0);
        zang.zero(tmp1);
        self.dc.paintFrequencyFromImpulses(tmp0, track, frame_index);
        zang.multiplyScalar(tmp1, tmp0, self.ratio);
        zang.zero(tmp2);
        self.modulator.paintControlledFrequency(sample_rate, tmp2, tmp1);
        zang.zero(tmp1);
        zang.multiplyScalar(tmp1, tmp2, self.multiplier);
        self.carrier.paintControlledPhaseAndFrequency(sample_rate, out, tmp1, tmp0);
    }
};

var g_buffers: struct {
    buf0: [AUDIO_BUFFER_SIZE]f32,
    buf1: [AUDIO_BUFFER_SIZE]f32,
    buf2: [AUDIO_BUFFER_SIZE]f32,
    buf3: [AUDIO_BUFFER_SIZE]f32,
    buf4: [AUDIO_BUFFER_SIZE]f32,
} = undefined;

pub const MainModule = struct {
    frame_index: usize,

    osc: [NUM_TRACKS]PulseModOscillator,
    env: [NUM_TRACKS]zang.Envelope,

    pub fn init() MainModule {
        return MainModule{
            .frame_index = 0,
            .osc = [1]PulseModOscillator{
                PulseModOscillator.init(1.0, 1.5)
            } ** NUM_TRACKS,
            .env = [1]zang.Envelope{
                zang.Envelope.init(zang.EnvParams {
                    .attack_duration = 0.025,
                    .decay_duration = 0.1,
                    .sustain_volume = 0.5,
                    .release_duration = 0.15,
                })
            } ** NUM_TRACKS,
        };
    }

    pub fn paint(self: *MainModule) [AUDIO_CHANNELS][]const f32 {
        const out = g_buffers.buf0[0..];
        const tmp0 = g_buffers.buf1[0..];
        const tmp1 = g_buffers.buf2[0..];
        const tmp2 = g_buffers.buf3[0..];
        const tmp3 = g_buffers.buf4[0..];

        zang.zero(out);

        var i: usize = 0;
        while (i < NUM_TRACKS) : (i += 1) {
            zang.zero(tmp0);
            self.osc[i].paintFromImpulses(AUDIO_SAMPLE_RATE, tmp0, tracks[i], tmp1, tmp2, tmp3, self.frame_index);
            zang.zero(tmp1);
            self.env[i].paintFromImpulses(AUDIO_SAMPLE_RATE, tmp1, tracks[i], self.frame_index);
            zang.multiply(out, tmp0, tmp1);
        }

        self.frame_index += out.len;

        return [AUDIO_CHANNELS][]const f32 {
            out,
        };
    }

    pub fn keyEvent(self: *MainModule, key: i32, down: bool) ?common.KeyEvent {
        return null;
    }
};
