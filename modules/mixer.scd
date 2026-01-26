// ================= Traitements globaux =================
SynthDef(\outputLimiter, { |input = 0, hardwareOut = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01).tanh;
    Out.ar(hardwareOut, limited);
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

SynthDef(\stereoInput, {
    |inA = 0, inB = 1, outBus = 0, gainDB = 0|
    var sig = SoundIn.ar([inA, inB]) * gainDB.dbamp;
    Out.ar(outBus, sig);
}).add;

SynthDef(\reverbReturn, {
    |inA = 8, inB = 9, outBus = 0, gainDB = 0|
    var sig = SoundIn.ar([inA, inB]) * gainDB.dbamp;
    Out.ar(outBus, sig);
}).add;

// ================= Mixage et gestion des bus =================

// Définitions des tranches d'entrée
~mixInputs = [
    (label: "evolver1",  channels: [2, 3],   isMono: 0),
    (label: "evolver2",  channels: [4, 5],   isMono: 0),
    (label: "evolver3",  channels: [6, 7],   isMono: 0),
    (label: "evolver4",  channels: [8, 9], isMono: 0),
    (label: "synth1", channels: [14, 15], isMono: 0),
    (label: "synth2", channels: [16, 17], isMono: 0),
    (label: "synth3", channels: [18, 19], isMono: 0)
];

~drumInputs = [
    (label: "Kick 13 / 14", channels: [20, 21], isMono: 0),
    (label: "HH1 15 / 16", channels: [22, 23], isMono: 0),
    (label: "HH2 17 / 18", channels: [24, 25], isMono: 0),
    (label: "Snare 19 / 20", channels: [26, 27], isMono: 0),
    (label: "Snare 21 / 22", channels: [28, 29], isMono: 0),
    (label: "Cymbal 31 / 32", channels: [30, 31], isMono: 0)
];

// SynthDef pour chaque tranche d'entrée avec égalisation 4 bandes
SynthDef(\mixChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0, auxBus = 0,
    gainAmp = 1, mute = 0, auxLevel = 0,
    preHpfFreq = 30, preLowShelfFreq = 120, preLowShelfGain = 0,
    monoBassFreq = 120,
    autopanRate = 0.08, autopanDepth = 0.4,
    haasDelayL = 0.012, haasDelayR = 0.012, haasMix = 0.2, haasHighFreq = 700,
    allpassMix = 0.25, allpassTime = 0.012, allpassDecay = 0.1,
    ghSideBias = 0.6,
    sideHpfFreq = 150,
    satDrive = 0.2,
    chorusDepth = 0.01, chorusDryWet = 0, chorusFeedback = 0.2,
    cloudsMix = 0, cloudsPitch = 0, cloudsPosition = 0.5, cloudsSize = 0.4, cloudsDensity = 0.4,
    cloudsTexture = 0.4, cloudsFeedback = 0.3, cloudsFreeze = 0, cloudsMode = 0, cloudsSpread = 0.6,
    cloudsReverb = 0.2, cloudsInputGain = 1, cloudsEnvAmount = 0.3,
    dryWet = 0, ghDelayTime = 1.5, ghDamp = 0.2, ghSize = 1, ghDiff = 0.7,
    ghFeedback = 0.3, ghModDepth = 0.1, ghModFreq = 1, ghEarlyDiff = 0.7, ghSpread = 0.8,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0,
    wideFreq = 1200, wideRQ = 1, wideGain = 0|
    var stereo, mono, sig, muteLevel, chorusDelay, chorusWet, greyholeWet, postFader;
    var cloudsEnv, cloudsDensityMod, cloudsTextureMod, cloudsWet;
    var lowBand, highBand, monoLow, panLfo;
    var haasBand, haasDelayed, haasBlend;
    var allpassWet;
    var midDry, sideDry, midWet, sideWet, midMix, sideMix;
    var drive;
    stereo = SoundIn.ar([inA, inB]);
    mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = LeakDC.ar(sig);
    sig = HPF.ar(sig, preHpfFreq.clip(10, 200));
    sig = BLowShelf.ar(sig, preLowShelfFreq.clip(40, 300), 1, preLowShelfGain);
    lowBand = LPF.ar(sig, monoBassFreq.clip(60, 200));
    highBand = HPF.ar(sig, monoBassFreq.clip(60, 200));
    monoLow = (lowBand.sum * 0.5) ! 2;
    panLfo = SinOsc.kr(autopanRate.clip(0.01, 2), 0, autopanDepth.clip(0, 1));
    highBand = Balance2.ar(highBand[0], highBand[1], panLfo);
    haasBand = HPF.ar(highBand, haasHighFreq.clip(200, 4000));
    haasDelayed = DelayC.ar(haasBand, 0.05, [
        haasDelayL.clip(0.001, 0.03),
        haasDelayR.clip(0.001, 0.03)
    ]);
    haasBlend = XFade2.ar(haasBand, haasDelayed, (haasMix.clip(0, 1) * 2) - 1);
    highBand = (highBand - haasBand) + haasBlend;
    sig = monoLow + highBand;
    chorusDelay = SinOsc.kr([0.23, 0.27], 0, chorusDepth.clip(0, 1) * 0.02 + 0.001, 0.005)
        .clip(0.001, 0.03);
    chorusWet = DelayC.ar(sig + (sig * chorusFeedback.clip(0, 1.2)), 0.05, chorusDelay);
    sig = XFade2.ar(sig, chorusWet, (chorusDryWet.clip(0, 1) * 2) - 1);
    allpassWet = AllpassC.ar(sig, 0.05, allpassTime.clip(0.001, 0.03), allpassDecay.clip(0.01, 1));
    allpassWet = AllpassC.ar(allpassWet, 0.05, (allpassTime * 1.2).clip(0.001, 0.03), allpassDecay.clip(0.01, 1));
    allpassWet = AllpassC.ar(allpassWet, 0.05, (allpassTime * 0.8).clip(0.001, 0.03), allpassDecay.clip(0.01, 1));
    sig = XFade2.ar(sig, allpassWet, (allpassMix.clip(0, 1) * 2) - 1);
    cloudsEnv = Amplitude.kr(sig.sum, 0.01, 0.2).clip(0, 1);
    cloudsDensityMod = (cloudsDensity + (cloudsEnv * cloudsEnvAmount)).clip(0, 1);
    cloudsTextureMod = (cloudsTexture + (cloudsEnv * (cloudsEnvAmount * 0.5))).clip(0, 1);
    cloudsWet = MiClouds.ar(
        sig * cloudsInputGain.clip(0, 2),
        pit: cloudsPitch.clip(-24, 24),
        pos: cloudsPosition.clip(0, 1),
        size: cloudsSize.clip(0, 1),
        dens: cloudsDensityMod,
        tex: cloudsTextureMod,
        drywet: 1,
        spread: cloudsSpread.clip(0, 1),
        rvb: cloudsReverb.clip(0, 1),
        fb: cloudsFeedback.clip(0, 0.99),
        freeze: cloudsFreeze.clip(0, 1),
        mode: cloudsMode.clip(0, 3)
    );
    sig = XFade2.ar(sig, cloudsWet, (cloudsMix.clip(0, 1) * 2) - 1);
    greyholeWet = Greyhole.ar(
        sig,
        ghDelayTime.clip(0.01, 5),
        ghDamp.clip(0, 1),
        ghSize.clip(0, 3),
        ghDiff.clip(0, 1),
        ghFeedback.clip(0, 0.99),
        ghModDepth.clip(0, 1),
        ghModFreq.clip(0, 10),
        ghEarlyDiff.clip(0, 1),
        ghSpread.clip(0, 1)
    );
    midDry = (sig[0] + sig[1]) * 0.5;
    sideDry = (sig[0] - sig[1]) * 0.5;
    midWet = (greyholeWet[0] + greyholeWet[1]) * 0.5;
    sideWet = (greyholeWet[0] - greyholeWet[1]) * 0.5;
    midMix = dryWet.clip(0, 1) * (1 - ghSideBias.clip(0, 1));
    sideMix = dryWet.clip(0, 1);
    midDry = XFade2.ar(midDry, midWet, (midMix * 2) - 1);
    sideDry = XFade2.ar(sideDry, sideWet, (sideMix * 2) - 1);
    sig = [midDry + sideDry, midDry - sideDry];
    midDry = (sig[0] + sig[1]) * 0.5;
    sideDry = (sig[0] - sig[1]) * 0.5;
    sideDry = HPF.ar(sideDry, sideHpfFreq.clip(80, 300));
    sig = [midDry + sideDry, midDry - sideDry];
    drive = 1 + satDrive.clip(0, 2);
    sig = (sig * drive).tanh;
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    sig = BPeakEQ.ar(sig, wideFreq, wideRQ, wideGain.lag(0.1));
    muteLevel = Lag.kr(1 - mute, 0.05);
    postFader = sig * gainAmp * muteLevel;
    Out.ar(outBus, postFader);
    Out.ar(auxBus, postFader * auxLevel.clip(0, 1));
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

~fxDefaults = (
    preHpfFreq: 10,
    preLowShelfFreq: 120,
    preLowShelfGain: 0,
    monoBassFreq: 60,
    autopanRate: 0.08,
    autopanDepth: 0,
    haasDelayL: 0.012,
    haasDelayR: 0.012,
    haasMix: 0,
    haasHighFreq: 700,
    allpassMix: 0,
    allpassTime: 0.012,
    allpassDecay: 0.1,
    ghSideBias: 0.6,
    sideHpfFreq: 80,
    satDrive: 0,
    cloudsMix: 0,
    cloudsPitch: 0,
    cloudsPosition: 0.5,
    cloudsSize: 0.4,
    cloudsDensity: 0.4,
    cloudsTexture: 0.4,
    cloudsFeedback: 0.3,
    cloudsFreeze: 0,
    cloudsMode: 0,
    cloudsSpread: 0.6,
    cloudsReverb: 0.2,
    cloudsInputGain: 1,
    cloudsEnvAmount: 0.3
);

~fxParamMap = (
    preHpfFreq: \preHpfFreq,
    preLowShelfFreq: \preLowShelfFreq,
    preLowShelfGain: \preLowShelfGain,
    monoBassFreq: \monoBassFreq,
    autopanRate: \autopanRate,
    autopanDepth: \autopanDepth,
    haasDelayL: \haasDelayL,
    haasDelayR: \haasDelayR,
    haasMix: \haasMix,
    haasHighFreq: \haasHighFreq,
    allpassMix: \allpassMix,
    allpassTime: \allpassTime,
    allpassDecay: \allpassDecay,
    ghSideBias: \ghSideBias,
    sideHpfFreq: \sideHpfFreq,
    satDrive: \satDrive,
    cloudsMix: \cloudsMix,
    cloudsPitch: \cloudsPitch,
    cloudsPosition: \cloudsPosition,
    cloudsSize: \cloudsSize,
    cloudsDensity: \cloudsDensity,
    cloudsTexture: \cloudsTexture,
    cloudsFeedback: \cloudsFeedback,
    cloudsFreeze: \cloudsFreeze,
    cloudsMode: \cloudsMode,
    cloudsSpread: \cloudsSpread,
    cloudsReverb: \cloudsReverb,
    cloudsInputGain: \cloudsInputGain,
    cloudsEnvAmount: \cloudsEnvAmount
);

~fxRanges = (
    preHpfFreq: [10, 200],
    preLowShelfFreq: [40, 300],
    preLowShelfGain: [-12, 12],
    monoBassFreq: [60, 200],
    autopanRate: [0.01, 2],
    autopanDepth: [0, 1],
    haasDelayL: [0.001, 0.03],
    haasDelayR: [0.001, 0.03],
    haasMix: [0, 1],
    haasHighFreq: [200, 4000],
    allpassMix: [0, 1],
    allpassTime: [0.001, 0.03],
    allpassDecay: [0.01, 1],
    ghSideBias: [0, 1],
    sideHpfFreq: [80, 300],
    satDrive: [0, 2],
    cloudsMix: [0, 1],
    cloudsPitch: [-24, 24],
    cloudsPosition: [0, 1],
    cloudsSize: [0, 1],
    cloudsDensity: [0, 1],
    cloudsTexture: [0, 1],
    cloudsFeedback: [0, 0.99],
    cloudsFreeze: [0, 1],
    cloudsMode: [0, 3],
    cloudsSpread: [0, 1],
    cloudsReverb: [0, 1],
    cloudsInputGain: [0, 2],
    cloudsEnvAmount: [0, 1]
);

~greyholeDefaults = (
    dryWet: 0,
    chorusDepth: 0.01,
    chorusDryWet: 0,
    chorusFeedback: 0.2,
    delayTime: 1.5,
    damp: 0.2,
    size: 1,
    diff: 0.7,
    feedback: 0.3,
    modDepth: 0.1,
    modFreq: 1,
    earlyDiff: 0.7,
    spread: 0.8
);

~greyholeParamMap = (
    dryWet: \dryWet,
    chorusDepth: \chorusDepth,
    chorusDryWet: \chorusDryWet,
    chorusFeedback: \chorusFeedback,
    delayTime: \ghDelayTime,
    damp: \ghDamp,
    size: \ghSize,
    diff: \ghDiff,
    feedback: \ghFeedback,
    modDepth: \ghModDepth,
    modFreq: \ghModFreq,
    earlyDiff: \ghEarlyDiff,
    spread: \ghSpread
);

~greyholeRanges = (
    dryWet: [0, 1],
    chorusDepth: [0, 1],
    chorusDryWet: [0, 1],
    chorusFeedback: [0, 1],
    delayTime: [0.01, 5],
    damp: [0, 1],
    size: [0, 3],
    diff: [0, 1],
    feedback: [0, 0.99],
    modDepth: [0, 1],
    modFreq: [0, 10],
    earlyDiff: [0, 1],
    spread: [0, 1]
);

~cleanupAudio = {
    [~channelSynths, ~drumSynths, ~limiterSynth, ~masterEqSynth, ~auxOutSynth, ~stereoInputSynth, ~reverbReturnSynth, ~airpodsOutSynth].do { |item|
        if(item.notNil) {
            if(item.isKindOf(Array)) {
                item.do(_.tryPerform(\free));
            } {
                item.tryPerform(\free);
            };
        };
    };

    [~inputGroup, ~fxGroup, ~outputGroup].do(_.tryPerform(\free));
    [~mixBus, ~masterBus, ~auxBus].do(_.tryPerform(\free));

    ~channelSynths = nil;
    ~drumSynths = nil;
    ~limiterSynth = nil;
    ~masterEqSynth = nil;
    ~mixBus = nil;
    ~masterBus = nil;
    ~auxBus = nil;
    ~inputGroup = nil;
    ~fxGroup = nil;
    ~outputGroup = nil;
    ~auxOutSynth = nil;
    ~stereoInputSynth = nil;
    ~reverbReturnSynth = nil;
    ~airpodsOutSynth = nil;
};

~setupAudio = {
    // Nettoyage si nécessaire
    ~cleanupAudio.value;

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.latency = 0.01;
    ~mixBus = Bus.audio(s, 2);
    ~masterBus = Bus.audio(s, 2);
    ~auxBus = Bus.audio(s, 2);

    ~inputGroup = Group.head(s);
    ~fxGroup = Group.after(~inputGroup);
    ~outputGroup = Group.after(~fxGroup);

    ~channelStates = Array.fill(~mixInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (
            gainDB: 0,
            eq: eqState,
            muted: 0,
            aux: 0,
            fx: ~fxDefaults.copy,
            greyhole: ~greyholeDefaults.copy
        );
    });

    ~drumStates = Array.fill(~drumInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (
            gainDB: 0,
            eq: eqState,
            muted: 0,
            aux: 0,
            fx: ~fxDefaults.copy,
            greyhole: ~greyholeDefaults.copy
        );
    });

    ~masterEqState = IdentityDictionary.new;
    [\low, \mid1, \mid2, \high].do { |band|
        ~masterEqState[band] = (~eqDefaults[band] ?? { IdentityDictionary.new }).copy;
    };

    ~stereoInputState = (gainDB: 0);
    ~reverbReturnState = (gainDB: 0);
    ~airpodsOutputState = (connected: 0);

    ~channelSynths = ~mixInputs.collect { |cfg, index|
        var state = ~channelStates[index];
        var fxState = state[\fx] ?? { ~fxDefaults.copy };
        Synth(\mixChannel, [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \auxBus, ~auxBus,
            \gainAmp, state[\gainDB].dbamp,
            \preHpfFreq, fxState[\preHpfFreq],
            \preLowShelfFreq, fxState[\preLowShelfFreq],
            \preLowShelfGain, fxState[\preLowShelfGain],
            \monoBassFreq, fxState[\monoBassFreq],
            \autopanRate, fxState[\autopanRate],
            \autopanDepth, fxState[\autopanDepth],
            \haasDelayL, fxState[\haasDelayL],
            \haasDelayR, fxState[\haasDelayR],
            \haasMix, fxState[\haasMix],
            \haasHighFreq, fxState[\haasHighFreq],
            \allpassMix, fxState[\allpassMix],
            \allpassTime, fxState[\allpassTime],
            \allpassDecay, fxState[\allpassDecay],
            \ghSideBias, fxState[\ghSideBias],
            \sideHpfFreq, fxState[\sideHpfFreq],
            \satDrive, fxState[\satDrive],
            \cloudsMix, fxState[\cloudsMix],
            \cloudsPitch, fxState[\cloudsPitch],
            \cloudsPosition, fxState[\cloudsPosition],
            \cloudsSize, fxState[\cloudsSize],
            \cloudsDensity, fxState[\cloudsDensity],
            \cloudsTexture, fxState[\cloudsTexture],
            \cloudsFeedback, fxState[\cloudsFeedback],
            \cloudsFreeze, fxState[\cloudsFreeze],
            \cloudsMode, fxState[\cloudsMode],
            \cloudsSpread, fxState[\cloudsSpread],
            \cloudsReverb, fxState[\cloudsReverb],
            \cloudsInputGain, fxState[\cloudsInputGain],
            \cloudsEnvAmount, fxState[\cloudsEnvAmount],
            \chorusDepth, state[\greyhole][\chorusDepth],
            \chorusDryWet, state[\greyhole][\chorusDryWet],
            \chorusFeedback, state[\greyhole][\chorusFeedback],
            \dryWet, state[\greyhole][\dryWet],
            \ghDelayTime, state[\greyhole][\delayTime],
            \ghDamp, state[\greyhole][\damp],
            \ghSize, state[\greyhole][\size],
            \ghDiff, state[\greyhole][\diff],
            \ghFeedback, state[\greyhole][\feedback],
            \ghModDepth, state[\greyhole][\modDepth],
            \ghModFreq, state[\greyhole][\modFreq],
            \ghEarlyDiff, state[\greyhole][\earlyDiff],
            \ghSpread, state[\greyhole][\spread],
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
            \auxLevel, state[\aux]
        ], target: ~inputGroup);
    };

    ~drumSynths = ~drumInputs.collect { |cfg, index|
        var state = ~drumStates[index];
        var fxState = state[\fx] ?? { ~fxDefaults.copy };
        Synth(\mixChannel, [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \auxBus, ~auxBus,
            \gainAmp, state[\gainDB].dbamp,
            \preHpfFreq, fxState[\preHpfFreq],
            \preLowShelfFreq, fxState[\preLowShelfFreq],
            \preLowShelfGain, fxState[\preLowShelfGain],
            \monoBassFreq, fxState[\monoBassFreq],
            \autopanRate, fxState[\autopanRate],
            \autopanDepth, fxState[\autopanDepth],
            \haasDelayL, fxState[\haasDelayL],
            \haasDelayR, fxState[\haasDelayR],
            \haasMix, fxState[\haasMix],
            \haasHighFreq, fxState[\haasHighFreq],
            \allpassMix, fxState[\allpassMix],
            \allpassTime, fxState[\allpassTime],
            \allpassDecay, fxState[\allpassDecay],
            \ghSideBias, fxState[\ghSideBias],
            \sideHpfFreq, fxState[\sideHpfFreq],
            \satDrive, fxState[\satDrive],
            \cloudsMix, fxState[\cloudsMix],
            \cloudsPitch, fxState[\cloudsPitch],
            \cloudsPosition, fxState[\cloudsPosition],
            \cloudsSize, fxState[\cloudsSize],
            \cloudsDensity, fxState[\cloudsDensity],
            \cloudsTexture, fxState[\cloudsTexture],
            \cloudsFeedback, fxState[\cloudsFeedback],
            \cloudsFreeze, fxState[\cloudsFreeze],
            \cloudsMode, fxState[\cloudsMode],
            \cloudsSpread, fxState[\cloudsSpread],
            \cloudsReverb, fxState[\cloudsReverb],
            \cloudsInputGain, fxState[\cloudsInputGain],
            \cloudsEnvAmount, fxState[\cloudsEnvAmount],
            \chorusDepth, state[\greyhole][\chorusDepth],
            \chorusDryWet, state[\greyhole][\chorusDryWet],
            \chorusFeedback, state[\greyhole][\chorusFeedback],
            \dryWet, state[\greyhole][\dryWet],
            \ghDelayTime, state[\greyhole][\delayTime],
            \ghDamp, state[\greyhole][\damp],
            \ghSize, state[\greyhole][\size],
            \ghDiff, state[\greyhole][\diff],
            \ghFeedback, state[\greyhole][\feedback],
            \ghModDepth, state[\greyhole][\modDepth],
            \ghModFreq, state[\greyhole][\modFreq],
            \ghEarlyDiff, state[\greyhole][\earlyDiff],
            \ghSpread, state[\greyhole][\spread],
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
            \auxLevel, state[\aux]
        ], target: ~inputGroup);
    };

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
    ~stereoInputSynth = Synth(\stereoInput, [
        \inA, 32,
        \inB, 33,
        \outBus, ~masterBus,
        \gainDB, ~stereoInputState[\gainDB]
    ], target: ~inputGroup, addAction: \addToHead);
    ~reverbReturnSynth = Synth(\reverbReturn, [
        \inA, 8,
        \inB, 9,
        \outBus, ~mixBus,
        \gainDB, ~reverbReturnState[\gainDB]
    ], target: ~inputGroup, addAction: \addToHead);
    ~auxOutSynth = SynthDef(\auxOutput, {
        |inBus = 0|
        Out.ar(2, In.ar(inBus, 2));
    }).play(target: ~outputGroup, args: [\inBus, ~auxBus], addAction: \addToTail);
    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~masterBus,
        \hardwareOut, 0
    ], target: ~outputGroup, addAction: \addToTail);
    ~airpodsOutSynth = nil;

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

    ~setChannelAux = { |index, send|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var level = send.clip(0, 1);
            ~channelStates[index][\aux] = level;
            synth.tryPerform(\set, \auxLevel, level);
        };
    };

    ~setChannelFx = { |index, param, value|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var state = ~channelStates[index][\fx] ?? { ~fxDefaults.copy };
            var key = ~fxParamMap[param];
            var range = ~fxRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~channelStates[index][\fx] = state;
            };
        };
    };

    ~setChannelGreyhole = { |index, param, value|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var state = ~channelStates[index][\greyhole];
            var key = ~greyholeParamMap[param];
            var range = ~greyholeRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~channelStates[index][\greyhole] = state;
            };
        };
    };

    ~setChannelChorus = { |index, param, value|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var state = ~channelStates[index][\greyhole];
            var key = ~greyholeParamMap[param];
            var range = ~greyholeRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~channelStates[index][\greyhole] = state;
            };
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

    ~setDrumGain = { |index, db|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            ~drumStates[index][\gainDB] = db;
            synth.tryPerform(\set, \gainAmp, db.dbamp);
        };
    };

    ~setDrumMute = { |index, muted|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            var muteValue = muted.clip(0, 1);
            ~drumStates[index][\muted] = muteValue;
            synth.tryPerform(\set, \mute, muteValue);
        };
    };

    ~setDrumAux = { |index, send|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            var level = send.clip(0, 1);
            ~drumStates[index][\aux] = level;
            synth.tryPerform(\set, \auxLevel, level);
        };
    };

    ~setDrumFx = { |index, param, value|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            var state = ~drumStates[index][\fx] ?? { ~fxDefaults.copy };
            var key = ~fxParamMap[param];
            var range = ~fxRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~drumStates[index][\fx] = state;
            };
        };
    };

    ~setDrumGreyhole = { |index, param, value|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            var state = ~drumStates[index][\greyhole];
            var key = ~greyholeParamMap[param];
            var range = ~greyholeRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~drumStates[index][\greyhole] = state;
            };
        };
    };

    ~setDrumChorus = { |index, param, value|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var synth = ~drumSynths[index];
            var state = ~drumStates[index][\greyhole];
            var key = ~greyholeParamMap[param];
            var range = ~greyholeRanges[param];

            if(key.notNil and: { range.notNil } and: { value.notNil }) {
                var clipped = value.clip(range[0], range[1]);
                state[param] = clipped;
                synth.tryPerform(\set, key, clipped);
                ~drumStates[index][\greyhole] = state;
            };
        };
    };

    ~setDrumEq = { |index, band, freq, gain, q|
        if((index >= 0) and: { index < ~drumSynths.size }) {
            var params = ~eqParamMap[band];
            var synth = ~drumSynths[index];
            if(params.notNil) {
                var rq = q.reciprocal;
                synth.tryPerform(\set,
                    params[\freqKey], freq,
                    params[\gainKey], gain,
                    params[\qKey], rq
                );
            };
            ~drumStates[index][\eq][band] = (freq: freq, gain: gain, q: q);
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

    ~setStereoInputGain = { |gainDB|
        ~stereoInputState[\gainDB] = gainDB;
        ~stereoInputSynth.tryPerform(\set, \gainDB, gainDB);
    };

    ~setReverbReturnGain = { |gainDB|
        ~reverbReturnState[\gainDB] = gainDB;
        ~reverbReturnSynth.tryPerform(\set, \gainDB, gainDB);
    };

    ~setAirpodsOutput = { |connected|
        var isConnected = connected.clip(0, 1);
        ~airpodsOutputState[\connected] = isConnected;
        if(isConnected == 1) {
            if(~airpodsOutSynth.isNil) {
                ~airpodsOutSynth = Synth(\outputLimiter, [
                    \input, ~masterBus,
                    \hardwareOut, 68
                ], target: ~outputGroup, addAction: \addToTail);
            };
        } {
            ~airpodsOutSynth.tryPerform(\free);
            ~airpodsOutSynth = nil;
        };
    };

    ~getChannelState = { |index|
        ~channelStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState, muted: 0, aux: 0, fx: ~fxDefaults.copy, greyhole: ~greyholeDefaults.copy);
        };
    };

    ~getDrumState = { |index|
        ~drumStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState, muted: 0, aux: 0, fx: ~fxDefaults.copy, greyhole: ~greyholeDefaults.copy);
        };
    };

    ~getMasterEqState = {
        ~masterEqState;
    };

    ~getStereoInputState = { ~stereoInputState };

    ~getReverbReturnState = { ~reverbReturnState };

    ~getAirpodsOutputState = { ~airpodsOutputState };

    CmdPeriod.doOnce({ ~cleanupAudio.value });
};
