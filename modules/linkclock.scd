// ======================
// Ableton Link Clock
// ======================

SynthDef(\linkMetronomeClick, {
    var env = Env.perc(0.001, 0.1, 1, -4);
    var amp = 0.2;
    var click = WhiteNoise.ar * EnvGen.ar(env, doneAction: 2);
    click = BPF.ar(click, 3000, 0.3) * amp;
    Out.ar(0, click ! 2);
}).add;

~setupLinkClock = {
    var quantum = 4;

    // Stop any previous monitoring task before creating a new one
    if (~linkClockMonitorTask.notNil) {
        ~linkClockMonitorTask.stop;
        ~linkClockMonitorTask = nil;
    };

    if (~linkClockMetronome.notNil) {
        ~linkClockMetronome.stop;
        ~linkClockMetronome = nil;
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

    ~linkClockMetronome = Routine({
        var offset = (~linkClock.elapsedBeats.ceil - ~linkClock.elapsedBeats).max(0);
        if (offset > 0) {
            offset.wait;
        };

        loop {
            Synth(\linkMetronomeClick);
            1.wait;
        }
    }).play(~linkClock);
};
