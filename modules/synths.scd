// ================= SynthDef BufferPlayer =================

// ================= Limiteur global =================
SynthDef(\outputLimiter, { |input = 0, out = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01);
    Out.ar(out, limited.tanh);
}).add;

// ================= Mixage et gestion des bus =================

// Définitions des tranches d'entrée : 1 (mono), 3/4, 5/6, 7/8
~mixInputs = [
    (label: "1",     channels: [0, 0], isMono: 1),
    (label: "3 / 4", channels: [2, 3], isMono: 0),
    (label: "5 / 6", channels: [4, 5], isMono: 0),
    (label: "7 / 8", channels: [6, 7], isMono: 0)
];

// SynthDef pour chaque tranche d'entrée avec égaliseur 4 bandes
SynthDef(\mixInputChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0, gain = 1,
    lowFreq = 120, lowGain = 0,
    mid1Freq = 500, mid1Gain = 0,
    mid2Freq = 2000, mid2Gain = 0,
    highFreq = 8000, highGain = 0|
    var sig;
    var stereo = SoundIn.ar([inA, inB]);
    var mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = BLowShelf.ar(sig, lowFreq, 1, lowGain);
    sig = BPeakEQ.ar(sig, mid1Freq, 1, mid1Gain);
    sig = BPeakEQ.ar(sig, mid2Freq, 1, mid2Gain);
    sig = BHiShelf.ar(sig, highFreq, 1, highGain);
    Out.ar(outBus, sig * gain);
}).add;

// SynthDef pour le gain maître
SynthDef(\mixMaster, { |inBus = 0, outBus = 0, masterGain = 1|
    var sig = In.ar(inBus, 2);
    Out.ar(outBus, sig * masterGain);
}).add;

// Paramètres d'égalisation par défaut
~eqDefaults = (
    low:  (freq: 120,  gain: 0),
    mid1: (freq: 500,  gain: 0),
    mid2: (freq: 2000, gain: 0),
    high: (freq: 8000, gain: 0)
);

~eqParamMap = (
    low:  (freqKey: \lowFreq,  gainKey: \lowGain),
    mid1: (freqKey: \mid1Freq, gainKey: \mid1Gain),
    mid2: (freqKey: \mid2Freq, gainKey: \mid2Gain),
    high: (freqKey: \highFreq, gainKey: \highGain)
);

~setupAudio = {
    // Nettoyage si nécessaire
    [~channelSynths, ~mixSynth, ~limiterSynth].do { |item|
        if(item.notNil) {
            if(item.isKindOf(Array)) {
                item.do(_.tryPerform(\free));
            } {
                item.tryPerform(\free);
            };
        };
    };

    [~inputGroup, ~processingGroup, ~outputGroup].do(_.tryPerform(\free));
    [~mixBus, ~postEqBus].do { |bus| bus.tryPerform(\free) };

    ~channelStates = nil;

    ~mixBus = Bus.audio(s, 2);
    ~postEqBus = Bus.audio(s, 2);

    ~inputGroup = Group.head(s);
    ~processingGroup = Group.after(~inputGroup);
    ~outputGroup = Group.after(~processingGroup);

    ~channelStates = Array.newClear(~mixInputs.size);

    ~channelSynths = ~mixInputs.collect { |cfg, index|
        var args = [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \gain, 1
        ];
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            var params = ~eqParamMap[band];
            eqState[band] = defaults.copy;
            args = args ++ [
                params[\freqKey], defaults[\freq],
                params[\gainKey], defaults[\gain]
            ];
        };
        ~channelStates[index] = eqState;
        Synth(\mixInputChannel, args, target: ~inputGroup);
    };

    ~masterGainDB = 0;

    ~mixSynth = Synth(\mixMaster, [
        \inBus, ~mixBus,
        \outBus, ~postEqBus,
        \masterGain, ~masterGainDB.dbamp
    ], target: ~processingGroup);

    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~postEqBus,
        \out, 0
    ], target: ~outputGroup);

    ~setMasterGain = { |db|
        ~masterGainDB = db;
        ~mixSynth.tryPerform(\set, \masterGain, db.dbamp);
    };

    ~setChannelEq = { |channelIndex, band, freq, gain|
        var params = ~eqParamMap[band];
        var channelState = ~channelStates.tryPerform(\at, channelIndex);
        var channelSynth = ~channelSynths.tryPerform(\at, channelIndex);
        if(params.notNil and: { channelState.notNil } and: { channelSynth.notNil }) {
            channelState[band] = (freq: freq, gain: gain);
            channelSynth.tryPerform(\set, params[\freqKey], freq, params[\gainKey], gain);
        };
    };

    ~getChannelEq = { |channelIndex, band|
        var channelState = ~channelStates.tryPerform(\at, channelIndex);
        if(channelState.notNil) {
            (channelState[band] ?? { ~eqDefaults[band] }).copy
        } {
            ~eqDefaults[band].copy
        };
    };

    ~getMasterGain = { ~masterGainDB };

    CmdPeriod.doOnce({
        [~channelSynths, ~mixSynth, ~limiterSynth].do { |item|
            if(item.notNil) {
                if(item.isKindOf(Array)) { item.do(_.tryPerform(\free)) } { item.tryPerform(\free) };
            };
        };
        [~mixBus, ~postEqBus].do { |bus| bus.tryPerform(\free) };
        [~inputGroup, ~processingGroup, ~outputGroup].do(_.tryPerform(\free));
        ~channelStates = nil;
    });
};
