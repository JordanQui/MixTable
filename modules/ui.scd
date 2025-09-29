~createUI = {
    var window, channelViews;
    var eqSpecs = [
        (band: \high, name: "High", freqRange: [5000, 16000], gainRange: [-60, 20], qRange: [0.2, 5]),
        (band: \mid2, name: "Mid 2", freqRange: [1200, 5000], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \mid1, name: "Mid 1", freqRange: [250, 1200], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \low,  name: "Low",  freqRange: [40, 250],   gainRange: [-60, 20], qRange: [0.2, 5])
    ];

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 4 voies", Rect(100, 100, 960, 560));
    if(window.respondsTo(\resizable_)) {
        window.resizable_(true);
    } {
        if(window.respondsTo(\resizable)) {
            window.resizable = true;
        };
    };
    ~mixWindow = window;

    channelViews = ~mixInputs.collect { |cfg, index|
        var channelContainer, title, gainSlider, gainValueLabel, eqArea, eqControls;

        channelContainer = CompositeView(window)
            .minWidth_(220);

        title = StaticText(channelContainer)
            .string_("Tranche " ++ cfg[\label])
            .align_(\center)
            .minHeight_(22);

        gainSlider = Slider(channelContainer)
            .orientation_(\vertical)
            .minHeight_(160);

        gainValueLabel = StaticText(channelContainer)
            .string_("0.0 dB")
            .align_(\center)
            .minHeight_(24);

        eqArea = CompositeView(channelContainer)
            .minHeight_(440);

        eqControls = eqSpecs.collect { |spec|
            var eqContainer, eqName, sliderRow, eqSlider, eqValueLabel,
                qContainer, qSlider, qTitle, qValueLabel, qRange, updateDisplay;

            eqContainer = CompositeView(eqArea);
            eqName = StaticText(eqContainer)
                .string_(spec[\name])
                .align_(\center)
                .minHeight_(20);
            sliderRow = CompositeView(eqContainer);
            eqSlider = Slider2D(sliderRow)
                .minHeight_(110);
            qContainer = CompositeView(sliderRow);
            qTitle = StaticText(qContainer)
                .string_("Q")
                .align_(\center)
                .minHeight_(20);
            qSlider = Slider(qContainer)
                .orientation_(\vertical)
                .minHeight_(110);
            qValueLabel = StaticText(qContainer)
                .string_("Q: 1.00")
                .align_(\center)
                .minHeight_(24);
            eqValueLabel = StaticText(eqContainer)
                .string_("")
                .align_(\center)
                .minHeight_(36);

            qRange = spec[\qRange] ?? { [0.2, 10] };
            updateDisplay = { |freq, gain, q|
                var display = freq.round(1).asString ++ " Hz\n" ++ gain.round(0.1).asString ++ " dB";
                eqValueLabel.string_(display);
                qValueLabel.string_("Q: " ++ q.round(0.01).asString);
            };

            qContainer.layout_(VLayout(4,
                [qTitle, 0],
                [qSlider, 1],
                [qValueLabel, 0]
            ));

            sliderRow.layout_(HLayout(6,
                [eqSlider, 1],
                [qContainer, 0]
            ));

            eqContainer.layout_(VLayout(6,
                [eqName, 0],
                [sliderRow, 1],
                [eqValueLabel, 0]
            ).margins_(4));

            eqSlider.action = { |view|
                var freq = view.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = view.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var q = qSlider.value.linexp(0, 1, qRange[0], qRange[1]);
                updateDisplay.(freq, gain, q);
                ~setChannelEq.value(index, spec[\band], freq, gain, q);
            };

            qSlider.action = { |slider|
                var freq = eqSlider.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = eqSlider.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var q = slider.value.linexp(0, 1, qRange[0], qRange[1]);
                updateDisplay.(freq, gain, q);
                ~setChannelEq.value(index, spec[\band], freq, gain, q);
            };

            (container: eqContainer, slider: eqSlider, qSlider: qSlider, valueLabel: eqValueLabel, qRange: qRange, spec: spec, updateDisplay: updateDisplay);
        };

        eqArea.layout_(VLayout(6, *(eqControls.collect { |control|
            [control[\container], 1]
        })).margins_(4));

        channelContainer.layout_(VLayout(8,
            [title, 0],
            [gainSlider, 1],
            [gainValueLabel, 0],
            [eqArea, 3]
        ).margins_(6));

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
                var qValue = (eqState[\q] ?? { 1 }).clip(control[\qRange][0], control[\qRange][1]);
                var qSliderValue = qValue.explin(control[\qRange][0], control[\qRange][1], 0, 1).clip(0, 1);
                control[\slider].setXY(x, y);
                control[\qSlider].value_(qSliderValue);
                control[\updateDisplay].(eqState[\freq], eqState[\gain], qValue);
            };
        }.value;

        (container: channelContainer);
    };

    window.layout_(HLayout(10, *(channelViews.collect { |control|
        [control[\container], 1]
    })).margins_(10));

    window.onClose = { ~mixWindow = nil; window.close };
    window.front;
};
