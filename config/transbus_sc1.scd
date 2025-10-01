~transBusConfig = (
    device: "TransBus",
    port: "SC1"
);

~rootNote = ~rootNote ? 0;
~scale = ~scale ? Scale.chromatic;
~tempo = ~tempo ? 1;

~braidsVoicer = nil;

~teardownBraidsVoicer = {
    ~braidsVoicer !? { |current|
        current.midiDefs !? { |defs|
            defs.values.do { |def| def.tryPerform(\free); };
        };
        current.roli.tryPerform(\releaseAll);
        current.roli.tryPerform(\stop);
        current.proxy.tryPerform(\stop);
        current.proxy.tryPerform(\clear);
        current.proxy.tryPerform(\free);
        current.bus.tryPerform(\free);
    };
    ~braidsVoicer = nil;
};

~findMidiSource = { |device, port|
    MIDIClient.sources.detect { |src|
        (src.device == device) and: { src.name == port }
    };
};

~setupBraidsVoicer = { |voiceGroup, mixInputs, channelIndex = 0, defaultConfig|
    var midiSource, midiUID, outputBus, proxy, roli, voicer, updatedConfig, channelSynth;

    ~teardownBraidsVoicer.value;

    MIDIClient.init;
    MIDIIn.connectAll;

    midiSource = ~findMidiSource.value(~transBusConfig[\device], ~transBusConfig[\port]);
    if(midiSource.isNil) {
        ("Source MIDI % % introuvable").format(~transBusConfig[\device], ~transBusConfig[\port]).warn;
    };
    midiUID = midiSource.tryPerform(\uid);

    outputBus = Bus.audio(s, 2);
    proxy = NodeProxy.audio(s, 2);
    proxy.play(outputBus.index, 2, voiceGroup);
    roli = NPVoicerL(proxy, [\freq, \amp, \mod, \bend, \out]);

    voicer = (
        proxy: proxy,
        roli: roli,
        bus: outputBus,
        indivParams: [\freq, \amp, \mod, \bend, \out],
        midiSource: midiSource,
        uid: midiUID
    );

    ~makeVoice.value(midiUID, voicer, 0, outputBus.index);

    updatedConfig = (defaultConfig ? ()).copy;
    updatedConfig.putAll((
        label: "Synth 1",
        channels: [outputBus.index, outputBus.index + 1],
        isMono: 0,
        useSoundIn: 0
    ));

    mixInputs[channelIndex] = updatedConfig;

    if(~channelSynths.isArray and: { channelIndex >= 0 } and: { channelIndex < ~channelSynths.size }) {
        channelSynth = ~channelSynths[channelIndex];
        channelSynth.tryPerform(\set,
            \inA, updatedConfig[\channels][0],
            \inB, updatedConfig[\channels][1],
            \isMono, updatedConfig[\isMono] ?? { 0 },
            \useSoundIn, updatedConfig[\useSoundIn] ?? { 1 }
        );
    };

    ~braidsVoicer = voicer;
};
