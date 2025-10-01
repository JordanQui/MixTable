if(MIDIClient.initialized.not) {
    MIDIClient.init;
};

~setupMidi = {
    var matchDevice;

    ~midiResponders.tryPerform(\do, _.tryPerform(\free));
    ~midiResponders = List.new;

    MIDIIn.disconnectAll;
    MIDIIn.connectAll;

    matchDevice = { |src|
        src.notNil and: {
            src.device == "TransBus" and: { src.name == "SC1" }
        }
    };

    ~midiResponders.add(MIDIFunc.noteOn({ |velocity, note, channel, src|
        if(matchDevice.(src)) {
            var freq = note.midicps;
            var amp = velocity.linlin(1, 127, 0.02, 0.5);
            var outBus = ~directBus ?? { 0 };
            Synth(\percussiveSine, [
                \freq, freq,
                \amp, amp,
                \out, outBus
            ]);
        };
    }));

    CmdPeriod.doOnce({
        ~midiResponders.tryPerform(\do, _.tryPerform(\free));
        ~midiResponders = nil;
    });
};
