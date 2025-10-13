// ======================
// Ableton Link Clock
// ======================

~setupLinkClock = {
    var quantum = 4;

    // Stop any previous monitoring task before creating a new one
    if (~linkClockMonitorTask.notNil) {
        ~linkClockMonitorTask.stop;
        ~linkClockMonitorTask = nil;
    };

    ~linkQuantum = quantum;
    ~linkClock = LinkClock.new(tempo: 120/60, quantum: quantum);

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
};

~linkClockNextBarBeat = {
    var quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    var beats = ~linkClock.tryPerform(\elapsedBeats) ?? { 0 };
    (((beats / quantum).floor) + 1) * quantum;
};

~scheduleOnNextLinkBar = { |func|
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

    targetBeat = ~linkClockNextBarBeat.value;
    targetBar = (targetBeat / quantum).floor + 1;
    targetBeatInBar = (targetBeat % quantum) + 1;

    "[LinkClock] Scheduling function for bar % beat % (target beat: %, current beat: %, delta: % beats)".format(
        targetBar,
        targetBeatInBar,
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
