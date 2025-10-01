~makeVoice  =
        {|uid, voicer, bank, out|
        var midiDefs = IdentityDictionary.new;

        voicer.indivParams;

        voicer.roli.prime(\synth1);

        voicer.makeNote = { |q, chan, note = 60, vel = 64|
                var velocity = vel.max(1) / 127; // avoid a zero velocity on note-on
                voicer.roli.put(chan, [
                        \freq, (note + ~rootNote).keyToDegree(~scale,12).degreeToKey(~scale).midicps,
                        \amp, velocity,
                        \gate, 1,
                        \mod, 0,
                        \bend, 0,
                        \pan, 0,
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
                // "slide: % % %\n".postf(chan, slide);
                if (obj.notNil) { obj.set(\mod, (slide/127)) };
        };
        voicer.setBend = { |q, chan=0, bendval = 0|
                var obj = voicer.roli.proxy.objects[chan];
                if (obj.notNil) { obj.set(\bend,
                        bendval.linlin(0, 16383, -36, 36)) };
        };

        midiDefs[\noteOn] = MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
                // "noteOn: % % %\n".postf(noteNum, vel, chan);
                voicer.makeNote(chan, noteNum, vel);
        },srcID:uid).enable;

        midiDefs[\noteOff] = MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
                // "noteOff: % % %\n".postf(noteNum, vel, chan);
                voicer.endNote(chan, noteNum);
        },srcID:uid).enable;

        midiDefs[\slide] = MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
                // ("slide " + ccnum  + val + chan).postln;
                voicer.setSlide(chan, val);
        },1,srcID:uid).enable;

        midiDefs[\touch] = MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
                voicer.setTouch(chan, val);
        },srcID:uid).enable;
        midiDefs[\bend] = MIDIdef.bend(\roliBend ++ out, { |bend, chan|
                // "bend: % %\n".postf(bend, chan);
                voicer.setBend(chan, bend);
        },srcID:uid).enable;
        // MIDIdef.program(\roliProgram ++ out, { |prog, chan|
        //      "program: % %\n".postf(prog, chan);
        //      voicer.roli.prime(~presets[bank][prog])
        // },srcID:uid).enable;
        voicer.midiDefs = midiDefs;
        voicer.uid = uid;
        voicer.out = out;
        };
