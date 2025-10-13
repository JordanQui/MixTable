~createUI = {
    var window, topBar, channelArea, channelViews, recordButton;
    var windowColor = Color(0.08, 0.08, 0.1);
    var panelColor = Color(0.12, 0.12, 0.16);
    var sectionColor = Color(0.18, 0.18, 0.22);
    var accentColor = Color(0.35, 0.65, 0.95);
    var mutedColor = Color(0.8, 0.25, 0.25);
    var recordBaseStates, recordStoppingStates;
    var updateRecordButtonState, armRecording, cancelArming, scheduleStop, cancelStop;
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

    ~recordState = ~recordState ?? { \idle };
    ~recordStartPending = false;
    ~recordStopPending = false;

    recordBaseStates = [
        ["Record", Color.white, Color(0.8, 0.2, 0.2)],
        ["Armé (prochaine mesure)", Color.white, Color(0.95, 0.7, 0.2)],
        ["Enregistrement", Color.white, Color(0.2, 0.7, 0.35)]
    ];

    recordStoppingStates = [
        ["Record", Color.white, Color(0.8, 0.2, 0.2)],
        ["Arrêt fin mesure", Color.white, Color(0.95, 0.7, 0.2)],
        ["Enregistrement", Color.white, Color(0.2, 0.7, 0.35)]
    ];

    topBar = CompositeView(window)
        .background_(panelColor)
        .maxHeight_(56);

    recordButton = Button(topBar)
        .states_(recordBaseStates.deepCopy)
        .maxWidth_(220)
        .minHeight_(30)
        .font_(Font("Helvetica-Bold", 14));

    updateRecordButtonState = { |state|
        switch(state,
            \idle, {
                recordButton.states_(recordBaseStates.deepCopy);
                recordButton.value_(0);
            },
            \arming, {
                recordButton.states_(recordBaseStates.deepCopy);
                recordButton.value_(1);
            },
            \recording, {
                recordButton.states_(recordBaseStates.deepCopy);
                recordButton.value_(2);
            },
            \stopping, {
                recordButton.states_(recordStoppingStates.deepCopy);
                recordButton.value_(1);
            }
        );
    };

    armRecording = {
        var scheduler;
        if(~linkClock.isNil) {
            "[Record] Impossible de démarrer : LinkClock non initialisé".warn;
            ^thisThread
        };

        ~recordStartPending = true;
        ~recordStopPending = false;
        ~recordState = \arming;
        updateRecordButtonState.(~recordState);

        scheduler = ~scheduleOnNextLinkBar;
        if(scheduler.isNil) {
            "[Record] Impossible de planifier : fonction de planification absente".warn;
            ~recordStartPending = false;
            ~recordState = \idle;
            updateRecordButtonState.(~recordState);
            ^thisThread;
        };

        scheduler.value({
            var recordBus = (~recordBusIndex ?? { 0 });
            var recordChannels = (~recordNumChannels ?? { s.options.numOutputBusChannels ?? { 2 } });

            if(~recordStartPending.not) { ^nil };

            s.prepareForRecord(numChannels: recordChannels, bus: recordBus);
            s.record(numChannels: recordChannels, bus: recordBus);

            {
                ~recordStartPending = false;
                ~recordState = \recording;
                updateRecordButtonState.(~recordState);
            }.defer;
        });
    };

    cancelArming = {
        if(~recordState != \arming) { ^thisThread };

        ~recordStartPending = false;
        ~recordState = \idle;
        updateRecordButtonState.(~recordState);
    };

    scheduleStop = {
        var scheduler;
        if(~linkClock.isNil) {
            "[Record] Impossible d'arrêter : LinkClock non initialisé".warn;
            ^thisThread
        };

        ~recordStopPending = true;
        ~recordState = \stopping;
        updateRecordButtonState.(~recordState);

        scheduler = ~scheduleOnNextLinkBar;
        if(scheduler.isNil) {
            "[Record] Impossible de planifier l'arrêt : fonction absente".warn;
            ~recordStopPending = false;
            ~recordState = \recording;
            updateRecordButtonState.(~recordState);
            ^thisThread;
        };

        scheduler.value({
            if(~recordStopPending.not) { ^nil };

            if(s.recording) { s.stopRecording };

            {
                ~recordStopPending = false;
                ~recordState = \idle;
                updateRecordButtonState.(~recordState);
            }.defer;
        });
    };

    cancelStop = {
        if(~recordState != \stopping) { ^thisThread };

        ~recordStopPending = false;
        ~recordState = \recording;
        updateRecordButtonState.(~recordState);
    };

    recordButton.action = {
        switch(~recordState,
            \idle, {
                armRecording.value;
            },
            \arming, {
                cancelArming.value;
            },
            \recording, {
                scheduleStop.value;
            },
            \stopping, {
                cancelStop.value;
            }
        );
    };

    ~recordButton = recordButton;
    updateRecordButtonState.(~recordState);

    topBar.layout_(HLayout(10,
        [recordButton, 0]
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
    })).margins_(10));

    window.layout_(VLayout(10,
        [topBar, 0],
        [channelArea, 1]
    ).margins_(10));

    window.onClose = {
        ~recordButton = nil;
        ~recordState = \idle;
        ~recordStartPending = false;
        ~recordStopPending = false;
        ~mixWindow = nil;
        {
            ~cleanupAudio.tryPerform(\value);
            s.quit;
        }.fork(AppClock);
        window.close;
    };
    window.front;
};
