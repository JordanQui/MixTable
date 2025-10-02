// ================= Gestion MIDI =================

~clearActiveMidiSynths = {
    if(~activeMidiSynths.notNil) {
        ~activeMidiSynths.valuesDo { |synth|
            synth.tryPerform(\set, \gate, 0);
            synth.tryPerform(\free);
        };
        ~activeMidiSynths.clear;
    } {
        ~activeMidiSynths = IdentityDictionary.new;
    };
};

~setMidiRouting = { |bus, group|
    var busIndex;
    ~midiOutputBus = bus;
    ~midiTargetGroup = group;
    if(~activeMidiSynths.notNil) {
        busIndex = if(bus.respondsTo(\index)) { bus.index } { bus ?? { 0 } };
        ~activeMidiSynths.valuesDo { |synth|
            synth.tryPerform(\set, \outBus, busIndex);
            if(group.notNil) { synth.tryPerform(\moveToHead, group) };
        };
    };
};

~midiBusIndex = {
    if(~midiOutputBus.notNil) {
        if(~midiOutputBus.respondsTo(\index)) { ~midiOutputBus.index } { ~midiOutputBus };
    } {
        0
    };
};

~setupMidi = {
    var endpoint, info, defaults, srcID;

    [~noteOnResponder, ~noteOffResponder, ~filterCCResponder].do(_.tryPerform(\free));
    if(~clearActiveMidiSynths.notNil) { ~clearActiveMidiSynths.value };

    MIDIClient.init;
    endpoint = MIDIClient.findPort("TransBus", "SC1");
    if(endpoint.notNil) {
        MIDIIn.connect(endpoint.uid);
        ~midiSourceID = endpoint.uid;
    } {
        ("Port MIDI 'TransBus'/'SC1' introuvable. Connexion à toutes les sources.").warn;
        MIDIIn.connectAll;
        ~midiSourceID = nil;
    };

    ~activeMidiSynths = IdentityDictionary.new;
    info = ~getCurrentMidiSynthInfo.tryPerform(\value);
    defaults = if(info.notNil) { info[\defaults] ?? { () } } { () };
    ~currentFilterFreq = defaults[\cutoff] ?? { 1200 };

    srcID = ~midiSourceID;

    ~noteOnResponder = MIDIFunc.noteOn({ |vel, note, chan, src|
        var offKey, existing, synthInfo, synthDefaults, defName, ampBase, rq,
        attack, decay, sustain, release, cutoff, busIndex, targetGroup, synth,
        noteKey;
        if(srcID.isNil or: { src == srcID }) {
            if(vel <= 0) {
                offKey = (chan << 7) + note;
                existing = ~activeMidiSynths.removeAt(offKey);
                if(existing.notNil) { existing.tryPerform(\set, \gate, 0) };
                ^nil;
            };
            synthInfo = ~midiSynthLibrary[~currentMidiSynthKey];
            if(synthInfo.notNil) {
                synthDefaults = synthInfo[\defaults] ?? { () };
                defName = synthInfo[\defName] ?? { ~currentMidiSynthKey };
                ampBase = synthDefaults[\amp] ?? { 0.3 };
                rq = synthDefaults[\rq] ?? { 0.2 };
                attack = synthDefaults[\attack] ?? { 0.01 };
                decay = synthDefaults[\decay] ?? { 0.2 };
                sustain = synthDefaults[\sustain] ?? { 0.6 };
                release = synthDefaults[\release] ?? { 0.4 };
                cutoff = ~currentFilterFreq ?? { synthDefaults[\cutoff] ?? { 1200 } };
                busIndex = ~midiBusIndex.value;
                targetGroup = ~midiTargetGroup ?? { ~sourceGroup ?? { ~inputGroup } };
                synth = Synth(defName, [
                    \outBus, busIndex,
                    \freq, note.midicps,
                    \gate, 1,
                    \amp, (vel / 127).clip(0, 1) * ampBase,
                    \cutoff, cutoff,
                    \rq, rq,
                    \attack, attack,
                    \decay, decay,
                    \sustain, sustain,
                    \release, release
                ], target: targetGroup, addAction: \addToHead);
                noteKey = (chan << 7) + note;
                ~activeMidiSynths[noteKey] = synth;
            };
        };
    }, srcID: srcID);

    ~noteOffResponder = MIDIFunc.noteOff({ |vel, note, chan, src|
        var key, synth;
        if(srcID.isNil or: { src == srcID }) {
            key = (chan << 7) + note;
            synth = ~activeMidiSynths.removeAt(key);
            if(synth.notNil) {
                synth.tryPerform(\set, \gate, 0);
            };
        };
    }, srcID: srcID);

    ~filterCCResponder = MIDIFunc.cc({ |value, ccNum, chan, src|
        var synthInfo, synthDefaults, range, freq;
        if(srcID.isNil or: { src == srcID }) {
            synthInfo = ~midiSynthLibrary[~currentMidiSynthKey];
            if(synthInfo.notNil) {
                synthDefaults = synthInfo[\defaults] ?? { () };
                range = synthDefaults[\cutoffRange] ?? { [200, 8000] };
                freq = value.linexp(0, 127, range[0], range[1]);
                ~currentFilterFreq = freq;
                if(~activeMidiSynths.notNil) {
                    ~activeMidiSynths.valuesDo { |synth|
                        synth.tryPerform(\set, \cutoff, freq);
                    };
                };
            };
        };
    }, ccNum: 74, srcID: srcID);

    CmdPeriod.doOnce({
        [~noteOnResponder, ~noteOffResponder, ~filterCCResponder].do(_.tryPerform(\free));
        if(~clearActiveMidiSynths.notNil) { ~clearActiveMidiSynths.value };
    });
};
