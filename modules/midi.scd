if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~makeMidiResponderKey = { |src, channel, note|
    "%:%:%".format(src, channel, note).asSymbol;
};

~setupMidi = {
    var matchDevice, makeKey;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    ~midiResponderSynths = ~midiResponderSynths ?? {
        IdentityDictionary.newFrom([
            \default, ~defaultMidiSynth
        ])
    };

    ~activeMidiSynths.tryPerform(\valuesDo, { |entry|
        var synth = entry.tryPerform(\at, \synth) ?? { entry };
        synth.tryPerform(\set, \gate, 0);
    });
    ~activeMidiSynths = Dictionary.new;
    ~midiCCValues = IdentityDictionary.new;

    MIDIIn.disconnectAll;
    MIDIIn.connectAll;

    makeKey = ~makeMidiResponderKey;

    matchDevice = { |src|
        var source;

        source = MIDIClient.sources.detect { |endpoint|
            endpoint.uid == src
        };

        source.notNil and: {
            source.device == "TransBus" and: { source.name == "SC1" }
        }
    };

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
                var freq, amp, outBus, existingEntry, existingSynth, synth, synthKey, config;
                var ccValue, args, channelCCValue, ccParam, ccDefault, ccMap, extraArgs;
                freq = note.midicps;
                amp = velocity.linlin(1, 127, 0.02, 0.5);
                outBus = ~directBus ?? { 0 };
                existingEntry = ~activeMidiSynths.removeAt(key);
                existingSynth = existingEntry.tryPerform(\at, \synth) ?? { existingEntry };
                ("[MIDI] stopping existing synth for key:% -> %"
                    .format(key, existingSynth)).postln;
                existingSynth.tryPerform(\set, \gate, 0);
                synthKey = {
                    var mappingKey = key;
                    var channelKey = ("channel:%".format(channel)).asSymbol;
                    ~midiResponderSynths[mappingKey]
                        ?? { ~midiResponderSynths[channelKey] }
                        ?? { ~midiResponderSynths[\default] ?? { ~defaultMidiSynth } };
                }.value;
                if(synthKey.respondsTo(\asSymbol)) {
                    synthKey = synthKey.asSymbol;
                } {
                    synthKey = ~defaultMidiSynth;
                };
                config = ~midiSynthConfigs[synthKey] ?? { IdentityDictionary.new };
                ccParam = config[\ccParam];
                ccMap = config[\ccMap] ?? { |val| val };
                ccDefault = config[\ccDefault] ?? { 64 };
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
                var config, ccParam, ccMap;
                if((synth.notNil) and: { entryChannel == channel }) {
                    config = ~midiSynthConfigs[type] ?? { IdentityDictionary.new };
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
