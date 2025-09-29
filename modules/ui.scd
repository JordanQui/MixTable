~createUI = {
    var window, masterSlider, masterLabel, masterValueLabel;
    var eqSpecs, eqControls;

    var darkBackground = Color.new255(25, 25, 25);
    var accentColor = Color.new255(90, 180, 255);

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 4 entrées", Rect(100, 100, 760, 360));
    window.background_(darkBackground);
    ~mixWindow = window;

    masterLabel = StaticText(window)
        .string_("Gain maître")
        .align_(\center)
        .stringColor_(Color.white);

    masterSlider = Slider(window);
    masterSlider.orientation_(\vertical);
    masterSlider.background_(Color.gray(0.2));

    masterValueLabel = StaticText(window)
        .string_("0.0 dB")
        .align_(\center)
        .stringColor_(Color.white);

    eqSpecs = [
        (band: \low,  name: "Low",  freqRange: [40, 250],   gainRange: [-12, 12]),
        (band: \mid1, name: "Mid 1", freqRange: [250, 1200], gainRange: [-12, 12]),
        (band: \mid2, name: "Mid 2", freqRange: [1200, 5000], gainRange: [-12, 12]),
        (band: \high, name: "High", freqRange: [5000, 16000], gainRange: [-12, 12])
    ];

    eqControls = eqSpecs.collect { |spec|
        var container = CompositeView(window, Rect(0, 0, 160, 260))
            .background_(Color.gray(0.12))
            .border_(Color.gray(0.35), 1);
        var title = StaticText(container)
            .string_(spec[\name])
            .align_(\center)
            .stringColor_(Color.white)
            .minHeight_(24);
        var valueLabel = StaticText(container)
            .string_("" )
            .align_(\center)
            .stringColor_(accentColor)
            .minHeight_(36);
        var slider = Slider2D(container)
            .background_(Color.gray(0.18))
            .knobColor_(accentColor);

        container.layout_(VLayout(6,
            [title, 0],
            [slider, 1],
            [valueLabel, 0]
        ).margins_(10));

        slider.action = { |view|
            var freq = view.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
            var gain = view.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
            var display = freq.round(1).asString ++ " Hz\n" ++ gain.round(0.1).asString ++ " dB";
            valueLabel.string_(display);
            ~setEqBand.value(spec[\band], freq, gain);
        };

        (container: container, slider: slider, valueLabel: valueLabel, spec: spec);
    };

    window.layout_(HLayout(12,
        VLayout(8,
            [masterLabel, 0],
            [masterSlider, 1],
            [masterValueLabel, 0]
        ).margins_(12),
        HLayout(12, *eqControls.collect(_.container))
    ).margins_(12));

    {
        var masterDB = ~getMasterGain.value;
        var sliderValue = masterDB.linlin(0, 12, 0, 1).clip(0, 1);
        masterSlider.value_(sliderValue);
        masterValueLabel.string_(masterDB.round(0.1).asString ++ " dB");
    }.value;

    masterSlider.action = { |sl|
        var db = sl.value.linlin(0, 1, 0, 12);
        masterValueLabel.string_(db.round(0.1).asString ++ " dB");
        ~setMasterGain.value(db);
    };

    eqControls.do { |control|
        var spec = control[\spec];
        var state = ~getEqState.value(spec[\band]);
        var x = state[\freq].linexp(spec[\freqRange][0], spec[\freqRange][1], 0, 1).clip(0, 1);
        var y = state[\gain].linlin(spec[\gainRange][0], spec[\gainRange][1], 0, 1).clip(0, 1);
        control[\slider].setXY(x, y);
        control[\valueLabel].string_(state[\freq].round(1).asString ++ " Hz\n" ++ state[\gain].round(0.1).asString ++ " dB");
    };

    window.onClose = { ~mixWindow = nil; window.close };
    window.front;
};

