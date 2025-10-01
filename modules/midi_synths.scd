// ================= Synthés contrôlés par MIDI =================

// Registre global pour les synthés accessibles via le responder MIDI.
~midiSynthRegistry = ~midiSynthRegistry ?? { Dictionary.new };

// ----------------- Sine percussif -----------------
SynthDef(\percussiveSine, {
    |out = 0, freq = 440, amp = 0.2, attack = 0.01, decay = 0.2, sustain = 0.7, release = 0.4, gate = 1|
    var env = Env.adsr(
        attack.max(0.001),
        decay.max(0.001),
        sustain.clip(0, 1),
        release.max(0.01),
        curve: -4
    );
    var envGen = EnvGen.kr(env, gate, doneAction: 2);
    var sig = SinOsc.ar(freq) * envGen * amp;
    Out.ar(out, sig ! 2);
}).add;

~midiSynthRegistry[\percussiveSine] = (
    label: "Sine percussif",
    makeArgs: { |freq, amp, out, velocity = 0|
        [
            \freq, freq,
            \amp, amp,
            \out, out,
            \gate, 1
        ]
    }
);

// ----------------- Mutable Instruments Braids -----------------
SynthDef(\miBraidsVoice, {
    |out = 0, gate = 1, freq = 440, amp = 0.2,
    attack = 0.01, decay = 0.2, sustain = 0.6, release = 0.4,
    timbre = 0.5, color = 0.5, model = 0,
    resamp = 2, decim = 0, bits = 0, ws = 0,
    pitchOffset = 0, rootNote = 0, fm = 0, envMod = 0,
    manualTrig = 0, level = 0.8, eocAmp = 0|
    var env = Env.adsr(
        attack.max(0.001),
        decay.max(0.001),
        sustain.clip(0, 1),
        release.max(0.01),
        curve: -4
    );
    var envGen = EnvGen.kr(env, gate, doneAction: 2);
    var gateTrig = Trig1.kr(HPZ1.kr(gate).max(0), 0.001);
    var pitch = freq.cpsmidi + pitchOffset;
    var braids = MiBraids.ar(
        pitch: pitch,
        timbre: timbre,
        color: color,
        model: model,
        trig: manualTrig + gateTrig,
        resamp: resamp,
        decim: decim,
        bits: bits,
        ws: ws,
        root: rootNote,
        fm: fm,
        env: envMod,
        level: level,
        eoc: eocAmp
    );
    var sig = braids.asArray;
    sig = (sig.size >= 2).if({ sig.copyRange(0, 1) }, { sig[0] ! 2 });
    sig = sig * envGen * amp;
    Out.ar(out, sig);
}).add;

~midiSynthRegistry[\miBraidsVoice] = (
    label: "Mutable Instruments Braids",
    makeArgs: { |freq, amp, out, velocity = 0|
        [
            \freq, freq,
            \amp, amp,
            \out, out,
            \gate, 1,
            \manualTrig, 0
        ]
    }
);

~currentMidiSynth = ~currentMidiSynth ?? { \percussiveSine };

~setCurrentMidiSynth = { |synthKey|
    var registry = ~midiSynthRegistry ?? { Dictionary.new };
    if(registry.includesKey(synthKey)) {
        ~currentMidiSynth = synthKey;
    } {
        ("[MIDI] Synth inconnue %".format(synthKey)).warn;
    };
};
