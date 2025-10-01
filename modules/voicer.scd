// ================= Voix Mutable Instruments Braids =================
~rootNote = ~rootNote ?? { 0 };
~scale = ~scale ?? { Scale.chromatic };
~enableBraidsVoicer = ~enableBraidsVoicer ?? { true };

SynthDef(\braidsVoice, {
    |out = 0, freq = 440, vel = 1, amp = 1, mod = 0, bend = 0, gate = 1|
    var pitch, env, timbre, color, trig, sig;
    pitch = freq * bend.midiratio;
    timbre = mod.linlin(0, 1, 0.05, 0.95);
    color = amp.clip(0, 1);
    trig = (vel > 0).if(1, 0);
    env = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 2);
    sig = MiBraids.ar(pitch, timbre: timbre, color: color, model: 0, trig: trig, resamp: 2);
    sig = sig * (vel.clip(0, 1) * amp.clip(0, 1)) * env;
    Out.ar(out, sig!2);
}).add;

~braidsMidiDefs = ~braidsMidiDefs ?? { List.new };

~freeBraidsMidiDefs = {
    ~braidsMidiDefs.do { |def| def.tryPerform(\free) };
    ~braidsMidiDefs = List.new;
};

~teardownBraidsVoicer = {
    ~freeBraidsMidiDefs.value;
    ~braidsVoicer.tryPerform(\free);
    ~braidsVoicer = nil;
    ~voiceBus.tryPerform(\free);
    ~voiceBus = nil;
};

~configureBraidsVoicer = {
    |uid, voicer, bank, out|
    var midiDefs = List.new;

    voicer.indivParams;
    voicer.roli.prime(\braidsVoice);

    voicer.makeNote = { |q, chan, note = 60, vel = 64|
        voicer.roli.put(chan, [
            \freq, (note + ~rootNote).keyToDegree(~scale, 12).degreeToKey(~scale).midicps,
            \vel, (vel / 127),
            \amp, 1,
            \gate, 1,
            \out, out
        ]);
    };

    voicer.endNote = { |q, chan|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\gate, 0) };
    };

    voicer.setTouch = { |q, chan = 0, touchval = 64|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\amp, (touchval / 127)) };
    };

    voicer.setSlide = { |q, chan = 0, slide = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\mod, (slide / 127)) };
    };

    voicer.setBend = { |q, chan = 0, bendval = 0|
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) {
            obj.set(\bend, bendval.linlin(0, 16383, -36, 36))
        };
    };

    midiDefs.add(MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
        voicer.makeNote(chan, noteNum, vel);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
        voicer.endNote(chan, noteNum);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
        voicer.setSlide(chan, val);
    }, 1, srcID: uid).enable);

    midiDefs.add(MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
        voicer.setTouch(chan, val);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.bend(\roliBend ++ out, { |bend, chan|
        voicer.setBend(chan, bend);
    }, srcID: uid).enable);

    midiDefs
};

~setupBraidsVoicer = {
    |voiceGroup, mixInputs, channelIndex = 0, fallbackConfig|
    var result = (voiceBus: nil, voicer: nil);
    var baseConfig;

    baseConfig = fallbackConfig ?? { mixInputs[channelIndex] };
    baseConfig = baseConfig.copy;

    if(~enableBraidsVoicer ?? { true }) {
        if(thisProcess.interpreter.notNil and: { NPVoicer.notNil }) {
            var iacSource, uid, voiceBus, voicer, updatedConfig;
            MIDIClient.init;
            iacSource = MIDIClient.sources.detect { |src|
                var name = [src.device, src.name].collect(_.asString).join(" ");
                name.contains("IAC");
            };
            if(iacSource.notNil) {
                uid = iacSource.uid;
                voiceBus = Bus.audio(s, 2);
                updatedConfig = baseConfig.copy.putAll((
                    label: (baseConfig[\label] ?? { "1" }).asString ++ " – Braids",
                    channels: [voiceBus.index, voiceBus.index + 1],
                    isMono: 0,
                    useSoundIn: 0
                ));
                voicer = NPVoicer(15, \braidsVoice, target: voiceGroup, out: voiceBus.index);
                if(voicer.notNil) {
                    ~freeBraidsMidiDefs.value;
                    ~braidsMidiDefs = ~configureBraidsVoicer.value(uid, voicer, nil, voiceBus.index);
                    mixInputs[channelIndex] = updatedConfig;
                    ~braidsVoicer = voicer;
                    ~voiceBus = voiceBus;
                    result = (voiceBus: voiceBus, voicer: voicer);
                } {
                    "Impossible de créer le NPVoicer pour la voix Braids.".warn;
                    voiceBus.free;
                    mixInputs[channelIndex] = baseConfig;
                };
            } {
                "Aucune source MIDI IAC trouvée pour le NPVoicer.".warn;
                mixInputs[channelIndex] = baseConfig;
            };
        } {
            "NPVoicer n'est pas disponible dans cet environnement.".warn;
            mixInputs[channelIndex] = baseConfig;
        };
    } {
        mixInputs[channelIndex] = baseConfig;
    };

    result
};
