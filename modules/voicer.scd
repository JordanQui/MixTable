// ================= Voix Mutable Instruments Braids =================
~rootNote = ~rootNote ?? { 0 };
~scale = ~scale ?? { Scale.chromatic };
~enableBraidsVoicer = ~enableBraidsVoicer ?? { true };

SynthDef(\braidsVoice, {
    |out = 0, freq = 440, vel = 1, amp = 1, mod = 0, bend = 0, gate = 1|
    var pitch, env, timbre, color, trig, sig, pressure, pressureLag, modLag, dynamicGain;
    pitch = freq * bend.midiratio;
    pressure = amp.clip(0, 1);
    pressureLag = Lag.kr(pressure, 0.1);
    modLag = Lag.kr(mod.clip(0, 1), 0.1);
    timbre = modLag.linlin(0, 1, 0.05, 0.95);
    color = pressureLag.linlin(0, 1, 0.05, 0.95);
    trig = (vel > 0).if(1, 0);
    env = EnvGen.kr(
        Env.adsr(0.01, 0.2, pressureLag.linlin(0, 1, 0.4, 1), 0.3),
        gate,
        doneAction: 2
    );
    dynamicGain = vel.clip(0, 1) * pressureLag.linexp(0, 1, 0.5, 1.2);
    sig = MiBraids.ar(
        pitch,
        timbre: timbre,
        color: color,
        model: 0,
        trig: trig,
        resamp: 2
    );
    sig = sig * dynamicGain * env;
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
        ("MIDI NoteOn reçu – Chan: %, Note: %, Vel: %".format(chan, note, vel)).postln;
        voicer.roli.put(chan, [
            \freq, (note + ~rootNote).keyToDegree(~scale, 12).degreeToKey(~scale).midicps,
            \vel, (vel / 127),
            \amp, 1,
            \gate, 1,
            \out, out
        ]);
    };

    voicer.endNote = { |q, chan|
        ("MIDI NoteOff reçu – Chan: %".format(chan)).postln;
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\gate, 0) };
    };

    voicer.setTouch = { |q, chan = 0, touchval = 64|
        ("MIDI Aftertouch reçu – Chan: %, Valeur: %".format(chan, touchval)).postln;
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\amp, (touchval / 127)) };
    };

    voicer.setSlide = { |q, chan = 0, slide = 0|
        ("MIDI Slide reçu – Chan: %, Valeur: %".format(chan, slide)).postln;
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) { obj.set(\mod, (slide / 127)) };
    };

    voicer.setBend = { |q, chan = 0, bendval = 0|
        ("MIDI Pitch Bend reçu – Chan: %, Valeur: %".format(chan, bendval)).postln;
        var obj = voicer.roli.proxy.objects[chan];
        if(obj.notNil) {
            obj.set(\bend, bendval.linlin(0, 16383, -36, 36))
        };
    };

    midiDefs.add(MIDIdef.noteOn(\roliOn ++ out, { |vel, noteNum, chan|
        ("Réception MIDIdef.noteOn – Chan: %, Note: %, Vel: %".format(chan, noteNum, vel)).postln;
        voicer.makeNote(chan, noteNum, vel);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.noteOff(\roliOff ++ out, { |vel, noteNum, chan|
        ("Réception MIDIdef.noteOff – Chan: %, Note: %, Vel: %".format(chan, noteNum, vel)).postln;
        voicer.endNote(chan, noteNum);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.cc(\roliSlide ++ out, { |val, ccnum, chan|
        ("Réception MIDIdef.cc – Chan: %, CC#: %, Valeur: %".format(chan, ccnum, val)).postln;
        voicer.setSlide(chan, val);
    }, 1, srcID: uid).enable);

    midiDefs.add(MIDIdef.touch(\roliTouch ++ out, { |val, chan, src|
        ("Réception MIDIdef.touch – Chan: %, Valeur: %".format(chan, val)).postln;
        voicer.setTouch(chan, val);
    }, srcID: uid).enable);

    midiDefs.add(MIDIdef.bend(\roliBend ++ out, { |bend, chan|
        ("Réception MIDIdef.bend – Chan: %, Valeur: %".format(chan, bend)).postln;
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
                name.contains("TransBus");
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
