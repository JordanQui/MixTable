// Gestion de l'interface avec Ableton Bridge pour la fonction Record
~ensureRecordTransport = {
    if(~recordTransportState.isNil) {
        ~recordTransportState = (
            state: \idle,
            measure: 1,
            observers: List.new
        );
    };
};

~notifyRecordTransport = {
    ~ensureRecordTransport.value;
    var snapshot = (
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
    ~notifyRecordTransport.value;
};

~setRecordMeasure = { |measure|
    ~ensureRecordTransport.value;
    var clipped = measure.asInteger.clip(1, 4);
    if(~recordTransportState[\measure] != clipped) {
        ~recordTransportState[\measure] = clipped;
        ~notifyRecordTransport.value;
    };
};

~requestRecordAtNextBar = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \idle) {
        ~recordTransportState[\state] = \waiting;
        ~notifyRecordTransport.value;
        ~abletonBridge.tryPerform(\requestRecord);
    };
};

~cancelPendingRecord = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \waiting) {
        ~recordTransportState[\state] = \idle;
        ~notifyRecordTransport.value;
        ~abletonBridge.tryPerform(\cancelRecord);
    };
};

~confirmRecordStart = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] != \recording) {
        ~recordTransportState[\state] = \recording;
        ~notifyRecordTransport.value;
    };
};

~stopRecordTransport = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] != \idle) {
        ~recordTransportState[\state] = \idle;
        ~notifyRecordTransport.value;
        ~abletonBridge.tryPerform(\stopRecord);
    };
};

~toggleRecordTransport = {
    ~ensureRecordTransport.value;
    switch(~recordTransportState[\state],
        \idle, { ~requestRecordAtNextBar.value },
        \waiting, { ~cancelPendingRecord.value },
        \recording, { ~stopRecordTransport.value },
        { ~requestRecordAtNextBar.value }
    );
};

// Initialisation
~ensureRecordTransport.value;
