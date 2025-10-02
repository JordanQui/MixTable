// ================= Gestion MIDI pour le synthé interne =================

~configureMidiInput = {
    var sources = MIDIClient.sources;
    var sourceIndex = sources.detectIndex { |src|
        (src.device == "TransBus") and: { src.name == "SC1" }
    };

	if(sources.isNil) {
        sources = Array.new;
    };

	MIDIClient.init;
    MIDIIn.disconnectAll;

    if(sourceIndex.isNil) {
        "Source MIDI 'TransBus - SC1' introuvable.".warn;
    } {
        MIDIIn.connect(sourceIndex, sources[sourceIndex]);
    };

    MIDIIn.noteOn = { |src, chan, num, vel|
        if(~midiSynth.notNil) {
            ~midiSynth.set(\freq, num.midicps);
            ~midiSynth.set(\gate, vel / 127);
        };
    };

    MIDIIn.noteOff = { |src, chan, num, vel|
        if(~midiSynth.notNil) {
            ~midiSynth.set(\gate, 0.0);
        };
    };

    MIDIIn.bend = { |src, chan, val|
        if(~midiSynth.notNil) {
            var normalized = (val - 8192) / 8192.0;
            var semitones = normalized * 2.0;
            ~midiSynth.set(\bend, semitones.midiratio);
        };
    };

    MIDIIn.control = { |src, chan, num, vel|
        if(~midiSynth.notNil) {
            switch(num,
                74, {
                    var cutoff = vel.linexp(0, 127, 200, 8000);
                    ~midiSynth.set(\cutoff, cutoff);
                },
                1, {
                    ~midiSynth.set(\vibrato, vel / 127);
                }
            );
        };
    };
};
