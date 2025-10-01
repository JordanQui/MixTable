// ================= Synthés pour les entrées MIDI =================
SynthDef(\percussiveSine, { |out = 0, freq = 440, amp = 0.2, attack = 0.005, release = 0.35|
    var env = Env.perc(attack.max(0.001), release.max(0.01), 1, curve: -4);
    var envGen = EnvGen.kr(env, doneAction: 2);
    var sig = SinOsc.ar(freq) * envGen * amp;
    Out.ar(out, sig ! 2);
}).add;
