// ================= Synthé MIDI interne =================

SynthDef(\squareMidiSynth, { |outBus = 0, freq = 440, gate = 0, cutoff = 1200, vibrato = 0, bend = 1, amp = 0.2|
    var env, vibratoDepth, freqMod, sig;
    env = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 0);
    vibratoDepth = vibrato.linlin(0, 1, 0, 0.02);
    freqMod = freq * bend * (1 + SinOsc.kr(5, 0, vibratoDepth));
    sig = Pulse.ar(freqMod, 0.5);
    sig = RLPF.ar(sig, cutoff.max(80), 0.7);
    sig = sig * env * amp;
    Out.ar(outBus, sig ! 2);
}).add;

~ensureSynthResources = {
    if(~synthBus.isNil) {
        ~synthBus = Bus.audio(s, 2);
    };
};

~startMidiSynth = { |targetGroup|
    ~ensureSynthResources.value;
    ~midiSynth.tryPerform(\free);
    ~midiSynth = Synth(\squareMidiSynth, [
        \outBus, ~synthBus
    ], target: targetGroup ?? { ~inputGroup });
};
