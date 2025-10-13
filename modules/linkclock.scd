// ======================
// Ableton Link Clock
// ======================

~linkClockOffsetBeats = ~linkClockOffsetBeats ?? { 0.306 * (120 / 60) }; // 306ms lead converted to beats at 120 BPM
~linkClickEvent = ~linkClickEvent ?? { nil };

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
    var offset;

    if(~linkClock.isNil) {
        "[LinkClock] Cannot start click: Link clock is not initialised".warn;
        ^nil;
    };

    ~stopLinkClick.value;

    offset = ~linkClockOffsetBeats ?? { 0 };

    ~linkClickEvent = nil;

    "[LinkClock] Tempo click disabled (offset applied: % beats)".format(
        offset.round(0.001)
    ).postln;
};

~setLinkClockOffset = { |beats = 0|
    ~linkClockOffsetBeats = beats;
    "[LinkClock] Offset set to % beats".format(beats.round(0.001)).postln;

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

    "[LinkClock] Initialised with quantum % beats".format(quantum).postln;

    ~linkClockMonitorTask = Task({
        var lastBeatNumber = -1;
        var beats, beatNumber, bar, beatInBar, progress, offset;

        loop {
            offset = ~linkClockOffsetBeats ?? { 0 };
            beats = (~linkClock.elapsedBeats ?? 0) - offset;
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
    var offset = ~linkClockOffsetBeats ?? { 0 };
    var beats = (~linkClock.tryPerform(\elapsedBeats) ?? { 0 }) - offset;
    (((beats / quantum).floor) + 1) * quantum + offset;
};

~scheduleOnNextLinkBar = { |func, offsetBeats = 0|
    var quantum, currentBeats, currentBeatNumber, currentBar, currentBeatInBar;
    var targetBeat, targetBar, targetBeatInBar, offset, scheduleOffset;

    if(~linkClock.isNil) {
        "[LinkClock] Cannot schedule: Link clock is not initialised".warn;
        ^nil;
    };

    quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    offset = ~linkClockOffsetBeats ?? { 0 };
    currentBeats = (~linkClock.elapsedBeats ?? 0) - offset;
    currentBeatNumber = currentBeats.floor;
    currentBar = (currentBeatNumber / quantum).floor + 1;
    currentBeatInBar = (currentBeatNumber % quantum) + 1;

    targetBeat = ~linkClockNextBarBeat.value + offsetBeats;
    targetBar = ((targetBeat - offset) / quantum).floor + 1;
    targetBeatInBar = ((targetBeat - offset) % quantum) + 1;

    "[LinkClock] Scheduling function for bar % beat % (target beat: %, current beat: %, delta: % beats)".format(
        targetBar,
        targetBeatInBar.round(0.001),
        (targetBeat - offset).round(0.001),
        currentBeats.round(0.001),
        ((targetBeat - offset) - currentBeats).round(0.001)
    ).postln;

    scheduleOffset = offset;

    ~linkClock.schedAbs(targetBeat, {
        var actualBeats = (~linkClock.elapsedBeats ?? 0) - scheduleOffset;
        var actualBeatNumber = actualBeats.floor;
        var actualBar = (actualBeatNumber / quantum).floor + 1;
        var actualBeatInBar = (actualBeatNumber % quantum) + 1;

        "[LinkClock] Triggered scheduled function at bar % beat % (expected beat: %, actual beat: %, delta: % beats)".format(
            actualBar,
            actualBeatInBar,
            (targetBeat - scheduleOffset).round(0.001),
            actualBeats.round(0.001),
            (actualBeats - (targetBeat - scheduleOffset)).round(0.001)
        ).postln;

        func.value;
        nil;
    });
};
