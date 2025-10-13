(
Link.enable;

s.waitForBoot {
    var clickPattern;

    ~linkClock = ~linkClock ?? { LinkClock.new };
    ~linkClock.latency = 0.03; // low latency for tight sync

    SynthDef(\linkMetronomeClick, { |out = 0, amp = 0.2, accent = 0|
        var env = Env.perc(0.001, 0.08, curve: -4);
        var accentLevel = accent.clip(0, 1);
        var baseClick = HPF.ar(WhiteNoise.ar(0.5), 2000);
        var accentClick = HPF.ar(WhiteNoise.ar(0.5), 2500) * 0.8
            + SinOsc.ar(accentLevel.linexp(0, 1, 700, 1200), 0, 0.35 * accentLevel);
        var click = SelectX.ar(accentLevel, [baseClick, accentClick]);
        var envGen = EnvGen.ar(env, doneAction: 2);
        var ampBoost = amp * (1 + (accentLevel * 0.6));
        Out.ar(out, (click * envGen * ampBoost) ! 2);
    }).add;

    s.sync;

    ~linkClockTempoOffset = ~linkClockTempoOffset ?? { 0 };
    ~linkClockBaseTempo = ~linkClock.tempo - ~linkClockTempoOffset;

    ~applyLinkClockTempoOffset = {
        var targetTempo = (~linkClockBaseTempo + ~linkClockTempoOffset).max(0.01);
        ~linkClock.tempo = targetTempo;
    };

    ~setLinkClockTempoOffset = { |offset|
        ~linkClockBaseTempo = ~linkClock.tempo - (~linkClockTempoOffset ?? { 0 });
        ~linkClockTempoOffset = offset;
        ~applyLinkClockTempoOffset.value;
    };

    ~getLinkClockTempoOffset = { ~linkClockTempoOffset };

    ~stopLinkMetronome = {
        ~linkMetronomePlayer.tryPerform(\stop);
        ~linkMetronomePlayer = nil;
    };

    clickPattern = Pbind(
        \instrument, \linkMetronomeClick,
        \dur, 1,
        \accent, Pseq([1, 0, 0, 0], inf),
        \amp, Pseq([0.32, 0.18, 0.18, 0.18], inf)
    );

    ~startLinkMetronome = {
        ~stopLinkMetronome.value;
        ~linkMetronomePlayer = clickPattern.play(~linkClock);
    };

    CmdPeriod.doOnce({ ~stopLinkMetronome.value });

    ~applyLinkClockTempoOffset.value;
    ~startLinkMetronome.value;
};
)
