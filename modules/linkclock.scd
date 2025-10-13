// ======================
// Ableton Link Clock
// ======================

~linkClockLatencyOffset = ~linkClockLatencyOffset ?? { 0.306 };

~setupLinkClock = {
    var quantum = 4;

    ~linkQuantum = quantum;
    ~linkClock = LinkClock.new;
    ~linkClock.quantum_(quantum);
    ~linkClock.latency_(~linkClockLatencyOffset);
};

~linkClockNextBarBeat = {
    var quantum = (~linkClock.tryPerform(\quantum) ?? { ~linkQuantum ?? { 4 } });
    var beats = ~linkClock.tryPerform(\elapsedBeats) ?? { 0 };
    (((beats / quantum).floor) + 1) * quantum;
};

~scheduleOnNextLinkBar = { |func, offsetBeats = 0|
    var targetBeat;

    if(~linkClock.isNil) {
        ^nil;
    };

    targetBeat = ~linkClockNextBarBeat.value + offsetBeats;

    ~linkClock.schedAbs(targetBeat, {
        func.value;
        nil;
    });
};
