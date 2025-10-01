if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setupMidi = {
    var matchDevice, makeKey, spawnMidiSynth;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    ~activeMidiSynths.tryPerform(\valuesDo, { |synth|
        synth.tryPerform(\set, \gate, 0);
    });
    ~activeMidiSynths = Dictionary.new;

    MIDIIn.disconnectAll;
    MIDIIn.connectAll;

    makeKey = { |src, channel, note|
        "%:%:%".format(src, channel, note);
    };

    spawnMidiSynth = { |freq, amp, outBus, velocity = 0|
        var synthKey, registry, entry, argBuilder, args;

        registry = ~midiSynthRegistry ?? { Dictionary.new };
        synthKey = ~currentMidiSynth.tryPerform(\value) ?? {
            (~currentMidiSynth ? \percussiveSine)
        };
        entry = registry[synthKey];
        argBuilder = entry.tryPerform(\at, \makeArgs);
        args = argBuilder.tryPerform(\value, freq, amp, outBus, velocity) ?? {
            [\freq, freq, \amp, amp, \out, outBus]
        };
        Synth(synthKey, args);
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

    ~midiResponders.add(MIDIFunc.noteOn({ |velocity, note, channel, src|
        var deviceMatches = matchDevice.(src);
        ("[MIDI] noteOn src:% channel:% note:% velocity:% match:%"
            .format(src, channel, note, velocity, deviceMatches)).postln;
        if(deviceMatches) {
            var key = makeKey.(src, channel, note);
            if(velocity <= 0) {
                var synth = ~activeMidiSynths.removeAt(key);
                ("[MIDI] noteOn treated as noteOff key:% synth:%"
                    .format(key, synth)).postln;
                synth.tryPerform(\set, \gate, 0);
            } {
                var freq, amp, outBus, existingSynth, synth;
                freq = note.midicps;
                amp = velocity.linlin(1, 127, 0.02, 0.5);
                outBus = ~directBus ?? { 0 };
                existingSynth = ~activeMidiSynths.removeAt(key);
                ("[MIDI] stopping existing synth for key:% -> %"
                    .format(key, existingSynth)).postln;
                existingSynth.tryPerform(\set, \gate, 0);
                synth = spawnMidiSynth.(freq, amp, outBus, velocity);
                ("[MIDI] started synth % for key:% freq:% amp:% out:%"
                    .format(synth, key, freq, amp, outBus)).postln;
                ~activeMidiSynths[key] = synth;
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
            var synth = ~activeMidiSynths.removeAt(key);
            ("[MIDI] noteOff releasing synth for key:% -> %"
                .format(key, synth)).postln;
            synth.tryPerform(\set, \gate, 0);
        } {
            ("[MIDI] noteOff ignored - device mismatch for src:%"
                .format(src)).postln;
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
        ~activeMidiSynths.tryPerform(\valuesDo, { |synth|
            synth.tryPerform(\set, \gate, 0);
        });
        ~activeMidiSynths = nil;
    });
};
