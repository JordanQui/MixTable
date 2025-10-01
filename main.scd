// ======================
// Options serveur
// ======================
s.options.memSize = 2.pow(21);
s.options.numBuffers = 2048;
s.options.numWireBufs = 64;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 8;

// ======================
// Initialisation
// ======================
~scale = Scale.chromatic;
~scale.tuning_(\et12);
~rootNote = 0;


~bootMixTable = {
    ("config/transbus_sc1.scd").loadRelative;
    ("modules/synth.scd").loadRelative;
    ("modules/voicer.scd").loadRelative;
    ("modules/mixer.scd").loadRelative;
    ("modules/ui.scd").loadRelative;
	("modules/synth.scd").loadRelative;

    ~setupAudio.value;
    ~createUI.value;

	~initMidi = {
		MIDIClient.init;
		MIDIClient.sources.do({|item, i|
			// roli
			if(item.device == "TransBus" && item.name == "SC1" , {
				~uidRoli1 = item.uid;
				('uid roli 1 :::::::: ' ++ ~uidRoli1).postln;
			});
		});
		MIDIIn.connectAll;
	};
	~initMidi.value;
	s.sync;
	~voicer = ~voicer ? ();
	~voicer.synth = NPVoicer( Ndef(\roli));
	s.sync;
	~makeVoice.value(~uidRoli1, ~voicer, 0,0);
	s.sync;
	~voicer.synth.prime(\synth1);
};

// ======================
// Boot serveur
// ======================
s.waitForBoot({ ~bootMixTable.play(AppClock) });

s.makeWindow;