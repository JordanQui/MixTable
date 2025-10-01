if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~midiNoteKey = { |channel, note| "%:%".format(channel, note) };

~midiGetAftertouchState = { |channel|
    var state;

    if(~midiAftertouchLevels.isNil) {
        ~midiAftertouchLevels = IdentityDictionary.new;
    };

    state = ~midiAftertouchLevels[channel];

    if(state.isNil) {
        state = IdentityDictionary.new;
        state[\channel] = 1;
        ~midiAftertouchLevels[channel] = state;
    };

    ^state;
};

~midiGetAftertouchLevel = { |channel, note|
    var state = ~midiGetAftertouchState.(channel);
    ^state[note] ?? { state[\channel] ?? { 1 } };
};

~midiSetChannelAftertouch = { |channel, level|
    ~midiGetAftertouchState.(channel)[\channel] = level;
};

~midiSetNoteAftertouch = { |channel, note, level|
    ~midiGetAftertouchState.(channel)[note] = level;
};

~midiClearNoteAftertouch = { |channel, note|
    var state;

    if(~midiAftertouchLevels.isNil) { ^nil };

    state = ~midiAftertouchLevels[channel];
    state.tryPerform(\removeAt, note);
};

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

    ~midiClearNoteAftertouch.(channel, note);
};

~setupMidi = {
    var matchDevice;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    if(~midiActiveSynths.notNil) {
        ~midiActiveSynths.do { |key, synth|
            synth.tryPerform(\set, \gate, 0);
            synth.tryPerform(\release);
            synth.tryPerform(\free);
        };
    };

    ~midiActiveSynths = Dictionary.new;
    ~midiAftertouchLevels = IdentityDictionary.new;

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
                    \out, outBus,
                    \aftertouchAmp, ~midiGetAftertouchLevel.(channel, note)
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

    ~midiResponders.add(MIDIFunc.afterTouch({ |value, channel, src|
        if(matchDevice.(src)) {
            var level = value.linlin(0, 127, 0, 1);
            var prefix = channel.asString ++ ":";

            ~midiSetChannelAftertouch.(channel, level);

            ~midiActiveSynths.keysValuesDo { |key, synth|
                if(key.beginsWith(prefix)) {
                    var parts = key.split($:);
                    var note = parts.at(1).tryPerform(\asInteger);
                    var noteLevel = ~midiGetAftertouchLevel.(channel, note);
                    synth.tryPerform(\set, \aftertouchAmp, noteLevel);
                };
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.polyTouch({ |value, note, channel, src|
        if(matchDevice.(src)) {
            var level = value.linlin(0, 127, 0, 1);
            var key = ~midiNoteKey.(channel, note);
            var synth = ~midiActiveSynths[key];

            ~midiSetNoteAftertouch.(channel, note, level);
            synth.tryPerform(\set, \aftertouchAmp, level);
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
        ~midiActiveSynths.tryPerform(\do, { |key, synth|
            synth.tryPerform(\set, \gate, 0);
            synth.tryPerform(\release);
            synth.tryPerform(\free);
        });
        ~midiActiveSynths = nil;
        ~midiAftertouchLevels = nil;
    });
};
