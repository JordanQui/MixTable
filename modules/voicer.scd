~makeVoice =
	{|uid, voicer, bank, out|

        var roliVoicer;

        roliVoicer = voicer[\roli];
        if(roliVoicer.isNil) {
                Error("Aucun voicer ROLI initialisé").throw;
        };

        roliVoicer.indivParams;

        roliVoicer.prime(\roli_kaivoY001);

        voicer.makeNote = { |q, chan, note = 60, vel = 64|
                roliVoicer.put(chan, [
                        \freq, (note + ~rootNote).keyToDegree(~scale,12).degreeToKey(~scale).midicps,
                        \vel, (vel/127),
                        \out, out
                        ]);
        };
        voicer.endNote = { |q, chan|
                var obj = roliVoicer.proxy.objects[chan];
                if (obj.notNil) { obj.set(\gate, 0) };
        };

        voicer.setTouch = { |q, chan=0, touchval = 64|
                var obj = roliVoicer.proxy.objects[chan];
                if (obj.notNil) { obj.set(\amp, (touchval/127)) };
        };
        voicer.setSlide = { |q, chan=0, slide = 0|
                var obj = roliVoicer.proxy.objects[chan];
                // "slide: % % %\n".postf(chan, slide);
                if (obj.notNil) { obj.set(\mod, (slide/127)) };
        };
        voicer.setBend = { |q, chan=0, bendval = 0|
                var obj = roliVoicer.proxy.objects[chan];
                if (obj.notNil) { obj.set(\bend,
                        bendval.linlin(0, 16383, -36, 36)) };
        };

	MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
		"noteOn: % % %\n".postf(noteNum, vel, chan);
		voicer.makeNote(chan, noteNum, vel);
	},srcID:uid).enable;

	MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
		// "noteOff: % % %\n".postf(noteNum, vel, chan);
		voicer.endNote(chan, noteNum);
	},srcID:uid).enable;

	MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
		// ("slide " + ccnum  + val + chan).postln;
		voicer.setSlide(chan, val);
	},1,srcID:uid).enable;

	MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
		//("touch " + val + chan).postln;
		voicer.setTouch(chan, val);
	},srcID:uid).enable;
	MIDIdef.bend(\roliBend ++ out, { |bend, chan|
		// "bend: % %\n".postf(bend, chan);
		voicer.setBend(chan, bend);
	},srcID:uid).enable;
	// MIDIdef.program(\roliProgram ++ out, { |prog, chan|
	// 	"program: % %\n".postf(prog, chan);
	// 	voicer.roli.prime(~presets[bank][prog])
	// },srcID:uid).enable;
	};


