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
        observer.(
            state: ~recordTransportState[\state],
            measure: ~recordTransportState[\measure]
        );
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
