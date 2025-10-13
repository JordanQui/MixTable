// ======================
// Ableton Link Clock
// ======================

~setupLinkClock = {
    var quantum = 4;
    var defaultTempoBPM = 120;
    var defaultTempo = defaultTempoBPM / 60;
    var sessionTempo;

    // Stop any previous monitoring task before creating a new one
    if (~linkClockMonitorTask.notNil) {
        ~linkClockMonitorTask.stop;
        ~linkClockMonitorTask = nil;
    };

    ~linkQuantum = quantum;
    ~linkClock = LinkClock.new(tempo: defaultTempo);
    ~linkClock.quantum_(quantum);

    sessionTempo = {
        var linkSession = (~linkClock.tryPerform(\link) ?? { nil });
        var detectedTempo;

        if(linkSession.notNil) {
            [\tempo, \currentTempo, \getTempo].do { |selector|
                if(detectedTempo.isNil) {
                    var value = linkSession.tryPerform(selector);

                    if(value.isKindOf(Function)) {
                        value = value.value;
                    };

                    if(value.isNumber) {
                        detectedTempo = value;
                    };
                };
            };
        };

        detectedTempo;
    }.value;

    if(sessionTempo.isNumber and: { (sessionTempo - defaultTempo).abs > 0.0001 }) {
        ~linkClock.tempo_(sessionTempo);
        "[LinkClock] Tempo synchronisé sur la session Link: % BPM".format(
            (sessionTempo * 60).round(0.01)
        ).postln;
    } {
        "[LinkClock] Tempo par défaut utilisé: % BPM".format(defaultTempoBPM).postln;
    };

    "[LinkClock] Initialised with quantum % beats @ % BPM".format(
        quantum,
        (~linkClock.tempo * 60).round(0.01)
    ).postln;

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
