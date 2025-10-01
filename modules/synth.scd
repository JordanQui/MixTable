SynthDef(\roli_kaivoY001,
	{|
	out=0, gate=1, freq, buff, amp, mod, rls=3, bend, pan, ctrl1, ctrl2
	|

    var sig, env, rlpfsig, rbpfsig,
	freq2 = freq * bend.midiratio;

	env = Env.adsr(0.1,0.3, 1, rls).kr(2,gate);

	sig = SelectX.ar(amp.squared.lag(0.1), [
            SinOsc.ar(freq2),
            Saw.ar(freq2),
        ]);

	sig = sig  * env;
	rlpfsig = BMoog.ar(sig, SinOsc.ar(mod.linexp(0,1,1,4)).range(1000, 1333) * amp.linexp(0,1,0.15,1).lag(0.1), 0.33, 0 );
	rbpfsig = Friction.ar(
		BMoog.ar(sig, mod.linexp(0,1,5e3,18e3), 0.33, 3),
		friction: mod.linlin(0,1,0.001,0.03).lag(0.1), mass: amp.linexp(0,1,0.2,5.25).lag(0.1),
	);
	sig = Mix.ar([rlpfsig, rbpfsig * mod.squared.lag(0.2)]*0.5);
	sig = (sig).tanh;
    Out.ar(out, Pan2.ar(sig, Rand(-1,1) * pan, amp.linexp(0,1,0.01,0.9).lag(rls)));
	}).add;
