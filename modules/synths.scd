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

// SynthDef pour chaque tranche d'entrée avec égalisation 4 bandes
SynthDef(\mixChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0,
    gainAmp = 1,
    lowFreq = 120, lowGain = 0,
    mid1Freq = 500, mid1Gain = 0,
    mid2Freq = 2000, mid2Gain = 0,
    highFreq = 8000, highGain = 0|
    var stereo, mono, sig;
    stereo = SoundIn.ar([inA, inB]);
    mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
	sig = BLowShelf.ar(sig, lowFreq, 1, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, 1, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, 1, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, 1, highGain.lag(0.1));
    sig = sig * gainAmp;
    Out.ar(outBus, sig);
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
    [~channelSynths, ~limiterSynth].do { |item|
        if(item.notNil) {
            if(item.isKindOf(Array)) {
                item.do(_.tryPerform(\free));
            } {
                item.tryPerform(\free);
            };
        };
    };

    [~inputGroup, ~outputGroup].do(_.tryPerform(\free));
    ~mixBus.tryPerform(\free);

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.sync;

    ~mixBus = Bus.audio(s, 2);

    ~inputGroup = Group.head(s);
    ~outputGroup = Group.after(~inputGroup);

    ~channelStates = Array.fill(~mixInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (gainDB: 0, eq: eqState);
    });

    ~channelSynths = ~mixInputs.collect { |cfg, index|
        var state = ~channelStates[index];
        Synth(\mixChannel, [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \gainAmp, state[\gainDB].dbamp,
            \lowFreq, state[\eq][\low][\freq],
            \lowGain, state[\eq][\low][\gain],
            \mid1Freq, state[\eq][\mid1][\freq],
            \mid1Gain, state[\eq][\mid1][\gain],
            \mid2Freq, state[\eq][\mid2][\freq],
            \mid2Gain, state[\eq][\mid2][\gain],
            \highFreq, state[\eq][\high][\freq],
            \highGain, state[\eq][\high][\gain]
        ], target: ~inputGroup);
    };

    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~mixBus,
        \out, 0
    ], target: ~outputGroup);

    ~setChannelGain = { |index, db|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            ~channelStates[index][\gainDB] = db;
            synth.tryPerform(\set, \gainAmp, db.dbamp);
        };
    };

    ~setChannelEq = { |index, band, freq, gain|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var params = ~eqParamMap[band];
            var synth = ~channelSynths[index];
            if(params.notNil) {
                synth.tryPerform(\set, params[\freqKey], freq, params[\gainKey], gain);
            };
            ~channelStates[index][\eq][band] = (freq: freq, gain: gain);
        };
    };

    ~getChannelState = { |index|
        ~channelStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState);
        };
    };

    CmdPeriod.doOnce({
        [~channelSynths, ~limiterSynth].do { |item|
            if(item.notNil) {
                if(item.isKindOf(Array)) { item.do(_.tryPerform(\free)) } { item.tryPerform(\free) };
            };
        };
        [~mixBus].do { |bus| bus.tryPerform(\free) };
        [~inputGroup, ~outputGroup].do(_.tryPerform(\free));
    });
};
