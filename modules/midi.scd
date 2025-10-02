if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setMidiSynthForKey = { |key, synthKey|
    var normalizedKey = ~normalizeSynthKey.(key);
    var normalizedSynth = ~normalizeSynthKey.(synthKey);
    var library = ~midiSynthLibrary;
    if(normalizedKey.isNil) {
        ("[MIDI] Impossible d'enregistrer le synthé : clef invalide %".format(key)).warn;
        ^nil;
    };
    if(library.isNil) {
        ("[MIDI] Bibliothèque de synthés MIDI indisponible").warn;
        ^nil;
    };
    if(normalizedSynth.isNil or: { library.includesKey(normalizedSynth).not }) {
        ("[MIDI] Synthé inconnu %".format(synthKey)).warn;
        ^nil;
    };
    if(normalizedKey == \default) {
        ^~setCurrentMidiSynth.(normalizedSynth);
    } {
        ~midiSynthRouting[normalizedKey] = normalizedSynth;
        ("[MIDI] Clef % associée au synthé %".format(normalizedKey, normalizedSynth)).postln;
    };
};

~setCurrentMidiSynth = { |synthKey|
    var result = ~setCurrentSynth.(synthKey);
    if(result.notNil) {
        ("[MIDI] Synthé MIDI courant -> %".format(result)).postln;
    };
    result;
};

~setActiveMidiSynth = { |key| ^~setCurrentMidiSynth.(key); };

~getDefaultMidiSynthKey = {
    var key = ~defaultMidiSynth ?? { \percussiveSine };
    if(key.respondsTo(\asSymbol)) {
        ^key.asSymbol;
    } {
        ^\percussiveSine;
    };
};

~getMidiSynthSelection = { |synthKey|
    var library = ~midiSynthLibrary;
    var defaultKey = ~getDefaultMidiSynthKey.();
    var resolvedKey = synthKey;
    if(library.isNil) {
        ("[MIDI] Bibliothèque de synthés indisponible, retour à %".format(defaultKey)).warn;
        ^(key: defaultKey, config: IdentityDictionary.new);
    };
    if(resolvedKey.respondsTo(\asSymbol)) {
        resolvedKey = resolvedKey.asSymbol;
    } {
        resolvedKey = defaultKey;
    };
    if(library.includesKey(resolvedKey).not) {
        ("[MIDI] Synthé % introuvable, retour à %".format(resolvedKey, defaultKey)).warn;
        resolvedKey = defaultKey;
    };
    (key: resolvedKey, config: library[resolvedKey] ?? { IdentityDictionary.new });
};

~getCurrentMidiSynthSelection = {
    var key = ~currentMidiSynthKey ?? { ~midiSynthRouting.tryPerform(\at, \default) };
    if(key.isNil) {
        key = ~getDefaultMidiSynthKey.();
    };
    ~getMidiSynthSelection.(key);
};

~setupMidi = {
    var matchDevice, makeKey;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    ~activeMidiSynths.tryPerform(\valuesDo, { |entry|
        var synth = entry.tryPerform(\at, \synth) ?? { entry };
        synth.tryPerform(\set, \gate, 0);
    });
    ~activeMidiSynths = Dictionary.new;
    ~midiCCValues = IdentityDictionary.new;

    MIDIIn.disconnectAll;
    MIDIIn.connectAll;

    makeKey = { |src, channel, note|
        "%:%:%".format(src, channel, note);
    };

    matchDevice = { |src|
        var source;

        source = MIDIClient.sources.detect { |endpoint|
            endpoint.uid == src
        };

        source.notNil and: {
            source.device == "TransBus" and: { source.name == "SC1" }
        }
    };

    {
        var selection = ~getCurrentMidiSynthSelection.();
        ~currentMidiSynthKey = selection[\key];
    }.value;

    ~midiResponders.add(MIDIFunc.noteOn({ |velocity, note, channel, src|
        var deviceMatches = matchDevice.(src);
        ("[MIDI] noteOn src:% channel:% note:% velocity:% match:%"
            .format(src, channel, note, velocity, deviceMatches)).postln;
        if(deviceMatches) {
            var key = makeKey.(src, channel, note);
            if(velocity <= 0) {
                var entry = ~activeMidiSynths.removeAt(key);
                var synth = entry.tryPerform(\at, \synth) ?? { entry };
                ("[MIDI] noteOn treated as noteOff key:% synth:%"
                    .format(key, synth)).postln;
                synth.tryPerform(\set, \gate, 0);
            } {
                var freq, amp, outBus, existingEntry, existingSynth, synth, synthKey, config, selection;
                var ccValue, args, channelCCValue, ccParam, ccDefault, ccMap, extraArgs;
                freq = note.midicps;
                amp = velocity.linlin(1, 127, 0.02, 0.5);
                outBus = ~directBus ?? { 0 };
                existingEntry = ~activeMidiSynths.removeAt(key);
                existingSynth = existingEntry.tryPerform(\at, \synth) ?? { existingEntry };
                ("[MIDI] stopping existing synth for key:% -> %"
                    .format(key, existingSynth)).postln;
                existingSynth.tryPerform(\set, \gate, 0);
                selection = ~getCurrentMidiSynthSelection.();
                synthKey = selection[\key];
                config = selection[\config];
                ~currentMidiSynthKey = synthKey;
                ccParam = config[\ccParam];
                ccMap = config[\ccMap] ?? { |val| val };
                ccDefault = config[\ccDefault] ?? { 74 };
                channelCCValue = ~midiCCValues[channel];
                if(channelCCValue.isNil) {
                    channelCCValue = ccDefault;
                    ~midiCCValues[channel] = channelCCValue;
                };
                ccValue = ccMap.(channelCCValue);
                extraArgs = config[\extraArgs].tryPerform(\value, freq, velocity, amp) ?? { [] };
                args = [
                    \freq, freq,
                    \amp, amp,
                    \out, outBus
                ];
                if(ccParam.notNil) {
                    args = args ++ [ccParam, ccValue];
                };
                args = args ++ extraArgs;
                synth = Synth(synthKey, args);
                ("[MIDI] started % synth % for key:% freq:% amp:% out:% ccValue:%"
                    .format(synthKey, synth, key, freq, amp, outBus, ccValue)).postln;
                ~activeMidiSynths[key] = (synth: synth, type: synthKey, channel: channel);
            };
        } {
            ("[MIDI] noteOn ignored - device mismatch for src:%"
                .format(src)).postln;
        };
    }));

    ~midiResponders.add(MIDIFunc.noteOff({ |velocity, note, channel, src|
        var deviceMatches = matchDevice.(src);
        ("[MIDI] noteOff src:% channel:% note:% velocity:% match:%"
            .format(src, channel, note, velocity, deviceMatches)).postln;
        if(deviceMatches) {
            var key = makeKey.(src, channel, note);
            var entry = ~activeMidiSynths.removeAt(key);
            var synth = entry.tryPerform(\at, \synth) ?? { entry };
            ("[MIDI] noteOff releasing synth for key:% -> %"
                .format(key, synth)).postln;
            synth.tryPerform(\set, \gate, 0);
        } {
            ("[MIDI] noteOff ignored - device mismatch for src:%"
                .format(src)).postln;
        };
    }));

    ~midiResponders.add(MIDIFunc.cc({ |value, ccNum, channel, src|
        var deviceMatches = matchDevice.(src);
        ("[MIDI] cc src:% channel:% cc:% value:% match:%"
            .format(src, channel, ccNum, value, deviceMatches)).postln;
        if(deviceMatches) {
            ~midiCCValues[channel] = value;
            ~activeMidiSynths.tryPerform(\valuesDo, { |entry|
                var synth = entry.tryPerform(\at, \synth);
                var type = entry.tryPerform(\at, \type);
                var entryChannel = entry.tryPerform(\at, \channel);
                var configData, config, ccParam, ccMap;
                if((synth.notNil) and: { entryChannel == channel }) {
                    configData = ~getMidiSynthSelection.(type);
                    config = configData[\config];
                    entry[\type] = configData[\key];
                    ccParam = config[\ccParam];
                    ccMap = config[\ccMap] ?? { |val| val };
                    if(ccParam.notNil) {
                        synth.tryPerform(\set, ccParam, ccMap.(value));
                    };
                };
            });
        };
    }, 74));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
        ~activeMidiSynths.tryPerform(\valuesDo, { |entry|
            var synth = entry.tryPerform(\at, \synth) ?? { entry };
            synth.tryPerform(\set, \gate, 0);
        });
        ~activeMidiSynths = nil;
        ~midiCCValues = nil;
    });
};
