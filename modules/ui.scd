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
    var greyholeSpecs = [
        (key: \dryWet, label: "Mix", range: [0, 1]),
        (key: \delayTime, label: "Delay", range: [0.01, 5]),
        (key: \damp, label: "Damp", range: [0, 1]),
        (key: \size, label: "Size", range: [0, 3]),
        (key: \diff, label: "Diff", range: [0, 1]),
        (key: \feedback, label: "Feedbk", range: [0, 0.99]),
        (key: \modDepth, label: "ModDepth", range: [0, 1]),
        (key: \modFreq, label: "ModFreq", range: [0, 10]),
        (key: \earlyDiff, label: "Early", range: [0, 1]),
        (key: \spread, label: "Spread", range: [0, 1])
    ];
    var chorusSpecs = [
        (key: \chorusDepth, label: "Depth", range: [0, 1]),
        (key: \chorusDryWet, label: "Mix", range: [0, 1]),
        (key: \chorusFeedback, label: "Feedbk", range: [0, 1])
    ];

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 5 voies", Rect(100, 100, 1380, 700));
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
        var channelBottom, eqArea, eqControls, greyholeSection, auxSection, auxSendSlider;
        var greyholeControls, greyholeColumns, chorusSection, chorusControls, chorusColumns;

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

        greyholeSection = CompositeView(channelBottom)
            .background_(sectionColor);

        chorusSection = CompositeView(channelBottom)
            .background_(sectionColor);

        auxSection = CompositeView(channelBottom)
            .background_(sectionColor);

        auxSendSlider = Slider(auxSection)
            .orientation_(\horizontal)
            .background_(sectionColor)
            .knobColor_(accentColor);

        eqArea = CompositeView(channelBottom)
            .minHeight_(320)
            .background_(sectionColor);

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

        greyholeControls = greyholeSpecs.collect { |spec|
            var container, slider, labelView;
            container = CompositeView(greyholeSection)
                .background_(panelColor);
            slider = Slider(container)
                .orientation_(\horizontal)
                .background_(sectionColor)
                .knobColor_(accentColor);
            labelView = StaticText(container)
                .string_(spec[\label])
                .align_(\left)
                .stringColor_(Color.white)
                .font_(Font(Font.defaultSansFace, 9));
            container.layout_(HLayout(4,
                [slider, 1],
                [labelView, 0]
            ).margins_(2));
            slider.action = { |sl|
                var value = sl.value.linlin(0, 1, spec[\range][0], spec[\range][1]);
                ~setChannelGreyhole.value(index, spec[\key], value);
            };
            (container: container, slider: slider, spec: spec);
        };

        greyholeColumns = greyholeControls.clump(5).collect { |columnControls|
            var columnView = CompositeView(greyholeSection)
                .background_(sectionColor);
            columnView.layout_(VLayout(2,
                *(columnControls.collect { |control| [control[\container], 0] })
            ).margins_(2));
            columnView;
        };

        chorusControls = chorusSpecs.collect { |spec|
            var container, slider, labelView;
            container = CompositeView(chorusSection)
                .background_(panelColor);
            slider = Slider(container)
                .orientation_(\horizontal)
                .background_(sectionColor)
                .knobColor_(accentColor);
            labelView = StaticText(container)
                .string_(spec[\label])
                .align_(\left)
                .stringColor_(Color.white)
                .font_(Font(Font.defaultSansFace, 9));
            container.layout_(HLayout(4,
                [slider, 1],
                [labelView, 0]
            ).margins_(2));
            slider.action = { |sl|
                var value = sl.value.linlin(0, 1, spec[\range][0], spec[\range][1]);
                ~setChannelChorus.value(index, spec[\key], value);
            };
            (container: container, slider: slider, spec: spec);
        };

        chorusColumns = chorusControls.clump(2).collect { |columnControls|
            var columnView = CompositeView(chorusSection)
                .background_(sectionColor);
            columnView.layout_(VLayout(2,
                *(columnControls.collect { |control| [control[\container], 0] })
            ).margins_(2));
            columnView;
        };

        greyholeSection.layout_(HLayout(6,
            *(greyholeColumns.collect { |column| [column, 1] })
        ).margins_(4));

        chorusSection.layout_(HLayout(6,
            *(chorusColumns.collect { |column| [column, 1] })
        ).margins_(4));

        eqArea.layout_(VLayout(6,
            *(eqControls.collect { |control|
                [control[\container], 1]
            })
        ).margins_(4));

        auxSection.layout_(VLayout(2,
            [auxSendSlider, 0]
        ).margins_(2));

        gainSection.layout_(VLayout(6,
            [gainSlider, 1],
            [muteButton, 0]
        ).margins_(4));

        channelBottom.layout_(VLayout(6,
            [greyholeSection, 0],
            [chorusSection, 0],
            [auxSection, 0],
            [eqArea, 1]
        ).margins_(4));

        channelContainer.layout_(VLayout(2,
            [gainSection, 1],
            [channelBottom, 3]
        ).margins_(6));

        {
            var state = ~getChannelState.value(index);
            var gainDB = state[\gainDB] ?? { 0 };
            var sliderValue = gainDB.linlin(-60, 20, 0, 1).clip(0, 1);
            var isMuted = state[\muted] ?? { 0 };
            var auxValue = (state[\aux] ?? { 0 }).clip(0, 1);
            var greyholeState = state[\greyhole] ?? { ~greyholeDefaults.copy };
            gainSlider.value_(sliderValue);
            muteButton.value_(isMuted);
            auxSendSlider.value_(auxValue);

            gainSlider.action = { |sl|
                var db = sl.value.linlin(0, 1, -60, 20);
                ~setChannelGain.value(index, db);
            };

            muteButton.action = { |btn|
                var muted = btn.value.clip(0, 1);
                ~setChannelMute.value(index, muted);
            };

            auxSendSlider.action = { |sl|
                ~setChannelAux.value(index, sl.value.clip(0, 1));
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

            greyholeControls.do { |control|
                var range = control[\spec][\range];
                var value = greyholeState[control[\spec][\key]] ?? { range[0] };
                var normalized = value.linlin(range[0], range[1], 0, 1).clip(0, 1);
                control[\slider].value_(normalized);
            };

            chorusControls.do { |control|
                var range = control[\spec][\range];
                var value = greyholeState[control[\spec][\key]] ?? { range[0] };
                var normalized = value.linlin(range[0], range[1], 0, 1).clip(0, 1);
                control[\slider].value_(normalized);
            };
        }.value;

        (container: channelContainer);
    };

    masterColumn = { |area|
        var column, masterEqArea, masterEqControls, returnSection, returnSliders, recordButton, recordContainer;
        var masterState = ~getMasterEqState.value;
        var stereoInputState = ~getStereoInputState.value;
        var reverbReturnState = ~getReverbReturnState.value;

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

        returnSection = CompositeView(column)
            .background_(sectionColor);

        returnSliders = [
            (key: \stereoInput, label: "In 19/20", mode: \db, action: { |value| ~setStereoInputGain.value(value); }),
            (key: \reverbReturn, label: "Reverb Return", mode: \db, action: { |value| ~setReverbReturnGain.value(value); }),
            (key: \reverbMix, label: "Reverb Mix", mode: \linear, range: [0, 1], action: { |value| ~setReverbReturnMix.value(value); })
        ].collect { |spec|
            var sliderContainer, sliderView, labelView;

            sliderContainer = CompositeView(returnSection)
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
                var value = case
                    { spec[\mode] == \db } { sl.value.linlin(0, 1, -60, 20) }
                    { spec[\mode] == \linear } {
                        var range = spec[\range] ?? { [0, 1] };
                        sl.value.linlin(0, 1, range[0], range[1]);
                    };
                spec[\action].value(value);
            };

            (container: sliderContainer, slider: sliderView, spec: spec);
        };

        recordButton = Button(returnSection)
            .states_([
                ["Record", Color.white, Color(0.3, 0.3, 0.35)],
                ["Stop", Color.white, mutedColor]
            ])
            .maxWidth_(90);

        recordButton.action = { |btn|
            if(btn.value == 1) {
                s.prepareForRecord;
                s.record;
            } {
                s.stopRecording;
            };
        };

        recordContainer = CompositeView(returnSection)
            .background_(panelColor);

        recordContainer.layout_(HLayout(6,
            [StaticText(recordContainer)
                .string_(" ")
                .stringColor_(Color.clear), 1],
            [recordButton, 0]
        ).margins_(4));

        returnSection.layout_(VLayout(6,
            *(returnSliders.collect { |slider|
                [slider[\container], 0]
            } ++ [[recordContainer, 0]])
        ).margins_(6));

        column.layout_(VLayout(8,
            [masterEqArea, 2],
            [returnSection, 1]
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

            returnSliders.do { |slider|
                var value = case
                { slider[\spec][\key] == \stereoInput } { stereoInputState[\gainDB] ?? { 0 } }
                { slider[\spec][\key] == \reverbReturn } { reverbReturnState[\gainDB] ?? { 0 } }
                { slider[\spec][\key] == \reverbMix } { reverbReturnState[\mix] ?? { 0.35 } };

                slider[\slider].value_(case
                    { slider[\spec][\mode] == \db } { value.linlin(-60, 20, 0, 1).clip(0, 1) }
                    { slider[\spec][\mode] == \linear } {
                        var range = slider[\spec][\range] ?? { [0, 1] };
                        value.linlin(range[0], range[1], 0, 1).clip(0, 1);
                    }
                );
            };

            if(s.isRecording) {
                recordButton.value_(1);
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
