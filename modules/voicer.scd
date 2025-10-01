~makeRoliVoice =
    {|uid, voicer, bank, out|
    var midiDefs = IdentityDictionary.new;
    var voices = IdentityDictionary.new;

    voicer.voices = voices;

    voicer[\makeNote] = { |q, chan, note = 60, vel = 64|
        var velocity = vel.max(1) / 127; // avoid a zero velocity on note-on
        var freq = (note + ~rootNote).keyToDegree(~scale, 12).degreeToKey(~scale).midicps;
        var existing = voices[chan];

        existing.tryPerform(\release, 0.1);

        voices[chan] = Synth(\roli_kaivoY001, [
            \freq, freq,
            \amp, velocity,
            \mod, 0,
            \bend, 0,
            \pan, 0,
            \gate, 1,
            \out, out
        ], target: voicer.group ?? { s.defaultGroup });
    };
    voicer[\endNote] = { |q, chan|
        var synth = voices.removeAt(chan);
        synth.tryPerform(\release, 0.1);
    };

    voicer[\setTouch] = { |q, chan = 0, touchval = 64|
        var synth = voices[chan];
        synth.tryPerform(\set, \amp, (touchval / 127));
    };
    voicer[\setSlide] = { |q, chan = 0, slide = 0|
        var synth = voices[chan];
        synth.tryPerform(\set, \mod, (slide / 127));
    };
    voicer[\setBend] = { |q, chan = 0, bendval = 0|
        var synth = voices[chan];
        synth.tryPerform(\set, \bend, bendval.linlin(0, 16383, -36, 36));
    };

    midiDefs[\noteOn] = MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
        voicer[\makeNote].tryPerform(\value, voicer, chan, noteNum, vel);
    }, srcID: uid).enable;

    midiDefs[\noteOff] = MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
        voicer[\endNote].tryPerform(\value, voicer, chan, noteNum);
    }, srcID: uid).enable;

    midiDefs[\slide] = MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
        voicer[\setSlide].tryPerform(\value, voicer, chan, val);
    }, 1, srcID: uid).enable;

    midiDefs[\touch] = MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
        voicer[\setTouch].tryPerform(\value, voicer, chan, val);
    }, srcID: uid).enable;
    midiDefs[\bend] = MIDIdef.bend(\roliBend ++ out, { |bend, chan|
        voicer[\setBend].tryPerform(\value, voicer, chan, bend);
    }, srcID: uid).enable;

    voicer.midiDefs = midiDefs;
    voicer.uid = uid;
    voicer.out = out;
};
