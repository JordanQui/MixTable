if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~midiNoteKey = { |channel, note| "%:%".format(channel, note) };

~midiEnsureAftertouchStores = {
    if(~midiChannelAftertouch.isNil) { ~midiChannelAftertouch = Dictionary.new };
    if(~midiNoteAftertouch.isNil) { ~midiNoteAftertouch = Dictionary.new };
};

~midiGetChannelAftertouch = { |channel|
    ~midiEnsureAftertouchStores.value;
    ^(~midiChannelAftertouch[channel] ?? { 1 }).clip(0, 1);
};

~midiSetChannelAftertouch = { |channel, level|
    ~midiEnsureAftertouchStores.value;
    ~midiChannelAftertouch[channel] = level.clip(0, 1);
};

~midiSetNoteAftertouch = { |channel, note, level|
    var key = ~midiNoteKey.(channel, note);
    ~midiEnsureAftertouchStores.value;
    ~midiNoteAftertouch[key] = level.clip(0, 1);
};

~midiClearNoteAftertouch = { |channel, note|
    var key = ~midiNoteKey.(channel, note);
    if(~midiNoteAftertouch.notNil) {
        ~midiNoteAftertouch.removeAt(key);
    };
};

~midiApplyAftertouchToSynth = { |key, synth|
    var parts = key.split($:);
    var channel = parts.at(0).tryPerform(\asInteger) ?? { 0 };
    var level;

    if(~midiNoteAftertouch.notNil) {
        level = ~midiNoteAftertouch[key];
    };

    if(level.isNil) {
        level = ~midiGetChannelAftertouch.(channel);
    };

    synth.tryPerform(\set, \aftertouchAmp, level);
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
    ~midiChannelAftertouch = Dictionary.new;
    ~midiNoteAftertouch = Dictionary.new;

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
                    \aftertouchAmp, ~midiGetChannelAftertouch.(channel)
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

    ~midiResponders.add(MIDIFunc.touch({ |value, channel, src|
        if(matchDevice.(src)) {
            var level = value.linlin(0, 127, 0, 1);
            var prefix = channel.asString ++ ":";

            ~midiSetChannelAftertouch.(channel, level);

            ~midiActiveSynths.keysValuesDo { |key, synth|
                if(key.beginsWith(prefix)) {
                    ~midiApplyAftertouchToSynth.(key, synth);
                };
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.polytouch({ |value, note, channel, src|
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
        ~midiChannelAftertouch = nil;
        ~midiNoteAftertouch = nil;
    });
};
