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
        var channelContainer, gainSlider, eqArea, eqControls;

        channelContainer = CompositeView(window)
            .minWidth_(220);

        gainSlider = Slider(channelContainer)
            .orientation_(\vertical)
            .minHeight_(160);

        eqArea = CompositeView(channelContainer)
            .minHeight_(440);

        eqControls = eqSpecs.collect { |spec|
            var eqContainer, sliderRow, eqSlider, qSlider, qRange;

            eqContainer = CompositeView(eqArea);
            sliderRow = CompositeView(eqContainer);
            eqSlider = Slider2D(sliderRow)
                .minHeight_(110);
            qSlider = Slider(sliderRow)
                .orientation_(\vertical)
                .minHeight_(110);

            qRange = spec[\qRange] ?? { [0.2, 10] };

            sliderRow.layout_(HLayout(6,
                [eqSlider, 1],
                [qSlider, 0]
            ));

            eqContainer.layout_(VLayout(6,
                [sliderRow, 1]
            ).margins_(4));

            eqSlider.action = { |view|
                var freq = view.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = view.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var q = qSlider.value.linexp(0, 1, qRange[0], qRange[1]);
                ~setChannelEq.value(index, spec[\band], freq, gain, q);
            };

            qSlider.action = { |slider|
                var freq = eqSlider.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = eqSlider.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var q = slider.value.linexp(0, 1, qRange[0], qRange[1]);
                ~setChannelEq.value(index, spec[\band], freq, gain, q);
            };

            (container: eqContainer, slider: eqSlider, qSlider: qSlider, qRange: qRange, spec: spec);
        };

        eqArea.layout_(VLayout(6, *(eqControls.collect { |control|
            [control[\container], 1]
        })).margins_(4));

        channelContainer.layout_(VLayout(8,
            [gainSlider, 1],
            [eqArea, 3]
        ).margins_(6));

        {
            var state = ~getChannelState.value(index);
            var gainDB = state[\gainDB] ?? { 0 };
            var sliderValue = gainDB.linlin(-60, 20, 0, 1).clip(0, 1);
            gainSlider.value_(sliderValue);

            gainSlider.action = { |sl|
                var db = sl.value.linlin(0, 1, -60, 20);
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
