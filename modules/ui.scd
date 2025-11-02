~createUI = {
    var window, channelArea, channelViews, masterColumn, layoutColumns;
    var windowColor = Color(0.08, 0.08, 0.1);
    var panelColor = Color(0.12, 0.12, 0.16);
    var sectionColor = Color(0.18, 0.18, 0.22);
    var accentColor = Color(0.35, 0.65, 0.95);
    var mutedColor = Color(0.8, 0.25, 0.25);
    var eqSpecs = [
        (band: \high, name: "High", freqRange: [5000, 16000], gainRange: [-60, 20], qRange: [0.2, 5]),
        (band: \mid2, name: "Mid 2", freqRange: [1200, 5000], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \mid1, name: "Mid 1", freqRange: [250, 1200], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \low,  name: "Low",  freqRange: [40, 250],   gainRange: [-60, 20], qRange: [0.2, 5])
    ];

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 5 voies", Rect(100, 100, 1380, 560));
    if(window.respondsTo(\resizable_)) {
        window.resizable_(true);
    } {
        if(window.respondsTo(\resizable)) {
            window.resizable = true;
        };
    };
    window.view.background_(windowColor);
    ~mixWindow = window;

    channelArea = CompositeView(window)
        .background_(windowColor);

    channelViews = ~mixInputs.collect { |cfg, index|
        var channelContainer, gainSection, gainSlider, muteButton;
        var channelBottom, eqArea, sendSection, sendSlider, eqControls;

        channelContainer = CompositeView(channelArea)
            .minWidth_(220)
            .background_(panelColor);

        gainSection = CompositeView(channelContainer)
            .background_(sectionColor);

        gainSlider = Slider(gainSection)
            .orientation_(\vertical)
            .minHeight_(160)
            .background_(panelColor)
            .knobColor_(accentColor);

        muteButton = Button(gainSection)
            .states_([
                ["Mute", Color.white, Color(0.2, 0.2, 0.25)],
                ["Muted", Color.white, mutedColor]
            ])
            .maxHeight_(28);

        channelBottom = CompositeView(channelContainer)
            .background_(sectionColor);

        eqArea = CompositeView(channelBottom)
            .minHeight_(440)
            .background_(sectionColor);

        sendSection = CompositeView(channelBottom)
            .background_(panelColor)
            .minWidth_(40);

        sendSlider = Slider(sendSection)
            .orientation_(\vertical)
            .minHeight_(440)
            .background_(sectionColor)
            .knobColor_(accentColor);

        eqControls = eqSpecs.collect { |spec|
            var eqContainer, sliderRow, eqSlider, qSlider, qRange;

            eqContainer = CompositeView(eqArea)
                .background_(panelColor);
            sliderRow = CompositeView(eqContainer)
                .background_(panelColor);
            eqSlider = Slider2D(sliderRow)
                .minHeight_(110)
                .background_(sectionColor)
                .knobColor_(accentColor);
            qSlider = Slider(sliderRow)
                .orientation_(\vertical)
                .minHeight_(110)
                .background_(sectionColor)
                .knobColor_(accentColor);

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

        eqArea.layout_(VLayout(6,
            *(eqControls.collect { |control|
                [control[\container], 1]
            })
        ).margins_(4));

        gainSection.layout_(VLayout(6,
            [gainSlider, 1],
            [muteButton, 0]
        ).margins_(4));

        sendSection.layout_(VLayout(6,
            [sendSlider, 1]
        ).margins_(4));

        channelBottom.layout_(HLayout(6,
            [eqArea, 1],
            [sendSection, 0]
        ).margins_(4));

        channelContainer.layout_(VLayout(8,
            [gainSection, 1],
            [channelBottom, 3]
        ).margins_(6));

        {
            var state = ~getChannelState.value(index);
            var gainDB = state[\gainDB] ?? { 0 };
            var sliderValue = gainDB.linlin(-60, 20, 0, 1).clip(0, 1);
            var isMuted = state[\muted] ?? { 0 };
            var sendValue = (state[\send] ?? { 0 }).clip(0, 1);
            gainSlider.value_(sliderValue);
            muteButton.value_(isMuted);
            sendSlider.value_(sendValue);

            gainSlider.action = { |sl|
                var db = sl.value.linlin(0, 1, -60, 20);
                ~setChannelGain.value(index, db);
            };

            muteButton.action = { |btn|
                var muted = btn.value.clip(0, 1);
                ~setChannelMute.value(index, muted);
            };

            sendSlider.action = { |sl|
                ~setChannelSend.value(index, sl.value.clip(0, 1));
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

    masterColumn = { |area|
        var column, masterEqArea, masterEqControls, reverbSection, reverbSliders;
        var masterState = ~getMasterEqState.value;
        var reverbState = ~getReverbState.value;

        column = CompositeView(area)
            .minWidth_(220)
            .background_(panelColor);

        masterEqArea = CompositeView(column)
            .background_(sectionColor);

        masterEqControls = eqSpecs.collect { |spec|
            var eqContainer, sliderRow, eqSlider, qSlider, qRange;

            eqContainer = CompositeView(masterEqArea)
                .background_(panelColor);
            sliderRow = CompositeView(eqContainer)
                .background_(panelColor);
            eqSlider = Slider2D(sliderRow)
                .minHeight_(110)
                .background_(sectionColor)
                .knobColor_(accentColor);
            qSlider = Slider(sliderRow)
                .orientation_(\vertical)
                .minHeight_(110)
                .background_(sectionColor)
                .knobColor_(accentColor);

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
                ~setMasterEq.value(spec[\band], freq, gain, q);
            };

            qSlider.action = { |slider|
                var freq = eqSlider.x.linexp(0, 1, spec[\freqRange][0], spec[\freqRange][1]);
                var gain = eqSlider.y.linlin(0, 1, spec[\gainRange][0], spec[\gainRange][1]);
                var q = slider.value.linexp(0, 1, qRange[0], qRange[1]);
                ~setMasterEq.value(spec[\band], freq, gain, q);
            };

            (container: eqContainer, slider: eqSlider, qSlider: qSlider, qRange: qRange, spec: spec);
        };

        masterEqArea.layout_(VLayout(6,
            *(masterEqControls.collect { |control|
                [control[\container], 1]
            })
        ).margins_(4));

        reverbSection = CompositeView(column)
            .background_(sectionColor);

        reverbSliders = [
            (key: \mix, label: "Mix"),
            (key: \room, label: "Room"),
            (key: \damp, label: "Damp")
        ].collect { |spec|
            var sliderContainer, sliderView, labelView;

            sliderContainer = CompositeView(reverbSection)
                .background_(panelColor);

            labelView = StaticText(sliderContainer)
                .string_(spec[\label])
                .align_(\center)
                .stringColor_(Color.white);

            sliderView = Slider(sliderContainer)
                .orientation_(\horizontal)
                .background_(sectionColor)
                .knobColor_(accentColor);

            sliderContainer.layout_(VLayout(4,
                [labelView, 0],
                [sliderView, 0]
            ).margins_(4));

            sliderView.action = { |sl|
                var value = sl.value.clip(0, 1);
                switch(spec[\key],
                    \mix, { ~setReverbParams.value(value, nil, nil); },
                    \room, { ~setReverbParams.value(nil, value, nil); },
                    \damp, { ~setReverbParams.value(nil, nil, value); }
                );
            };

            (container: sliderContainer, slider: sliderView, spec: spec);
        };

        reverbSection.layout_(VLayout(6,
            *(reverbSliders.collect { |slider|
                [slider[\container], 0]
            })
        ).margins_(6));

        column.layout_(VLayout(8,
            [masterEqArea, 2],
            [reverbSection, 1]
        ).margins_(6));

        {
            masterEqControls.do { |control|
                var spec = control[\spec];
                var eqState = masterState[spec[\band]] ?? { ~eqDefaults[spec[\band]].copy };
                var x = eqState[\freq].linexp(spec[\freqRange][0], spec[\freqRange][1], 0, 1).clip(0, 1);
                var y = eqState[\gain].linlin(spec[\gainRange][0], spec[\gainRange][1], 0, 1).clip(0, 1);
                var qValue = (eqState[\q] ?? { 1 }).clip(control[\qRange][0], control[\qRange][1]);
                var qSliderValue = qValue.explin(control[\qRange][0], control[\qRange][1], 0, 1).clip(0, 1);
                control[\slider].setXY(x, y);
                control[\qSlider].value_(qSliderValue);
            };

            reverbSliders.do { |slider|
                var stateValue = reverbState[slider[\spec][\key]] ?? { 0 };
                slider[\slider].value_(stateValue.clip(0, 1));
            };
        }.value;

        column;
    }.value(channelArea);

    layoutColumns = channelViews.collect { |control|
        [control[\container], 1]
    };
    layoutColumns = layoutColumns.add([masterColumn, 0]);

    channelArea.layout_(HLayout(10,
        *layoutColumns
    ).margins_(10));

    window.layout_(VLayout(10,
        [channelArea, 1]
    ).margins_(10));

    window.onClose = {
        ~mixWindow = nil;
        {
            ~cleanupAudio.tryPerform(\value);
            s.quit;
        }.fork(AppClock);
        window.close;
    };
    window.front;
};
