SynthDef(\synth1,
	{|
	out=0, gate=1, freq, buff, amp, mod, rls=3, bend, pan, ctrl1, ctrl2
	|

    var sig, env,
	freq2 = freq * bend.midiratio;

	env = Env.adsr(0.1,0.3, 1, rls).kr(2,gate);
	sig = SinOsc.ar(freq2);

	sig = sig  * env;
    Out.ar(out, Pan2.ar(sig, Rand(-1,1) * pan, amp.linexp(0,1,0.01,0.9).lag(rls)));
	}).add;
