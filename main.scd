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
~bootMixTable = {
    ("modules/mixer.scd").loadRelative;
    ("modules/synths.scd").loadRelative;
    ("modules/midi.scd").loadRelative;
    ("modules/ui.scd").loadRelative;

    ~setupAudio.value;
    if(~setupMidi.notNil) { ~setupMidi.value };
    ~createUI.value;
};

// ======================
// Boot serveur
// ======================
s.waitForBoot({ ~bootMixTable.value });

s.makeWindow;
