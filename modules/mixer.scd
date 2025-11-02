// ================= Traitements globaux =================
SynthDef(\outputLimiter, { |input = 0, hardwareOut = 0|
    var inSig = In.ar(input, 2);
    var limited = Limiter.ar(inSig, 0.99, 0.01).tanh;
    Out.ar(hardwareOut, limited);
}).add;

SynthDef(\masterVSTInsert, { |inBus = 0, outBus = 0, bypass = 1|
    var input = In.ar(inBus, 2);
    var processed = VSTPlugin.ar(input, 2, id: \masterInsert);
    var bypassMix = bypass.clip(0, 1);
    var output = (processed * (1 - bypassMix)) + (input * bypassMix);
    ReplaceOut.ar(outBus, output);
}).add;

SynthDef(\vstSendEffect, { |inBus = 0, outBus = 0, bypass = 1|
    var input = In.ar(inBus, 2);
    var processed = VSTPlugin.ar(input, 2, id: \sendEffect);
    var active = 1 - bypass.clip(0, 1);
    Out.ar(outBus, processed * active);
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
    |inA = 0, inB = 1, isMono = 0, outBus = 0,
    gainAmp = 1, mute = 0,
    lowFreq = 120, lowRQ = 1, lowGain = 0,
    mid1Freq = 500, mid1RQ = 1, mid1Gain = 0,
    mid2Freq = 2000, mid2RQ = 1, mid2Gain = 0,
    highFreq = 8000, highRQ = 1, highGain = 0,
    wideFreq = 1200, wideRQ = 1, wideGain = 0,
    revMix = 0, reverbSendBus = 0|
    var stereo, mono, sig, muteLevel, dryLevel, sendLevel;
    stereo = SoundIn.ar([inA, inB]);
    mono = SoundIn.ar(inA) ! 2;
    sig = (stereo * (1 - isMono)) + (mono * isMono);
    sig = BLowShelf.ar(sig, lowFreq, lowRQ, lowGain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid1Freq, mid1RQ, mid1Gain.lag(0.1));
    sig = BPeakEQ.ar(sig, mid2Freq, mid2RQ, mid2Gain.lag(0.1));
    sig = BHiShelf.ar(sig, highFreq, highRQ, highGain.lag(0.1));
    sig = BPeakEQ.ar(sig, wideFreq, wideRQ, wideGain.lag(0.1));
    revMix = Lag.kr(revMix.clip(0, 1), 0.1);
    muteLevel = Lag.kr(1 - mute, 0.05);
    sig = sig * gainAmp * muteLevel;
    dryLevel = sig * (1 - revMix);
    sendLevel = sig * revMix;
    Out.ar(outBus, dryLevel);
    Out.ar(reverbSendBus, sendLevel);
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

// Configuration des VST externes : ajustez ~vstSettings avant ~setupAudio
// pour spécifier les chemins de recherche ou des emplacements précis.
~vstSettings = ~vstSettings ?? { IdentityDictionary.new };
~vstSettings[\searchPaths] = (~vstSettings[\searchPaths] ?? { [] }).as(Array);
~vstSettings[\plugins] = (~vstSettings[\plugins] ?? { IdentityDictionary.new }).copy;

{
    var existing = ~vstSettings[\plugins][\reverb] ?? { IdentityDictionary.new };
    ~vstSettings[\plugins][\reverb] = (
        name: existing[\name] ?? { "Aaltoverb 2" },
        path: existing[\path]
    );
}.value;

{
    var existing = ~vstSettings[\plugins][\master] ?? { IdentityDictionary.new };
    ~vstSettings[\plugins][\master] = (
        name: existing[\name] ?? { "Ozone Stabilizer" },
        path: existing[\path]
    );
}.value;

~registeredVstPaths = ~registeredVstPaths ?? { [] };

~ensureVSTSearchPaths = {
    var paths = ~vstSettings[\searchPaths].reject({ |path|
        var str = path.tryPerform(\asString) ?? { "" };
        str.trim.size == 0
    });
    var standardizedPaths = paths.collect({ |p| p.asString.standardizePath }).as(Array);
    if(standardizedPaths != ~registeredVstPaths) {
        standardizedPaths.do { |path|
            VSTPlugin.search(path, useCache: true, wait: true, verbose: false);
        };
        if(standardizedPaths.notEmpty) {
            (~"Chemins VST enregistrés: " ++ standardizedPaths).postln;
        };
        ~registeredVstPaths = standardizedPaths;
    };
};

~resolvePluginIdentifier = { |key|
    var plugins = ~vstSettings[\plugins] ?? { IdentityDictionary.new };
    var plugin = plugins[key];
    var pluginPath, pluginName;
    if(plugin.isNil) { ^nil };
    pluginPath = plugin[\path];
    if(pluginPath.notNil and: { pluginPath.asString.trim.size > 0 }) {
        ^pluginPath.asString.standardizePath;
    };
    pluginName = plugin[\name];
    if(pluginName.notNil and: { pluginName.asString.trim.size > 0 }) {
        ^pluginName;
    };
    ^nil;
};

~describePlugin = { |key|
    var plugins = ~vstSettings[\plugins] ?? { IdentityDictionary.new };
    var plugin = plugins[key];
    var pluginName, pluginPath;
    if(plugin.isNil) { ^key.asString };
    pluginName = plugin[\name];
    if(pluginName.notNil and: { pluginName.asString.trim.size > 0 }) {
        ^pluginName;
    };
    pluginPath = plugin[\path];
    if(pluginPath.notNil and: { pluginPath.asString.trim.size > 0 }) {
        var pathName = PathName(pluginPath);
        ^(pathName.fileName ?? { pluginPath.asString.standardizePath });
    };
    ^key.asString;
};

~cleanupAudio = {
    [~masterVSTController, ~reverbVSTController].do { |controller|
        controller.tryPerform(\close);
    };

    [~channelSynths, ~limiterSynth, ~masterInsertSynth, ~reverbVSTSynth].do { |item|
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
    ~postMasterBus.tryPerform(\free);
    ~reverbBus.tryPerform(\free);

    ~channelSynths = nil;
    ~limiterSynth = nil;
    ~masterInsertSynth = nil;
    ~reverbVSTSynth = nil;
    ~mixBus = nil;
    ~postMasterBus = nil;
    ~reverbBus = nil;
    ~inputGroup = nil;
    ~outputGroup = nil;
    ~masterVSTController = nil;
    ~reverbVSTController = nil;
};

~setupAudio = {
    var controllerClass;
    // Nettoyage si nécessaire
    ~cleanupAudio.value;

    // S'assurer que toutes les définitions de synthés précédemment envoyées
    // ont bien été traitées par le serveur avant d'instancier de nouveaux nodes.
    s.latency = 0.01;
    ~mixBus = Bus.audio(s, 2);
    ~postMasterBus = Bus.audio(s, 2);
    ~reverbBus = Bus.audio(s, 2);

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
            \revMix, state[\reverbMix],
            \reverbSendBus, ~reverbBus,
            \mute, state[\muted]
        ], target: ~inputGroup);
    };

    controllerClass = \VSTPluginController.asClass;

    ~reverbVSTSynth = Synth(\vstSendEffect, [
        \inBus, ~reverbBus,
        \outBus, ~mixBus,
        \bypass, 1
    ], target: ~outputGroup, addAction: \addToHead);

    if(controllerClass.isNil) {
        "Le quark VSTPlugin est requis pour utiliser l'effet de reverb externe.".warn;
        ~reverbVSTSynth.tryPerform(\set, \bypass, 1);
    } {
        {
            var reverbIdentifier, reverbLabel;
            ~ensureVSTSearchPaths.value;
            reverbIdentifier = ~resolvePluginIdentifier.value(\reverb);
            reverbLabel = ~describePlugin.value(\reverb);
            if(reverbIdentifier.isNil) {
                ("Aucun VST configuré pour l'envoi : " ++ reverbLabel).warn;
                ~reverbVSTSynth.tryPerform(\set, \bypass, 1);
            } {
                ~reverbVSTController = controllerClass.new(~reverbVSTSynth, \sendEffect);
                ~reverbVSTController.open(reverbIdentifier, action: { |ctl, success|
                    if(success) {
                        ("VST '" ++ reverbLabel ++ "' chargé sur le départ auxiliaire.").postln;
                        ~reverbVSTSynth.tryPerform(\set, \bypass, 0);
                    } {
                        ("Impossible d'ouvrir le VST '" ++ reverbLabel ++ "'.").warn;
                        ~reverbVSTSynth.tryPerform(\set, \bypass, 1);
                    };
                });
            };
        }.try({ |error|
            ("Erreur lors de l'initialisation du VST d'envoi : " ++ error).warn;
            ~reverbVSTSynth.tryPerform(\set, \bypass, 1);
            ~reverbVSTController = nil;
        });
    };

    ~masterInsertSynth = Synth(\masterVSTInsert, [
        \inBus, ~mixBus,
        \outBus, ~postMasterBus,
        \bypass, 1
    ], target: ~outputGroup, addAction: \addToTail);

    if(controllerClass.isNil) {
        "Le quark VSTPlugin est requis pour charger le traitement master externe.".warn;
        ~masterInsertSynth.tryPerform(\set, \bypass, 1);
    } {
        {
            var masterIdentifier, masterLabel;
            ~ensureVSTSearchPaths.value;
            masterIdentifier = ~resolvePluginIdentifier.value(\master);
            masterLabel = ~describePlugin.value(\master);
            if(masterIdentifier.isNil) {
                ("Aucun VST configuré pour le master : " ++ masterLabel).warn;
                ~masterInsertSynth.tryPerform(\set, \bypass, 1);
            } {
                ~masterVSTController = controllerClass.new(~masterInsertSynth, \masterInsert);
                ~masterVSTController.open(masterIdentifier, action: { |ctl, success|
                    if(success) {
                        ("VST '" ++ masterLabel ++ "' chargé sur le master.").postln;
                        ~masterInsertSynth.tryPerform(\set, \bypass, 0);
                    } {
                        ("Impossible d'ouvrir le VST '" ++ masterLabel ++ "'.").warn;
                        ~masterInsertSynth.tryPerform(\set, \bypass, 1);
                    };
                });
            };
        }.try({ |error|
            ("Erreur lors de l'initialisation du VST master : " ++ error).warn;
            ~masterInsertSynth.tryPerform(\set, \bypass, 1);
            ~masterVSTController = nil;
        });
    };

    ~limiterSynth = Synth(\outputLimiter, [
        \input, ~postMasterBus,
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
