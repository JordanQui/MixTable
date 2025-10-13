// Gestion de l'interface avec Ableton Bridge pour la fonction Record
~ensureRecordTransport = {
    if(~recordTransportState.isNil) {
        ~recordTransportState = (
            state: \idle,
            measure: 1,
            rawMeasure: 1,
            pendingStop: false,
            observers: List.new
        );
    };
};

~notifyRecordTransport = {
    var snapshot;
    ~ensureRecordTransport.value;
    snapshot = (
        state: ~recordTransportState[\state],
        measure: ~recordTransportState[\measure]
    );
    ~recordTransportState[\observers].do { |observer|
        {
            observer.(snapshot)
        }.try({ |error|
            ("Record observer error: %".format(error)).warn;
        });
    };
};

~addRecordObserver = { |observer|
    ~ensureRecordTransport.value;
    if(observer.notNil) {
        ~recordTransportState[\observers].add(observer);
        observer.((
            state: ~recordTransportState[\state],
            measure: ~recordTransportState[\measure]
        ));
    };
};

~removeRecordObserver = { |observer|
    ~ensureRecordTransport.value;
    if(observer.notNil) {
        ~recordTransportState[\observers].remove(observer);
    };
};

~setRecordState = { |newState|
    ~ensureRecordTransport.value;
    ~recordTransportState[\state] = newState;
    if(newState != \stopping) {
        ~recordTransportState[\pendingStop] = false;
    };
    ~notifyRecordTransport.value;
};

~setRecordMeasure = { |measure|
    var rawMeasure, previousRaw, clipped, wrapped;
    ~ensureRecordTransport.value;
    rawMeasure = measure.asInteger.max(1);
    previousRaw = ~recordTransportState[\rawMeasure] ?? { rawMeasure };
    clipped = rawMeasure.clip(1, 4);
    wrapped = rawMeasure < previousRaw;
    if(previousRaw != rawMeasure) {
        ~recordTransportState[\rawMeasure] = rawMeasure;
    };
    if(~recordTransportState[\measure] != clipped) {
        ~recordTransportState[\measure] = clipped;
        ~notifyRecordTransport.value;
    };
    if((~recordTransportState[\state] == \stopping) and: { ~recordTransportState[\pendingStop] } and: { wrapped }) {
        ~finalizePendingStop.value;
    };
};

~ensureLinkClock = {
    var quantum, isPlaying;
    if(~linkClock.isNil) {
        ~linkClock = LinkClock.new;
    };

    isPlaying = (~linkClock.tryPerform(\isPlaying) ?? { false });
    if(isPlaying.not) {
        ~linkClock.tryPerform(\play);
    };

    quantum = (~linkClock.tryPerform(\quantum) ?? { 4 });
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~linkClock.quantum = quantum;
};

~stopLinkMeasureSync = {
    if(~linkMeasureRoutine.notNil) {
        ~linkMeasureRoutine.stop;
        ~linkMeasureRoutine = nil;
    };
    if(~linkClockCmdPeriodHandler.notNil) {
        CmdPeriod.remove(~linkClockCmdPeriodHandler);
        ~linkClockCmdPeriodHandler = nil;
    };
};

~startLinkMeasureSync = {
    ~ensureLinkClock.value;

    if(~linkMeasureRoutine.notNil) {
        ~linkMeasureRoutine.stop;
    };

    ~linkMeasureRoutine = Routine({
        var lastMeasure = nil;
        var quantum, beat, measure, linkIsPlaying;
        loop {
            linkIsPlaying = (~linkClock.tryPerform(\isPlaying) ?? { true });
            if(linkIsPlaying) {
                quantum = (~linkClock.tryPerform(\quantum) ?? { 4 }).asInteger.max(1);
                beat = (~linkClock.tryPerform(\beats) ?? { 0 }).asFloat;
                measure = (((beat.floor) % quantum) + 1).clip(1, quantum);
                if(lastMeasure != measure) {
                    ~setRecordMeasure.value(measure);
                    lastMeasure = measure;
                };
            } {
                if(lastMeasure.notNil) {
                    ~setRecordMeasure.value(1);
                    lastMeasure = nil;
                };
            };
            0.05.wait;
        };
    }).play(AppClock);

    if(~linkClockCmdPeriodHandler.isNil) {
        ~linkClockCmdPeriodHandler = { ~stopLinkMeasureSync.value };
        CmdPeriod.add(~linkClockCmdPeriodHandler);
    };
};

~requestRecordAtNextBar = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \idle) {
        ~recordTransportState[\state] = \waiting;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~abletonBridge.tryPerform(\requestRecord);
    };
};

~cancelPendingRecord = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \waiting) {
        ~recordTransportState[\state] = \idle;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~abletonBridge.tryPerform(\cancelRecord);
    };
};

~confirmRecordStart = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] != \recording) {
        ~recordTransportState[\state] = \recording;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
    };
};

~cancelPendingStop = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \stopping) {
        ~recordTransportState[\state] = \recording;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
    };
};

~finalizePendingStop = {
    ~ensureRecordTransport.value;
    ~recordTransportState[\pendingStop] = false;
    ~recordTransportState[\state] = \idle;
    ~notifyRecordTransport.value;
    ~abletonBridge.tryPerform(\stopRecord);
};

~stopRecordTransport = {
    ~ensureRecordTransport.value;
    switch(~recordTransportState[\state],
        \recording, {
            ~recordTransportState[\state] = \stopping;
            ~recordTransportState[\pendingStop] = true;
            ~notifyRecordTransport.value;
        },
        \stopping, {
            // already waiting for the bar to end
        },
        \waiting, {
            ~cancelPendingRecord.value;
        },
        {
            if(~recordTransportState[\state] != \idle) {
                ~recordTransportState[\state] = \idle;
                ~recordTransportState[\pendingStop] = false;
                ~notifyRecordTransport.value;
                ~abletonBridge.tryPerform(\stopRecord);
            };
        }
    );
};

~toggleRecordTransport = {
    ~ensureRecordTransport.value;
    switch(~recordTransportState[\state],
        \idle, { ~requestRecordAtNextBar.value },
        \waiting, { ~cancelPendingRecord.value },
        \recording, { ~stopRecordTransport.value },
        \stopping, { ~cancelPendingStop.value },
        { ~requestRecordAtNextBar.value }
    );
};

// Initialisation
~ensureRecordTransport.value;
~startLinkMeasureSync.value;
