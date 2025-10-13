// ======================
// Ableton Link Clock
// ======================

~linkClockOffsetBeats = ~linkClockOffsetBeats ?? { 0 };
~linkClickAmp = ~linkClickAmp ?? { 0.25 };
~linkClickAccentAmp = ~linkClickAccentAmp ?? { 0.4 };
~linkClickEvent = ~linkClickEvent ?? { nil };
~linkClickSynthReady = ~linkClickSynthReady ?? { false };

~stopLinkClick = {
    if(~linkClickEvent.notNil) {
        if(~linkClock.notNil) {
            ~linkClock.tryPerform(\unsched, ~linkClickEvent);
        };
        ~linkClickEvent = nil;
        "[LinkClock] Click stopped".postln;
    };
};

~startLinkClick = {
    var quantum, offset, startBeat;

    if(~linkClock.isNil) {
        "[LinkClock] Cannot start click: Link clock is not initialised".warn;
        ^nil;
    };

    if(~linkClickSynthReady.not) {
        "[LinkClock] Cannot start click: click SynthDef is not loaded".warn;
        ^nil;
    };

    ~stopLinkClick.value;

    quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    offset = ~linkClockOffsetBeats ?? { 0 };
    startBeat = (~linkClock.elapsedBeats.ceil) + offset;

    ~linkClickEvent = ~linkClock.schedAbs(startBeat, { |scheduledBeat|
        var beatPosition = (scheduledBeat - offset).round(0.0001);
        var accent = ((beatPosition % quantum).round(0.0001) == 0);

        Synth(\linkClick, [
            \accent, accent.if({ 1 }, { 0 }),
            \level, ~linkClickAmp ?? { 0.25 },
            \accentLevel, ~linkClickAccentAmp ?? { 0.4 }
        ]);

        scheduledBeat + 1;
    });

    "[LinkClock] Click started (offset: % beats)".format(offset.round(0.001)).postln;
};

~setLinkClockOffset = { |beats = 0|
    ~linkClockOffsetBeats = beats;
    "[LinkClock] Offset set to % beats".format(beats.round(0.001)).postln;

    if(~linkClickEvent.notNil) {
        ~startLinkClick.value;
    };
};

~setLinkClickLevels = { |level, accentLevel|
    if(level.notNil) {
        ~linkClickAmp = level.max(0);
    };

    if(accentLevel.notNil) {
        ~linkClickAccentAmp = accentLevel.max(0);
    };

    "[LinkClock] Click levels updated (level: %, accent: %)".format(
        (~linkClickAmp ?? { 0.25 }).round(0.001),
        (~linkClickAccentAmp ?? { 0.4 }).round(0.001)
    ).postln;

    if(~linkClickEvent.notNil) {
        ~startLinkClick.value;
    };
};

~setupLinkClock = {
    var quantum = 4;

    // Stop any previous monitoring task and click before creating a new one
    if (~linkClockMonitorTask.notNil) {
        ~linkClockMonitorTask.stop;
        ~linkClockMonitorTask = nil;
    };

    ~stopLinkClick.value;

    ~linkQuantum = quantum;
    ~linkClock = LinkClock.new(tempo: 120/60);
    ~linkClock.quantum_(quantum);

    ~linkClickSynthReady = false;
    SynthDef(\linkClick, { |out = 0, level = 0.25, accentLevel = 0.4, accent = 0|
        var env = Env.perc(0.001, 0.06, curve: -4).ar(doneAction: 2);
        var freq = Select.kr(accent, [2200, 3200]);
        var click = (SinOsc.ar(freq) + (WhiteNoise.ar * 0.15)) * env;
        var amp = Select.kr(accent, [level, accentLevel]);
        Out.ar(out, (click * amp) ! 2);
    }).add;
    s.sync;
    ~linkClickSynthReady = true;

    "[LinkClock] Initialised with quantum % beats".format(quantum).postln;

    ~linkClockMonitorTask = Task({
        var lastBeatNumber = -1;
        var beats, beatNumber, bar, beatInBar, progress;

        loop {
            beats = ~linkClock.elapsedBeats;
            beatNumber = beats.floor;
            bar = (beatNumber / quantum).floor + 1;
            beatInBar = (beatNumber % quantum) + 1;
            progress = (beats % quantum) / quantum;

            if (beatNumber != lastBeatNumber) {
                "[LinkClock] Bar % Beat % (progress: %%)".format(
                    bar,
                    beatInBar,
                    (progress * 100).round(0.1)
                ).postln;
                lastBeatNumber = beatNumber;
            };

            0.05.wait;
        }
    }, AppClock);

    ~linkClockMonitorTask.play;
    ~startLinkClick.value;

    CmdPeriod.doOnce({
        ~linkClockMonitorTask.tryPerform(\stop);
        ~linkClockMonitorTask = nil;
        ~stopLinkClick.value;
    });
};

~linkClockNextBarBeat = {
    var quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    var beats = ~linkClock.tryPerform(\elapsedBeats) ?? { 0 };
    (((beats / quantum).floor) + 1) * quantum;
};

~scheduleOnNextLinkBar = { |func, offsetBeats = 0|
    var quantum, currentBeats, currentBeatNumber, currentBar, currentBeatInBar;
    var targetBeat, targetBar, targetBeatInBar;

    if(~linkClock.isNil) {
        "[LinkClock] Cannot schedule: Link clock is not initialised".warn;
        ^nil;
    };

    quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    currentBeats = ~linkClock.elapsedBeats;
    currentBeatNumber = currentBeats.floor;
    currentBar = (currentBeatNumber / quantum).floor + 1;
    currentBeatInBar = (currentBeatNumber % quantum) + 1;

    targetBeat = ~linkClockNextBarBeat.value + offsetBeats;
    targetBar = (targetBeat / quantum).floor + 1;
    targetBeatInBar = (targetBeat % quantum) + 1;

    "[LinkClock] Scheduling function for bar % beat % (target beat: %, current beat: %, delta: % beats)".format(
        targetBar,
        targetBeatInBar.round(0.001),
        targetBeat.round(0.001),
        currentBeats.round(0.001),
        (targetBeat - currentBeats).round(0.001)
    ).postln;

    ~linkClock.schedAbs(targetBeat, {
        var actualBeats = ~linkClock.elapsedBeats;
        var actualBeatNumber = actualBeats.floor;
        var actualBar = (actualBeatNumber / quantum).floor + 1;
        var actualBeatInBar = (actualBeatNumber % quantum) + 1;

        "[LinkClock] Triggered scheduled function at bar % beat % (expected beat: %, actual beat: %, delta: % beats)".format(
            actualBar,
            actualBeatInBar,
            targetBeat.round(0.001),
            actualBeats.round(0.001),
            (actualBeats - targetBeat).round(0.001)
        ).postln;

        func.value;
        nil;
    });
};
