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
    ("config/transbus_sc1.scd").loadRelative;
    ("modules/synth.scd").loadRelative;
    ("modules/voicer.scd").loadRelative;
    ("modules/mixer.scd").loadRelative;
    ("modules/ui.scd").loadRelative;

    ~setupAudio.value;
    ~createUI.value;
};

// ======================
// Boot serveur
// ======================
s.waitForBoot({ ~bootMixTable.value });

s.makeWindow;
