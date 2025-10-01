~makeRoliVoice =
    {|uid, voicer, bank, out|
    var midiDefs = IdentityDictionary.new;

    voicer.indivParams;

    voicer.roli.prime(\roli_kaivoY001);

    voicer.makeNote = { |q, chan, note = 60, vel = 64|
        var velocity = vel.max(1) / 127; // avoid a zero velocity on note-on
        voicer.roli.put(chan, [
            \freq, (note + ~rootNote).keyToDegree(~scale,12).degreeToKey(~scale).midicps,
            \amp, velocity,
            \mod, 0,
            \bend, 0,
            \pan, 0,
            \gate, 1,
            \out, out
        ]);
    };
    voicer.endNote = { |q, chan|
        var obj = voicer.roli.proxy.objects[chan];
        if (obj.notNil) { obj.set(\gate, 0) };
    };

    voicer.setTouch = { |q, chan=0, touchval = 64|
        var obj = voicer.roli.proxy.objects[chan];
        if (obj.notNil) { obj.set(\amp, (touchval/127)) };
    };
    voicer.setSlide = { |q, chan=0, slide = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if (obj.notNil) { obj.set(\mod, (slide/127)) };
    };
    voicer.setBend = { |q, chan=0, bendval = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if (obj.notNil) {
            obj.set(\bend, bendval.linlin(0, 16383, -36, 36))
        };
    };

    midiDefs[\noteOn] = MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
        voicer.makeNote(chan, noteNum, vel);
    },srcID:uid).enable;

    midiDefs[\noteOff] = MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
        voicer.endNote(chan, noteNum);
    },srcID:uid).enable;

    midiDefs[\slide] = MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
        voicer.setSlide(chan, val);
    },1,srcID:uid).enable;

    midiDefs[\touch] = MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
        voicer.setTouch(chan, val);
    },srcID:uid).enable;
    midiDefs[\bend] = MIDIdef.bend(\roliBend ++ out, { |bend, chan|
        voicer.setBend(chan, bend);
    },srcID:uid).enable;

    voicer.midiDefs = midiDefs;
    voicer.uid = uid;
    voicer.out = out;
};
