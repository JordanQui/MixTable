// ======================
// Options serveur
// ======================
s.options.memSize = 2.pow(21);
s.options.numBuffers = 2048;
s.options.numWireBufs = 64;
s.options.hardwareBufferSize = 64;
s.options.blockSize = 64;
s.latency = 0.01;
s.options.outDevice = "SoundCard";
s.options.inDevice = "SoundCard";
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 18;

// ======================
// Gestion des chemins
// ======================
~projectRoot = thisProcess.nowExecutingPath.dirname;
~ezConvIRRelativePath = "IRs/IR1.wav";
~ezConvIRPath = (~projectRoot +/+ ~ezConvIRRelativePath).standardizePath;

// ======================
// Initialisation
// ======================
~bootMixTable = {
    ("modules/mixer.scd").loadRelative;
    ("modules/ui.scd").loadRelative;

    ~setupAudio.value;
    ~createUI.value;
};

// ======================
// Boot serveur
//  ======================
s.waitForBoot({ ~bootMixTable.value });

s.makeWindow;
