// ======================
// Options serveur
// ======================
s.options.memSize = 2.pow(21);
s.options.numBuffers = 2048;
s.options.numWireBufs = 64;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 8;
s.options.maxNodes = 1024;



// ======================
// Routine principale
// ======================
~mixTick = Routine {

};

// ======================
// Boot serveur
// ======================
s.waitForBoot({ ~mixTick.play(AppClock) });
