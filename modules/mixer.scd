// ================= Limiteur global =================
SynthDef(\outputLimiter, { |input = 0, hardwareOut = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01).tanh;
    Out.ar(hardwareOut, limited);
}).add;

// ================= Mixage et gestion des bus =================

// Définitions des tranches d'entrée
~defaultReverbFrameSize = 2048;
~reverbFrameSize = ~defaultReverbFrameSize;

~mixInputs = [
    (label: "3 / 4",  channels: [2, 3],   isMono: 0),
    (label: "5 / 6",  channels: [4, 5],   isMono: 0),
    (label: "7 / 8",  channels: [6, 7],   isMono: 0),
    (label: "15 / 16", channels: [14, 15], isMono: 0),
    (label: "17 / 18", channels: [16, 17], isMono: 0)
];

// SynthDef pour chaque tranche d'entrée avec égalisation 4 bandes
SynthDef(\mixChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0,
    gainAmp = 1, mute = 0,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0,
    wideFreq = 1200, wideRQ = 1, wideGain = 0,
    convBuf = 0, revMix = 0|
    var stereo, mono, sig, muteLevel, dry, wet;
    stereo = SoundIn.ar([inA, inB]);
    mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    sig = BPeakEQ.ar(sig, wideFreq, wideRQ, wideGain.lag(0.1));
    dry = sig;
    wet = Convolution2.ar(sig, convBuf, 1, (~reverbFrameSize ?? { ~defaultReverbFrameSize }));
    revMix = Lag.kr(revMix.clip(0, 1), 0.1);
    sig = (dry * (1 - revMix)) + (wet * revMix);
    muteLevel = Lag.kr(1 - mute, 0.05);
    sig = sig * gainAmp * muteLevel;
    Out.ar(outBus, sig);
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

~ensureReverbBuffer = { |irPath = nil|
    var resolvedPath, irExists, soundFile, frameSize, fallbackSize, envelope, impulse;

    resolvedPath = irPath ?? {
        ~ezConvIRPath ?? { (~projectRoot +/+ (~ezConvIRRelativePath ?? { "IRs/IR1.wav" })).standardizePath };
    };

    ~reverbBuffer.tryPerform(\free);

    irExists = resolvedPath.notNil and: { File.exists(resolvedPath) };

    if(irExists) {
        soundFile = SoundFile.openRead(resolvedPath);
        if(soundFile.notNil) {
            frameSize = soundFile.numFrames.max(1).nextPowerOfTwo;
            soundFile.close;
            soundFile.free;
            ~reverbFrameSize = frameSize;
            ~reverbBuffer = Buffer.readChannel(
                s,
                resolvedPath,
                startFrame: 0,
                numFrames: frameSize,
                channels: [0]
            );
            ^nil;
        };
    };

    if(resolvedPath.notNil and: { irExists.not }) {
        ("Impulse response introuvable: " ++ resolvedPath).warn;
    };

    fallbackSize = (~defaultReverbFrameSize ?? { 2048 }).max(128).nextPowerOfTwo;
    ~reverbFrameSize = fallbackSize;
    envelope = Env.perc(0.001, 1.2, curve: -4).asSignal(fallbackSize);
    impulse = FloatArray.newClear(fallbackSize);
    fallbackSize.do { |index|
        impulse[index] = envelope[index] * rrand(-0.3, 0.3);
    };
    impulse[0] = impulse[0] + 1.0;
    ~reverbBuffer = Buffer.loadCollection(s, impulse);
};

~cleanupAudio = {
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
    ~reverbBuffer.tryPerform(\free);

    ~channelSynths = nil;
    ~limiterSynth = nil;
    ~mixBus = nil;
    ~inputGroup = nil;
    ~outputGroup = nil;
    ~reverbBuffer = nil;
    ~reverbFrameSize = ~defaultReverbFrameSize;
};

~setupAudio = {
    var irPath;
    // Nettoyage si nécessaire
    ~cleanupAudio.value;

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.latency = 0.002;
    irPath = ~ezConvIRPath ?? {
        (~projectRoot +/+ (~ezConvIRRelativePath ?? { "IRs/IR1.wav" })).standardizePath;
    };
    ~ensureReverbBuffer.value(irPath);
    s.sync;

    ~mixBus = Bus.audio(s, 2);

    ~inputGroup = Group.head(s);
    ~outputGroup = Group.after(~inputGroup);

    ~channelStates = Array.fill(~mixInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (gainDB: 0, eq: eqState, muted: 0, reverbMix: 0);
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
            \convBuf, ~reverbBuffer.bufnum,
            \revMix, state[\reverbMix],
            \mute, state[\muted]
        ], target: ~inputGroup);
    };

    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~mixBus,
        \hardwareOut, 0
    ], target: ~outputGroup);

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

    ~setChannelReverbMix = { |index, mix|
        if((index >= 0) and: { index < ~channelSynths.size }) {
            var synth = ~channelSynths[index];
            var mixValue = mix.clip(0, 1);
            ~channelStates[index][\reverbMix] = mixValue;
            synth.tryPerform(\set, \revMix, mixValue);
        };
    };

    ~getChannelState = { |index|
        ~channelStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState, muted: 0, reverbMix: 0);
        };
    };

    CmdPeriod.doOnce({ ~cleanupAudio.value });
};
