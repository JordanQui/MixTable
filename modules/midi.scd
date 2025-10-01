if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setupMidi = {
    var matchDevice, ensureChannelState;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;
    ~roliSineVoices.tryPerform(\do, { |voice|
        if(voice.isKindOf(Synth)) {
            voice.tryPerform(\free);
        } {
            voice[\synth].tryPerform(\free);
        };
    });
    ~roliSineVoices = IdentityDictionary.new;
    ~mpeChannelState = IdentityDictionary.new;
    ~mpePitchBendRange = ~mpePitchBendRange ?? { 48 };

    ensureChannelState = { |channel|
        ~mpeChannelState[channel] ?? {
            ~mpeChannelState[channel] = (pressure: 1, bend: 0);
        };
    };

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
            var freq, amp, outBus, channelKey, state, existing, pressure, bend, synth;

            freq = note.midicps;
            amp = velocity.linlin(1, 127, 0.02, 0.5);
            outBus = ~directBus ?? { 0 };
            channelKey = channel;
            state = ensureChannelState.(channelKey);
            existing = ~roliSineVoices[channelKey];
            pressure = (state[\pressure] ?? { 1 }).clip(0, 1);
            if(pressure <= 0.001) {
                pressure = 1;
            };
            bend = state[\bend] ?? { 0 };

            if(existing.notNil) {
                if(existing.isKindOf(Synth)) {
                    existing.tryPerform(\set, \modAmp, 0, \gate, 0);
                } {
                    existing[\synth].tryPerform(\set, \modAmp, 0, \gate, 0);
                };
            };

            state[\pressure] = pressure;

            synth = Synth(\percussiveSine, [
                \freq, freq,
                \amp, amp,
                \gate, 1,
                \out, outBus,
                \modAmp, pressure,
                \bend, bend
            ]);

            ~roliSineVoices[channelKey] = (note: note, synth: synth);

            synth.onFree({
                {
                    var current = ~roliSineVoices[channelKey];
                    if(current.notNil) {
                        if(current.isKindOf(Synth)) {
                            if(current === synth) {
                                ~roliSineVoices.removeAt(channelKey);
                            };
                        } {
                            if(current[\synth] === synth) {
                                ~roliSineVoices.removeAt(channelKey);
                            };
                        };
                    };
                }.defer;
            });
        };
    }));

    ~midiResponders.add(MIDIFunc.polytouch({ |pressure, note, channel, src|
        if(matchDevice.(src)) {
            var channelKey = channel;
            var state = ensureChannelState.(channelKey);
            var mod = pressure.linlin(0, 127, 0, 1).clip(0, 1);
            var voice = ~roliSineVoices[channelKey];
            state[\pressure] = mod;
            if(voice.notNil and: { voice[\note] == note }) {
                voice[\synth].tryPerform(\set, \modAmp, mod);
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.touch({ |pressure, channel, src|
        if(matchDevice.(src)) {
            var channelKey = channel;
            var state = ensureChannelState.(channelKey);
            var mod = pressure.linlin(0, 127, 0, 1).clip(0, 1);
            var voice = ~roliSineVoices[channelKey];
            state[\pressure] = mod;
            if(voice.notNil) {
                voice[\synth].tryPerform(\set, \modAmp, mod);
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.bend({ |value, channel, src|
        if(matchDevice.(src)) {
            var channelKey = channel;
            var state = ensureChannelState.(channelKey);
            var bend = value.linlin(0, 16383, (~mpePitchBendRange * -1), ~mpePitchBendRange);
            var voice = ~roliSineVoices[channelKey];
            state[\bend] = bend;
            if(voice.notNil) {
                voice[\synth].tryPerform(\set, \bend, bend);
            };
        };
    }));

    ~midiResponders.add(MIDIFunc.noteOff({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            var channelKey = channel;
            var voice = ~roliSineVoices[channelKey];
            if(voice.notNil) {
                var synth = voice.isKindOf(Synth).if({ voice }, { voice[\synth] });
                if(voice.isKindOf(Synth) or: { voice[\note] == note }) {
                    synth.tryPerform(\set, \modAmp, 0, \gate, 0);
                };
            };
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
        ~mpeChannelState = nil;
        ~roliSineVoices = nil;
    });
};
