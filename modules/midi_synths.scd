// ================= Synthés pour les entrées MIDI =================
SynthDef(\percussiveSine, { |out = 0, freq = 440, amp = 0.2, attack = 0.005, release = 2, modAmp = 1, gate=1|
    var env = Env.perc(attack.max(0.001), release.max(0.01), 1, curve: -4);
    var envGen = Env.adsr(0.001,2, 1, release).kr(2,gate);
	var sigPerc = SinOsc.ar(freq) * envGen * amp * modAmp.lag(0.1);
	var sigBody = SinOsc.ar(freq) * modAmp;
	var sig = Mix.ar([sigPerc, sigBody]);
    Out.ar(out, sig ! 2);
}).add;
