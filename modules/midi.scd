if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setupMidi = {
    var matchDevice;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;
    ~roliSineVoices.tryPerform(\do, { |synth|
        synth.tryPerform(\free);
    });
    ~roliSineVoices = IdentityDictionary.new;

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
            var freq = note.midicps;
            var amp = velocity.linlin(1, 127, 0.02, 0.5);
            var outBus = ~directBus ?? { 0 };
            var synth;
            synth = Synth(\percussiveSine, [
                \freq, freq,
                \amp, amp,
                \out, outBus
            ]);
            ~roliSineVoices[note] = synth;
            synth.onFree({
                {
                    ~roliSineVoices.removeAt(note);
                }.defer;
            });
        };
    }));

    ~midiResponders.add(MIDIFunc.polytouch({ |pressure, note, channel, src|
        if(matchDevice.(src)) {
            var synth = ~roliSineVoices[note];
            var mod = pressure.linlin(0, 127, 0, 1).clip(0, 1);
            if(synth.notNil) {
                synth.tryPerform(\set, \modAmp, mod);
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.touch({ |pressure, channel, src|
        if(matchDevice.(src)) {
            var mod = pressure.linlin(0, 127, 0, 1).clip(0, 1);
            ~roliSineVoices.do { |voice|
                voice.tryPerform(\set, \modAmp, mod);
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.noteOff({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            var synth = ~roliSineVoices.removeAt(note);
            if(synth.notNil) {
                synth.tryPerform(\set, \modAmp, 0);
            };
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
    });
};
