// ================= Synthés internes =================

SynthDef(\squareLead, { |outBus = 0, freq = 440, gate = 1,
    amp = 0.3, cutoff = 1200, rq = 0.2,
    attack = 0.01, decay = 0.2, sustain = 0.6, release = 0.4|
    var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    var sig = Pulse.ar(freq, 0.5);
    sig = RLPF.ar(sig, cutoff.clip(40, 20000), rq.clip(0.05, 1));
    sig = (sig * env * amp).dup;
    Out.ar(outBus, sig);
}).add;

~midiSynthLibrary = IdentityDictionary.newFrom([
    \squareLead, (
        defName: \squareLead,
        defaults: (
            amp: 0.35,
            cutoff: 1400,
            cutoffRange: [200, 8000],
            rq: 0.2,
            attack: 0.01,
            decay: 0.2,
            sustain: 0.6,
            release: 0.4
        )
    )
]);

~currentMidiSynthKey = ~currentMidiSynthKey ?? { \squareLead };

~setCurrentMidiSynth = { |key|
    var info = ~midiSynthLibrary[key];
    if(info.notNil) {
        ~currentMidiSynthKey = key;
        var defaults = info[\defaults] ?? { () };
        ~currentFilterFreq = defaults[\cutoff] ?? { ~currentFilterFreq };
        ("Synthé MIDI courant: %".format(key)).postln;
        if(~activeMidiSynths.notNil) {
            var freq = ~currentFilterFreq;
            ~activeMidiSynths.valuesDo { |synth|
                synth.tryPerform(\set, \cutoff, freq);
            };
        };
    } {
        ("Clé de synthé inconnue: %".format(key)).warn;
    };
};

~getCurrentMidiSynthInfo = {
    ~midiSynthLibrary[~currentMidiSynthKey];
};
