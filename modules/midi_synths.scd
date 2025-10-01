// ================= Synthés pour les entrées MIDI =================
SynthDef(\percussiveSine, {
    |out = 0, freq = 440, amp = 0.2,
    attack = 0.005, release = 2,
    modAmp = 1, gate = 1, bend = 0,
    attackRatio = 1, bodyRatio = 1,
    bodyAttack = 0.02, attackLevel = 1, bodyLevel = 0.7|
    var pressure = Lag.kr(modAmp.clip(0, 1), 0.05);
    var baseFreq = freq * bend.midiratio;
    var attackEnv = EnvGen.kr(
        Env.perc(attack.max(0.001), release.max(0.01), attackLevel, curve: -4),
        gate,
        doneAction: 0
    );
    var bodyEnv = EnvGen.kr(
        Env.asr(bodyAttack.max(0.001), 1, release.max(0.01), curve: -4),
        gate,
        doneAction: 2
    );
    var attackOsc = SinOsc.ar(baseFreq * attackRatio) * attackEnv;
    var bodyOsc = SinOsc.ar(baseFreq * bodyRatio) * bodyEnv * bodyLevel;
    var sig = (attackOsc + bodyOsc) * pressure * amp;
    Out.ar(out, sig ! 2);
}).add;
