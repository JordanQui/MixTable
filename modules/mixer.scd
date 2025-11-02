// ================= Traitements globaux =================
SynthDef(\outputLimiter, { |input = 0, hardwareOut = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01).tanh;
    Out.ar(hardwareOut, limited);
}).add;

SynthDef(\globalReverb, {
    |inBus = 0, outBus = 0,
    mix = 0.2, room = 0.5, damp = 0.5|
    var inSig = In.ar(inBus, 2);
    var wet = FreeVerb.ar(inSig, mix.clip(0, 1), room.clip(0, 1), damp.clip(0, 1));
    Out.ar(outBus, wet);
}).add;

SynthDef(\masterEQ, {
    |inBus = 0, outBus = 0,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0|
    var sig = In.ar(inBus, 2);
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    Out.ar(outBus, sig);
}).add;

// ================= Mixage et gestion des bus =================

// Définitions des tranches d'entrée
~mixInputs = [
    (label: "3 / 4",  channels: [2, 3],   isMono: 0),
    (label: "5 / 6",  channels: [4, 5],   isMono: 0),
    (label: "7 / 8",  channels: [6, 7],   isMono: 0),
    (label: "15 / 16", channels: [14, 15], isMono: 0),
    (label: "17 / 18", channels: [16, 17], isMono: 0)
];

// SynthDef pour chaque tranche d'entrée avec égalisation 4 bandes
SynthDef(\mixChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0, reverbBus = 0,
    gainAmp = 1, mute = 0, sendLevel = 0,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0,
    wideFreq = 1200, wideRQ = 1, wideGain = 0|
    var stereo, mono, sig, muteLevel;
    stereo = SoundIn.ar([inA, inB]);
    mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    sig = BPeakEQ.ar(sig, wideFreq, wideRQ, wideGain.lag(0.1));
    muteLevel = Lag.kr(1 - mute, 0.05);
    sig = sig * gainAmp * muteLevel;
    Out.ar(outBus, sig);
    Out.ar(reverbBus, sig * sendLevel.clip(0, 1));
}).add;

// Paramètres d'égalisation par défaut
~eqDefaults = (
    low:  (freq: 120,  gain: 0, q: 1),
    mid1: (freq: 500,  gain: 0, q: 1),
    mid2: (freq: 2000, gain: 0, q: 1),
    high: (freq: 8000, gain: 0, q: 1),
    wide: (freq: 1200, gain: 0, q: 1)
);

~eqParamMap = (
    low:  (freqKey: \lowFreq,  gainKey: \lowGain,  qKey: \lowRQ),
    mid1: (freqKey: \mid1Freq, gainKey: \mid1Gain, qKey: \mid1RQ),
    mid2: (freqKey: \mid2Freq, gainKey: \mid2Gain, qKey: \mid2RQ),
    high: (freqKey: \highFreq, gainKey: \highGain, qKey: \highRQ),
    wide: (freqKey: \wideFreq, gainKey: \wideGain, qKey: \wideRQ)
);

~cleanupAudio = {
    [~channelSynths, ~limiterSynth, ~reverbSynth, ~masterEqSynth].do { |item|
        if(item.notNil) {
            if(item.isKindOf(Array)) {
                item.do(_.tryPerform(\free));
            } {
                item.tryPerform(\free);
            };
        };
    };

    [~inputGroup, ~fxGroup, ~outputGroup].do(_.tryPerform(\free));
    [~mixBus, ~masterBus, ~reverbBus].do(_.tryPerform(\free));

    ~channelSynths = nil;
    ~limiterSynth = nil;
    ~reverbSynth = nil;
    ~masterEqSynth = nil;
    ~mixBus = nil;
    ~masterBus = nil;
    ~reverbBus = nil;
    ~inputGroup = nil;
    ~fxGroup = nil;
    ~outputGroup = nil;
};

~setupAudio = {
    // Nettoyage si nécessaire
    ~cleanupAudio.value;

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.latency = 0.01;
    ~mixBus = Bus.audio(s, 2);
    ~masterBus = Bus.audio(s, 2);
    ~reverbBus = Bus.audio(s, 2);

    ~inputGroup = Group.head(s);
    ~fxGroup = Group.after(~inputGroup);
    ~outputGroup = Group.after(~fxGroup);

    ~channelStates = Array.fill(~mixInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (gainDB: 0, eq: eqState, muted: 0, send: 0);
    });

    ~masterEqState = IdentityDictionary.new;
    [\low, \mid1, \mid2, \high].do { |band|
        ~masterEqState[band] = (~eqDefaults[band] ?? { IdentityDictionary.new }).copy;
    };

    ~reverbState = (mix: 0.2, room: 0.5, damp: 0.5);

    ~channelSynths = ~mixInputs.collect { |cfg, index|
        var state = ~channelStates[index];
        Synth(\mixChannel, [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \reverbBus, ~reverbBus,
            \gainAmp, state[\gainDB].dbamp,
            \lowFreq, state[\eq][\low][\freq],
            \lowRQ, (state[\eq][\low][\q] ?? { 1 }).reciprocal,
            \lowGain, state[\eq][\low][\gain],
            \mid1Freq, state[\eq][\mid1][\freq],
            \mid1RQ, (state[\eq][\mid1][\q] ?? { 1 }).reciprocal,
            \mid1Gain, state[\eq][\mid1][\gain],
            \mid2Freq, state[\eq][\mid2][\freq],
            \mid2RQ, (state[\eq][\mid2][\q] ?? { 1 }).reciprocal,
            \mid2Gain, state[\eq][\mid2][\gain],
            \highFreq, state[\eq][\high][\freq],
            \highRQ, (state[\eq][\high][\q] ?? { 1 }).reciprocal,
            \highGain, state[\eq][\high][\gain],
            \wideFreq, state[\eq][\wide][\freq],
            \wideRQ, (state[\eq][\wide][\q] ?? { 1 }).reciprocal,
            \wideGain, state[\eq][\wide][\gain],
            \mute, state[\muted],
            \sendLevel, state[\send]
        ], target: ~inputGroup);
    };

    ~reverbSynth = Synth(\globalReverb, [
        \inBus, ~reverbBus,
        \outBus, ~mixBus,
        \mix, ~reverbState[\mix],
        \room, ~reverbState[\room],
        \damp, ~reverbState[\damp]
    ], target: ~fxGroup);

    ~masterEqSynth = Synth(\masterEQ, [
        \inBus, ~mixBus,
        \outBus, ~masterBus,
        \lowFreq, ~masterEqState[\low][\freq],
        \lowRQ, (~masterEqState[\low][\q] ?? { 1 }).reciprocal,
        \lowGain, ~masterEqState[\low][\gain],
        \mid1Freq, ~masterEqState[\mid1][\freq],
        \mid1RQ, (~masterEqState[\mid1][\q] ?? { 1 }).reciprocal,
        \mid1Gain, ~masterEqState[\mid1][\gain],
        \mid2Freq, ~masterEqState[\mid2][\freq],
        \mid2RQ, (~masterEqState[\mid2][\q] ?? { 1 }).reciprocal,
        \mid2Gain, ~masterEqState[\mid2][\gain],
        \highFreq, ~masterEqState[\high][\freq],
        \highRQ, (~masterEqState[\high][\q] ?? { 1 }).reciprocal,
        \highGain, ~masterEqState[\high][\gain]
    ], target: ~outputGroup, addAction: \addToHead);
    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~masterBus,
        \hardwareOut, 0
    ], target: ~outputGroup, addAction: \addToTail);

    ~setChannelGain = { |index, db|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            ~channelStates[index][\gainDB] = db;
            synth.tryPerform(\set, \gainAmp, db.dbamp);
        };
    };

    ~setChannelMute = { |index, muted|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var muteValue = muted.clip(0, 1);
            ~channelStates[index][\muted] = muteValue;
            synth.tryPerform(\set, \mute, muteValue);
        };
    };

    ~setChannelSend = { |index, send|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var level = send.clip(0, 1);
            ~channelStates[index][\send] = level;
            synth.tryPerform(\set, \sendLevel, level);
        };
    };

    ~setChannelEq = { |index, band, freq, gain, q|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var params = ~eqParamMap[band];
            var synth = ~channelSynths[index];
            if(params.notNil) {
                var rq = q.reciprocal;
                synth.tryPerform(\set,
                    params[\freqKey], freq,
                    params[\gainKey], gain,
                    params[\qKey], rq
                );
            };
            ~channelStates[index][\eq][band] = (freq: freq, gain: gain, q: q);
        };
    };

    ~setMasterEq = { |band, freq, gain, q|
        var params = ~eqParamMap[band];
        if(params.notNil) {
            var rq = q.reciprocal;
            ~masterEqState[band] = (freq: freq, gain: gain, q: q);
            ~masterEqSynth.tryPerform(\set,
                params[\freqKey], freq,
                params[\gainKey], gain,
                params[\qKey], rq
            );
        };
    };

    ~setReverbParams = { |mix = nil, room = nil, damp = nil|
        if(mix.notNil) {
            ~reverbState[\mix] = mix.clip(0, 1);
            ~reverbSynth.tryPerform(\set, \mix, ~reverbState[\mix]);
        };
        if(room.notNil) {
            ~reverbState[\room] = room.clip(0, 1);
            ~reverbSynth.tryPerform(\set, \room, ~reverbState[\room]);
        };
        if(damp.notNil) {
            ~reverbState[\damp] = damp.clip(0, 1);
            ~reverbSynth.tryPerform(\set, \damp, ~reverbState[\damp]);
        };
    };

    ~getChannelState = { |index|
        ~channelStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState, muted: 0, send: 0);
        };
    };

    ~getMasterEqState = {
        ~masterEqState;
    };

    ~getReverbState = {
        ~reverbState;
    };

    CmdPeriod.doOnce({ ~cleanupAudio.value });
};
