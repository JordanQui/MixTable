~createUI = {
    var window, channelViews;
    var darkBackground = Color.new255(25, 25, 25);
    var accentColor = Color.new255(90, 180, 255);
    var textColor = Color.white;

    var eqSpecs = [
        (band: \low,  name: "Low",  freqRange: [40, 250],   gainRange: [-60, 20]),
        (band: \mid1, name: "Mid 1", freqRange: [250, 1200], gainRange: [-60, 20]),
        (band: \mid2, name: "Mid 2", freqRange: [1200, 5000], gainRange: [-60, 20]),
        (band: \high, name: "High", freqRange: [5000, 16000], gainRange: [-60, 20])
    ];

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 4 voies", Rect(100, 100, 1080, 440));
    window.background_(darkBackground);
    ~mixWindow = window;

    channelViews = ~mixInputs.collect { |cfg, index|
        var channelContainer = CompositeView(window)
            .background_(Color.gray(0.12))
            .border_(Color.gray(0.35), 1)
            .minWidth_(240);
        var title = StaticText(channelContainer)
            .string_("Tranche " ++ cfg[\label])
            .align_(\center)
            .stringColor_(textColor)
            .minHeight_(24);
        var gainLabel = StaticText(channelContainer)
            .string_("Gain")
            .align_(\center)
            .stringColor_(textColor);
        var gainSlider = Slider(channelContainer)
            .orientation_(\vertical)
            .background_(Color.gray(0.2))
            .minHeight_(160);
        var gainValueLabel = StaticText(channelContainer)
            .string_("0.0 dB")
            .align_(\center)
            .stringColor_(accentColor)
            .minHeight_(24);
        var eqTitle = StaticText(channelContainer)
            .string_("Égalisation")
            .align_(\center)
            .stringColor_(textColor)
            .minHeight_(24);
        var eqArea = CompositeView(channelContainer)
            .background_(Color.gray(0.16))
            .border_(Color.gray(0.25), 1);

        var eqControls = eqSpecs.collect { |spec|
            var eqContainer = CompositeView(eqArea)
                .background_(Color.gray(0.18))
                .border_(Color.gray(0.3), 1);
            var eqName = StaticText(eqContainer)
                .string_(spec[\name])
                .align_(\center)
                .stringColor_(textColor)
                .minHeight_(20);
            var eqSlider = Slider2D(eqContainer)
                .background_(Color.gray(0.1))
                .knobColor_(accentColor)
                .minHeight_(110);
            var eqValueLabel = StaticText(eqContainer)
                .string_("")
                .align_(\center)
                .stringColor_(accentColor)
                .minHeight_(36);

            eqContainer.layout_(VLayout(6,
                [eqName, 0],
                [eqSlider, 1],
                [eqValueLabel, 0]
            ).margins_(8));

            eqSlider.action = { |view|
                var freq = view.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = view.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var display = freq.round(1).asString ++ " Hz\n" ++ gain.round(0.1).asString ++ " dB";
                eqValueLabel.string_(display);
                ~setChannelEq.value(index, spec[\band], freq, gain);
            };

            (container: eqContainer, slider: eqSlider, valueLabel: eqValueLabel, spec: spec);
        };

        eqArea.layout_(VLayout(10, *(eqControls.collect { |control|
            [control[\container], 1]
        })).margins_(10));

        channelContainer.layout_(VLayout(12,
            [title, 0],
            [gainLabel, 0],
            [gainSlider, 1],
            [gainValueLabel, 0],
            [eqTitle, 0],
            [eqArea, 2]
        ).margins_(12));

        {
            var state = ~getChannelState.value(index);
            var gainDB = state[\gainDB] ?? { 0 };
            var sliderValue = gainDB.linlin(-60, 20, 0, 1).clip(0, 1);
            gainSlider.value_(sliderValue);
            gainValueLabel.string_(gainDB.round(0.1).asString ++ " dB");

            gainSlider.action = { |sl|
                var db = sl.value.linlin(0, 1, -60, 20);
                gainValueLabel.string_(db.round(0.1).asString ++ " dB");
                ~setChannelGain.value(index, db);
            };

            eqControls.do { |control|
                var spec = control[\spec];
                var eqState = state[\eq][spec[\band]] ?? { ~eqDefaults[spec[\band]].copy };
                var x = eqState[\freq].linexp(spec[\freqRange][0], spec[\freqRange][1], 0, 1).clip(0, 1);
                var y = eqState[\gain].linlin(spec[\gainRange][0], spec[\gainRange][1], 0, 1).clip(0, 1);
                control[\slider].setXY(x, y);
                control[\valueLabel].string_(eqState[\freq].round(1).asString ++ " Hz\n" ++ eqState[\gain].round(0.1).asString ++ " dB");
            };
        }.value;

        (container: channelContainer);
    };

    window.layout_(HLayout(12, *(channelViews.collect { |control|
        control[\container]
    })).margins_(12));

    window.onClose = { ~mixWindow = nil; window.close };
    window.front;
};
