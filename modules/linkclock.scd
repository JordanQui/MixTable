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
