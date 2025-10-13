~createUI = {
    var window, channelViews, headerBar, channelArea, headerSpacer;
    var recordButton, measureContainer, measureIndicators, recordObserver;
    var windowColor = Color(0.08, 0.08, 0.1);
    var panelColor = Color(0.12, 0.12, 0.16);
    var sectionColor = Color(0.18, 0.18, 0.22);
    var accentColor = Color(0.35, 0.65, 0.95);
    var mutedColor = Color(0.8, 0.25, 0.25);
    var waitingColor = Color(0.95, 0.78, 0.25);
    var recordingColor = Color(0.85, 0.2, 0.2);
    var measureInactiveColor = Color(0.25, 0.25, 0.32);
    var measureActiveColor = accentColor;
    var eqSpecs = [
        (band: \high, name: "High", freqRange: [5000, 16000], gainRange: [-60, 20], qRange: [0.2, 5]),
        (band: \mid2, name: "Mid 2", freqRange: [1200, 5000], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \mid1, name: "Mid 1", freqRange: [250, 1200], gainRange: [-60, 20], qRange: [0.2, 10]),
        (band: \low,  name: "Low",  freqRange: [40, 250],   gainRange: [-60, 20], qRange: [0.2, 5])
    ];

    if(~mixWindow.notNil) { ~mixWindow.close };
    window = Window("MixTable - 5 voies", Rect(100, 100, 1180, 560));
    if(window.respondsTo(\resizable_)) {
        window.resizable_(true);
    } {
        if(window.respondsTo(\resizable)) {
            window.resizable = true;
        };
    };
    window.view.background_(windowColor);
    ~mixWindow = window;

    headerBar = CompositeView(window)
        .background_(panelColor)
        .minHeight_(56)
        .maxHeight_(56);

    recordButton = Button(headerBar)
        .states_([
            ["Record", Color.white, accentColor],
            ["Record", Color.black, waitingColor],
            ["Record", Color.white, recordingColor]
        ])
        .minWidth_(110)
        .maxHeight_(32);

    measureContainer = CompositeView(headerBar)
        .background_(panelColor);

    measureIndicators = (1..4).collect { |number|
        StaticText(measureContainer)
            .string_(number.asString)
            .align_(\center)
            .font_(Font("Helvetica", 13))
            .stringColor_(Color.white)
            .background_(measureInactiveColor)
            .minWidth_(32)
            .maxHeight_(28);
    };

    measureIndicators[0].background_(measureActiveColor);
    measureIndicators[0].stringColor_(Color.black);

    measureContainer.layout_(HLayout(6, *(measureIndicators.collect { |indicator|
        [indicator, 0]
    })));

    headerSpacer = CompositeView(headerBar)
        .background_(panelColor);

    headerBar.layout_(HLayout(12,
        [recordButton, 0],
        [measureContainer, 0],
        [headerSpacer, 1]
    ).margins_(10));

    channelArea = CompositeView(window)
        .background_(windowColor);

    channelViews = ~mixInputs.collect { |cfg, index|
        var channelContainer, gainSection, gainSlider, muteButton, eqArea, eqControls;

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

        eqArea = CompositeView(channelContainer)
            .minHeight_(440)
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

        eqArea.layout_(VLayout(6, *(eqControls.collect { |control|
            [control[\container], 1]
        })).margins_(4));

        gainSection.layout_(VLayout(6,
            [gainSlider, 1],
            [muteButton, 0]
        ).margins_(4));

        channelContainer.layout_(VLayout(8,
            [gainSection, 1],
            [eqArea, 3]
        ).margins_(6));

        {
            var state = ~getChannelState.value(index);
            var gainDB = state[\gainDB] ?? { 0 };
            var sliderValue = gainDB.linlin(-60, 20, 0, 1).clip(0, 1);
            var isMuted = state[\muted] ?? { 0 };
            gainSlider.value_(sliderValue);
            muteButton.value_(isMuted);

            gainSlider.action = { |sl|
                var db = sl.value.linlin(0, 1, -60, 20);
                ~setChannelGain.value(index, db);
            };

            muteButton.action = { |btn|
                var muted = btn.value.clip(0, 1);
                ~setChannelMute.value(index, muted);
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

    channelArea.layout_(HLayout(10, *(channelViews.collect { |control|
        [control[\container], 1]
    })).margins_(0));

    window.layout_(VLayout(10,
        [headerBar, 0],
        [channelArea, 1]
    ).margins_(10));

    recordButton.action = {
        ~toggleRecordTransport.tryPerform(\value);
    };

    recordObserver = { |state|
        var status = state[\state] ?? { \idle };
        var measure = (state[\measure] ?? { 1 }).clip(1, 4);
        var buttonState = case
        { status == \idle } { 0 }
        { status == \waiting } { 1 }
        { status == \stopping } { 1 }
        { status == \recording } { 2 }
        { 0 };

        recordButton.value_(buttonState);
        measureIndicators.do { |indicator, idx|
            if(idx == (measure - 1)) {
                indicator.background_(measureActiveColor);
                indicator.stringColor_(Color.black);
            } {
                indicator.background_(measureInactiveColor);
                indicator.stringColor_(Color.white);
            };
        };
    };

    ~addRecordObserver.tryPerform(\value, recordObserver);

    window.onClose = {
        ~mixWindow = nil;
        ~removeRecordObserver.tryPerform(\value, recordObserver);
        ~stopLinkMeasureSync.tryPerform(\value);
        ~freeAbletonBridgeOsc.tryPerform(\value);
        {
            ~cleanupAudio.tryPerform(\value);
            s.quit;
        }.fork(AppClock);
        window.close;
    };
    window.front;
};
