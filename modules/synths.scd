// ================= Synthés MIDI =================

// Définition d'un sine percussif avec contrôle de brillance
SynthDef(\percussiveSine, {
    |out = 0, freq = 440, amp = 0.2, attack = 0.01, decay = 0.2, sustain = 0.7,
    release = 0.4, gate = 1, brightHz = 5000|
    var env = Env.adsr(
        attack.max(0.001),
        decay.max(0.001),
        sustain.clip(0, 1),
        release.max(0.01),
        curve: -4
    );
    var envGen = EnvGen.kr(env, gate, doneAction: 2);
    var sig = SinOsc.ar(freq) * envGen * amp;
    sig = LPF.ar(sig, brightHz.clip(200, 12000));
    Out.ar(out, sig ! 2);
}).add;

// Définition d'un synthé basé sur MembraneHexagon
SynthDef(\membraneHit, {
    |out = 0, freq = 110, amp = 0.2, gate = 1, tension = 0.6|
    var ampEnv, exciteEnv, excitation, membrane, resonated, output;
    ampEnv = EnvGen.kr(Env.asr(0.005, 1, 1.0, curve: -4), gate, doneAction: 2);
    exciteEnv = EnvGen.kr(Env.perc(0.002, 0.12, 1, curve: -6), gate);
    excitation = PinkNoise.ar(exciteEnv) * 0.18;
    membrane = MembraneHexagon.ar(excitation, tension.clip(0.05, 0.99), loss: 0.9995);
    resonated = BPF.ar(LeakDC.ar(membrane), freq.clip(40, 4000), 0.2);
    resonated = Limiter.ar(resonated, 0.7, 0.015);
    output = resonated * ampEnv * amp;
    output = Limiter.ar(output, 0.5, 0.01);
    Out.ar(out, output ! 2);
}).add;

// Définition d'un synthé Karplus-Strong (Pluck)
SynthDef(\karplusString, {
    |out = 0, freq = 220, amp = 0.2, gate = 1, trig = 1, decayTime = 3, damping = 0.5|
    var env = EnvGen.kr(Env.asr(0.005, 1, decayTime, curve: -4), gate, doneAction: 2);
    var excitation = WhiteNoise.ar(amp * 0.5);
    var sig = Pluck.ar(
        excitation,
        trig,
        (1 / 20),
        freq.reciprocal,
        decayTime.max(0.1),
        damping.clip(0.05, 0.99)
    );
    Out.ar(out, (sig * env).dup);
}).add;

// Configuration des synthés MIDI disponibles et des paramètres modulables par CC
~midiSynthLibrary = IdentityDictionary.newFrom([
    \percussiveSine, (
        ccParam: \brightHz,
        ccDefault: 74, // valeur de CC "brightness" par défaut
        ccMap: { |value| value.linexp(0, 127, 400, 12000) },
        extraArgs: { [] }
    ),
    \membraneHit, (
        ccParam: \tension,
        ccDefault: 74,
        ccMap: { |value| value.linlin(0, 127, 0.1, 0.95) },
        extraArgs: { [] }
    ),
    \karplusString, (
        ccParam: \damping,
        ccDefault: 74,
        ccMap: { |value| value.linlin(0, 127, 0.1, 0.95) },
        extraArgs: { [\trig, 1] }
    )
]);

~defaultMidiSynth = \percussiveSine;
~midiSynthRouting = IdentityDictionary.new;

~normalizeSynthKey = ~normalizeSynthKey ?? { |key|
    if(key.isNil) { ^nil };
    if(key.respondsTo(\asSymbol)) { ^key.asSymbol };
    (key.isKindOf(Symbol)).if({ key }, { nil });
};

~setCurrentSynth = { |synthKey|
    var normalizedSynth = ~normalizeSynthKey.(synthKey);
    var library = ~midiSynthLibrary;
    if(normalizedSynth.isNil) {
        ("[Synth] Synthé invalide %".format(synthKey)).warn;
        ^nil;
    };
    if(library.isNil) {
        ("[Synth] Bibliothèque de synthés MIDI indisponible").warn;
        ^nil;
    };
    if(library.includesKey(normalizedSynth).not) {
        ("[Synth] Synthé inconnu %".format(synthKey)).warn;
        ^nil;
    };
    ~currentMidiSynthKey = normalizedSynth;
    ~midiSynthRouting[\default] = normalizedSynth;
    ("[Synth] Synthé courant -> %".format(normalizedSynth)).postln;
    normalizedSynth;
};

~setCurrentSynth.(~defaultMidiSynth);

~midiSynthRouting[0] = \percussiveSine;
~midiSynthRouting[1] = \membraneHit;
~midiSynthRouting[2] = \karplusString;
