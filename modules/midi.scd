if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setupMidi = {
    var matchDevice, makeKey;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    ~activeMidiSynths.tryPerform(\valuesDo, { |synth|
        synth.tryPerform(\set, \gate, 0);
    });
    ~activeMidiSynths = IdentityDictionary.new;

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

    ~midiResponders.add(MIDIFunc.noteOn({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            var key = makeKey.(src, channel, note);
            if(velocity <= 0) {
                var synth = ~activeMidiSynths.removeAt(key);
                synth.tryPerform(\set, \gate, 0);
            } {
                var freq = note.midicps;
                var amp = velocity.linlin(1, 127, 0.02, 0.5);
                var outBus = ~directBus ?? { 0 };
                var synth = Synth(\percussiveSine, [
                    \freq, freq,
                    \amp, amp,
                    \out, outBus
                ]);
                ~activeMidiSynths[key] = synth;
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.noteOff({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            var key = makeKey.(src, channel, note);
            var synth = ~activeMidiSynths.removeAt(key);
            synth.tryPerform(\set, \gate, 0);
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
