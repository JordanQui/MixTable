if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~midiNoteKey = { |channel, note| "%:%".format(channel, note) };

~releaseMidiNote = { |channel, note|
    var dict = ~midiActiveSynths;
    var key, synth;

    if(dict.isNil) { ^nil };

    key = ~midiNoteKey.(channel, note);
    synth = dict.removeAt(key);

    if(synth.notNil) {
        synth.tryPerform(\set, \gate, 0);
        synth.tryPerform(\release);
    };
};

~setupMidi = {
    var matchDevice;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    if(~midiActiveSynths.notNil) {
        ~midiActiveSynths.valuesDo { |synth|
            synth.tryPerform(\set, \gate, 0);
            synth.tryPerform(\release);
            synth.tryPerform(\free);
        };
    };

    ~midiActiveSynths = Dictionary.new;

    MIDIIn.disconnectAll;
    MIDIIn.connectAll;

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
            if(velocity <= 0) {
                ~releaseMidiNote.(channel, note);
            } {
                var freq = note.midicps;
                var amp = velocity.linlin(1, 127, 0.02, 0.5);
                var outBus = ~directBus ?? { 0 };
                var key = ~midiNoteKey.(channel, note);
                var synth;

                ~releaseMidiNote.(channel, note);

                synth = Synth(\percussiveSine, [
                    \freq, freq,
                    \amp, amp,
                    \out, outBus
                ]);

                ~midiActiveSynths[key] = synth;
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.noteOff({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            ~releaseMidiNote.(channel, note);
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
        ~midiActiveSynths.tryPerform(\valuesDo, { |synth|
            synth.tryPerform(\set, \gate, 0);
            synth.tryPerform(\release);
            synth.tryPerform(\free);
        });
        ~midiActiveSynths = nil;
    });
};
