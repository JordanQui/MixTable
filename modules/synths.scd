// ================= Limiteur global =================
SynthDef(\outputLimiter, { |input = 0, out = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01);
    Out.ar(out, limited.tanh);
}).add;

// ================= Voix Mutable Instruments Braids =================
~rootNote = ~rootNote ?? { 0 };
~scale = ~scale ?? { Scale.chromatic };
~enableBraidsVoicer = ~enableBraidsVoicer ?? { true };

SynthDef(\braidsVoice, {
    |out = 0, freq = 440, vel = 1, amp = 1, mod = 0, bend = 0, gate = 1|
    var pitch, env, timbre, color, trig, sig;
    pitch = freq * bend.midiratio;
    timbre = mod.linlin(0, 1, 0.05, 0.95);
    color = amp.clip(0, 1);
    trig = (vel > 0).if(1, 0);
    env = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 2);
    sig = MiBraids.ar(pitch, timbre: timbre, color: color, model: 0, trig: trig, resamp: 2);
    sig = sig * (vel.clip(0, 1) * amp.clip(0, 1)) * env;
    Out.ar(out, sig!2);
}).add;

~configureBraidsVoicer = {
    |uid, voicer, bank, out|
    var midiDefs = List.new;

    voicer.indivParams;
    voicer.roli.prime(\braidsVoice);

    voicer.makeNote = { |q, chan, note = 60, vel = 64|
        voicer.roli.put(chan, [
            \freq, (note + ~rootNote).keyToDegree(~scale, 12).degreeToKey(~scale).midicps,
            \vel, (vel / 127),
            \amp, 1,
            \gate, 1,
            \out, out
        ]);
    };

    voicer.endNote = { |q, chan|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\gate, 0) };
    };

    voicer.setTouch = { |q, chan = 0, touchval = 64|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\amp, (touchval / 127)) };
    };

    voicer.setSlide = { |q, chan = 0, slide = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\mod, (slide / 127)) };
    };

    voicer.setBend = { |q, chan = 0, bendval = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) {
            obj.set(\bend, bendval.linlin(0, 16383, -36, 36))
        };
    };

    midiDefs.add(MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
        voicer.makeNote(chan, noteNum, vel);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
        voicer.endNote(chan, noteNum);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
        voicer.setSlide(chan, val);
    }, 1, srcID: uid).enable);

    midiDefs.add(MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
        voicer.setTouch(chan, val);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.bend(\roliBend ++ out, { |bend, chan|
        voicer.setBend(chan, bend);
    }, srcID: uid).enable);

    midiDefs
};

// ================= Mixage et gestion des bus =================

// Définitions des tranches d'entrée : 1 (mono), 3/4, 5/6, 7/8
~braidsMidiDefs = ~braidsMidiDefs ?? { List.new };

~defaultMixInputs = [
    (label: "1",     channels: [0, 0], isMono: 1, useSoundIn: 1),
    (label: "3 / 4", channels: [2, 3], isMono: 0, useSoundIn: 1),
    (label: "5 / 6", channels: [4, 5], isMono: 0, useSoundIn: 1),
    (label: "7 / 8", channels: [6, 7], isMono: 0, useSoundIn: 1)
];
~mixInputs = ~defaultMixInputs.collect(_.copy);

// SynthDef pour chaque tranche d'entrée avec égalisation 4 bandes
SynthDef(\mixChannel, {
    |inA = 0, inB = 1, isMono = 0, outBus = 0, useSoundIn = 1,
    gainAmp = 1, mute = 0,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0|
    var stereo, mono, sig, muteLevel;
    if(useSoundIn > 0.5) {
        stereo = SoundIn.ar([inA, inB]);
        mono = SoundIn.ar(inA) ! 2;
    } {
        stereo = In.ar(inA, 2);
        mono = In.ar(inA, 1) ! 2;
    };
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    muteLevel = Lag.kr(1 - mute, 0.05);
    sig = sig * gainAmp * muteLevel;
    Out.ar(outBus, sig);
}).add;

// Paramètres d'égalisation par défaut
~eqDefaults = (
    low:  (freq: 120,  gain: 0, q: 1),
    mid1: (freq: 500,  gain: 0, q: 1),
    mid2: (freq: 2000, gain: 0, q: 1),
    high: (freq: 8000, gain: 0, q: 1)
);

~eqParamMap = (
    low:  (freqKey: \lowFreq,  gainKey: \lowGain,  qKey: \lowRQ),
    mid1: (freqKey: \mid1Freq, gainKey: \mid1Gain, qKey: \mid1RQ),
    mid2: (freqKey: \mid2Freq, gainKey: \mid2Gain, qKey: \mid2RQ),
    high: (freqKey: \highFreq, gainKey: \highGain, qKey: \highRQ)
);

~setupAudio = {
    // Nettoyage si nécessaire
    [~channelSynths, ~limiterSynth, ~braidsVoicer].do { |item|
        if(item.notNil) {
            if(item.isKindOf(Array)) {
                item.do(_.tryPerform(\free));
            } {
                item.tryPerform(\free);
            };
        };
    };

    ~braidsVoicer = nil;

    ~braidsMidiDefs.do { |def| def.tryPerform(\free) };
    ~braidsMidiDefs = List.new;

    [~voiceGroup, ~inputGroup, ~outputGroup].do(_.tryPerform(\free));
    [~mixBus, ~voiceBus].do { |bus| bus.tryPerform(\free) };
    ~voiceBus = nil;

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.sync;

    ~mixBus = Bus.audio(s, 2);

    ~mixInputs = ~defaultMixInputs.collect(_.copy);

    ~voiceGroup = Group.head(s);
    ~inputGroup = Group.after(~voiceGroup);
    ~outputGroup = Group.after(~inputGroup);

    if(~enableBraidsVoicer ?? { true }) {
        if(thisProcess.interpreter.notNil and: { NPVoicer.notNil }) {
            var iacSource, uid;
            MIDIClient.init;
            iacSource = MIDIClient.sources.detect { |src|
                var name = [src.device, src.name].collect(_.asString).join(" ");
                name.contains("IAC");
            };
            if(iacSource.notNil) {
                uid = iacSource.uid;
                ~voiceBus = Bus.audio(s, 2);
                ~mixInputs[0] = ~mixInputs[0].copy.putAll((
                    label: "NPV Braids",
                    channels: [~voiceBus.index, ~voiceBus.index + 1],
                    isMono: 0,
                    useSoundIn: 0
                ));
                ~braidsVoicer = NPVoicer(15, \braidsVoice, target: ~voiceGroup, out: ~voiceBus.index);
                if(~braidsVoicer.notNil) {
                    ~braidsMidiDefs.do { |def| def.tryPerform(\free) };
                    ~braidsMidiDefs = ~configureBraidsVoicer.value(uid, ~braidsVoicer, nil, ~voiceBus.index);
                } {
                    "Impossible de créer le NPVoicer pour la voix Braids.".warn;
                    ~mixInputs[0] = ~defaultMixInputs[0].copy;
                    ~voiceBus.tryPerform(\free);
                    ~voiceBus = nil;
                };
            } {
                "Aucune source MIDI IAC trouvée pour le NPVoicer.".warn;
            };
        } {
            "NPVoicer n'est pas disponible dans cet environnement.".warn;
        };
    };

    ~channelStates = Array.fill(~mixInputs.size, {
        var eqState = IdentityDictionary.new;
        ~eqDefaults.keysValuesDo { |band, defaults|
            eqState[band] = defaults.copy;
        };
        (gainDB: 0, eq: eqState, muted: 0);
    });

    ~channelSynths = ~mixInputs.collect { |cfg, index|
        var state = ~channelStates[index];
        Synth(\mixChannel, [
            \inA, cfg[\channels][0],
            \inB, cfg[\channels][1],
            \isMono, cfg[\isMono],
            \outBus, ~mixBus,
            \useSoundIn, cfg[\useSoundIn] ?? { 1 },
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
            \mute, state[\muted]
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

    ~getChannelState = { |index|
        ~channelStates[index] ?? {
            var eqState = IdentityDictionary.new;
            ~eqDefaults.keysValuesDo { |band, defaults|
                eqState[band] = defaults.copy;
            };
            (gainDB: 0, eq: eqState, muted: 0);
        };
    };

    CmdPeriod.doOnce({
        [~channelSynths, ~limiterSynth, ~braidsVoicer].do { |item|
            if(item.notNil) {
                if(item.isKindOf(Array)) { item.do(_.tryPerform(\free)) } { item.tryPerform(\free) };
            };
        };
        ~braidsMidiDefs.do { |def| def.tryPerform(\free) };
        [~mixBus, ~voiceBus].do { |bus| bus.tryPerform(\free) };
        [~voiceGroup, ~inputGroup, ~outputGroup].do(_.tryPerform(\free));
        ~voiceBus = nil;
        ~braidsVoicer = nil;
    });
};
