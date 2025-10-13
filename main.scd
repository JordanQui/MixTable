// ======================
// Options serveur
// ======================
s.options.memSize = 2.pow(21);
s.options.numBuffers = 2048;
s.options.numWireBufs = 64;
s.options.outDevice = "SoundCard";
s.options.inDevice = "SoundCard";
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 18;

// Réduit la latence de planification côté client pour les événements synchronisés
// avec Ableton Link. La valeur par défaut (~0.2s) retarde fortement les clics
// générés dans SuperCollider par rapport à ceux d'Ableton Live.
s.latency = 0.02;

// ======================
// Initialisation
// ======================
~bootMixTable = {
    ("modules/mixer.scd").loadRelative;
    ("modules/ui.scd").loadRelative;
    ("modules/linkclock.scd").loadRelative;

    ~setupAudio.value;
    ~createUI.value;
    ~setupLinkClock.value;
};

// ======================
// Boot serveur
// ======================
s.waitForBoot({ ~bootMixTable.value });

s.makeWindow;
