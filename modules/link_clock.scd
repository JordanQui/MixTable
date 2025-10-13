(
Link.enable;

s.waitForBoot {
    var linkClock = LinkClock.new;
    linkClock.latency = 0.03; // low latency for tight sync

    SynthDef(\linkClick, { |out = 0, amp = 0.2|
        var env = Env.perc(0.001, 0.05, curve: -4);
        var sig = WhiteNoise.ar(0.5) * EnvGen.ar(env, doneAction: 2);
        sig = HPF.ar(sig, 2000);
        Out.ar(out, (sig ! 2) * amp);
    }).add;

    s.sync;

    Pbind(
        \instrument, \linkClick,
        \dur, 1,          // quarter-note pulse
        \amp, 0.2
    ).play(linkClock);
};
)
