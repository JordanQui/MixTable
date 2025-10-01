~transBusConfig = (
    device: "TransBus",
    port: "SC1"
);

~rootNote = ~rootNote ? 0;
~scale = ~scale ? Scale.chromatic;

~braidsVoicer = nil;

~teardownBraidsVoicer = {
    ~braidsVoicer !? { |current|
        current.midiDefs !? { |defs|
            defs.values.do { |def| def.tryPerform(\free); };
        };
        current.voices !? { |voiceDict|
            voiceDict.values.do(_.tryPerform(\release, 0.1));
            voiceDict.clear;
        };
        current.proxy !? { |proxy|
            proxy.tryPerform(\stop);
            proxy.tryPerform(\clear);
            proxy.tryPerform(\free);
        };
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
    var midiSource, midiUID, outputBus, voicer, updatedConfig, channelSynth;

    ~teardownBraidsVoicer.value;

    MIDIClient.init;
    MIDIIn.connectAll;

    midiSource = ~findMidiSource.value(~transBusConfig[\device], ~transBusConfig[\port]);
    if(midiSource.isNil) {
        ("Source MIDI % % introuvable").format(~transBusConfig[\device], ~transBusConfig[\port]).warn;
    };
    midiUID = midiSource.tryPerform(\uid);

    outputBus = Bus.audio(s, 2);

    voicer = (
        group: voiceGroup,
        bus: outputBus,
        midiSource: midiSource,
        uid: midiUID
    );

    ~makeRoliVoice.value(midiUID, voicer, 0, outputBus.index);

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
