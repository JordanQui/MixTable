// Gestion de l'interface avec Ableton Bridge pour la fonction Record
~abletonBridgeConfig = ~abletonBridgeConfig ?? {
    (
        host: "127.0.0.1",
        sendPort: 9001,
        receivePort: NetAddr.langPort,
        quantum: 4
    )
};

~abletonBridgeSockets = ~abletonBridgeSockets ?? { () };

~configureAbletonBridge = { |config|
    if(config.notNil) {
        if(config.respondsTo(\pairsDo)) {
            config.pairsDo { |key, value|
                ~abletonBridgeConfig[key] = value;
            };
            ~ensureBridgeOsc.tryPerform(\value);
        } {
            if(config.respondsTo(\keysValuesDo)) {
                config.keysValuesDo { |key, value|
                    ~abletonBridgeConfig[key] = value;
                };
                ~ensureBridgeOsc.tryPerform(\value);
            };
        };
    };
};

~ensureAbletonBridgeSocket = { |key = \default|
    var config = ~abletonBridgeConfig;
    var host = config[\host] ?? { "127.0.0.1" };
    var port = config[\sendPort] ?? { 9001 };
    if(~abletonBridgeSockets[key].isNil) {
        ~abletonBridgeSockets[key] = NetAddr(host, port);
    } {
        var socket = ~abletonBridgeSockets[key];
        if(socket.hostname != host or: { socket.port != port }) {
            ~abletonBridgeSockets[key] = NetAddr(host, port);
        };
    };
    ~abletonBridgeSockets[key];
};

~abletonBridgeSend = { |path, ...args|
    var socket = ~ensureAbletonBridgeSocket.value;
    if(socket.notNil) {
        socket.sendMsg(path, *args);
    };
};

~abletonBridgeOscDefs = ~abletonBridgeOscDefs ?? { List.new };
~abletonBridgeCmdPeriodHandler = ~abletonBridgeCmdPeriodHandler ?? { nil };

~freeAbletonBridgeOsc = {
    ~abletonBridgeOscDefs.do(_.free);
    ~abletonBridgeOscDefs.clear;
    if(~abletonBridgeCmdPeriodHandler.notNil) {
        CmdPeriod.remove(~abletonBridgeCmdPeriodHandler);
        ~abletonBridgeCmdPeriodHandler = nil;
    };
    if(~abletonBridgeSockets.notNil) {
        ~abletonBridgeSockets.clear;
    };
};

~handleBridgeMeasure = { |rawMeasure, isAbsolute = true, quantumOverride = nil|
    var quantum = quantumOverride ?? { ~linkClock.tryPerform(\quantum) } ?? { ~abletonBridgeConfig[\quantum] ?? { 4 } };
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~abletonBridgeConfig[\quantum] = quantum;
    var measure;
    if(isAbsolute) {
        measure = ((rawMeasure.asInteger - 1) % quantum) + 1;
    } {
        measure = rawMeasure.asInteger.clip(1, quantum);
    };
    ~setRecordMeasure.value(measure);
};

~handleBridgeRecordState = { |state|
    var symbolState;
    if(state.isNumber) {
        symbolState = case
        { state == 0 } { \idle }
        { state == 1 } { \waiting }
        { state == 2 } { \recording }
        { state == 3 } { \stopping }
        { \idle };
    } {
        symbolState = state.asSymbol;
    };
    switch(symbolState,
        \idle, { ~setRecordState.tryPerform(\value, \idle); },
        \stopped, { ~setRecordState.tryPerform(\value, \idle); },
        \waiting, { ~setRecordState.tryPerform(\value, \waiting); },
        \recording, { ~confirmRecordStart.value; },
        \stopping, {
            ~setRecordState.tryPerform(\value, \stopping);
            if(~recordTransportState.notNil) {
                ~recordTransportState[\pendingStop] = true;
            };
        },
        {
            ("Unknown record state from Ableton Bridge: %".format(state)).warn;
        }
    );
};

~ensureBridgeOsc = {
    var config = ~abletonBridgeConfig;
    var receivePort = config[\receivePort] ?? { NetAddr.langPort };
    if(NetAddr.langPort != receivePort) {
        NetAddr.langPort = receivePort;
    };

    ~freeAbletonBridgeOsc.value;

    ["/mixTable/transport/measure", "/ableton/measure", "/ableton/bar"].do { |path|
        var defName = ("abletonMeasureAbs_%".format(path.copy.replace("/", "_"))).asSymbol;
        ~abletonBridgeOscDefs.add(OSCdef(defName, { |msg|
            if(msg.size > 1) {
                var quantum = if(msg.size > 2) { msg[2] } { nil };
                ~handleBridgeMeasure.value(msg[1], true, quantum);
            };
        }, path));
    };

    ["/mixTable/transport/step", "/ableton/beat"].do { |path|
        var defName = ("abletonMeasureRel_%".format(path.copy.replace("/", "_"))).asSymbol;
        ~abletonBridgeOscDefs.add(OSCdef(defName, { |msg|
            if(msg.size > 1) {
                var quantum = if(msg.size > 2) { msg[2] } { nil };
                ~handleBridgeMeasure.value(msg[1], false, quantum);
            };
        }, path));
    };

    ["/mixTable/transport/recordState", "/ableton/record/state"].do { |path|
        var defName = ("abletonRecordState_%".format(path.copy.replace("/", "_"))).asSymbol;
        ~abletonBridgeOscDefs.add(OSCdef(defName, { |msg|
            if(msg.size > 1) {
                ~handleBridgeRecordState.value(msg[1]);
            };
        }, path));
    };

    if(~abletonBridgeCmdPeriodHandler.isNil) {
        ~abletonBridgeCmdPeriodHandler = {
            ~freeAbletonBridgeOsc.value;
            AppClock.sched(0.1, { ~ensureBridgeOsc.value; nil });
        };
        CmdPeriod.add(~abletonBridgeCmdPeriodHandler);
    };
};

~ensureBridgeOsc.value;

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
    clipped = (((rawMeasure - 1) % 4) + 1).clip(1, 4);
    wrapped = rawMeasure < previousRaw;
    if(previousRaw != rawMeasure) {
        ~recordTransportState[\rawMeasure] = rawMeasure;
    };
    if(~recordTransportState[\measure] != clipped) {
        ~recordTransportState[\measure] = clipped;
        ~notifyRecordTransport.value;
    };
    if((~recordTransportState[\state] == \waiting) and: { wrapped }) {
        ~confirmRecordStart.value;
    };
    if((~recordTransportState[\state] == \stopping) and: { ~recordTransportState[\pendingStop] } and: { wrapped }) {
        ~finalizePendingStop.value;
    };
};

~ensureLinkClock = {
    var quantum;
    if(~linkClock.isNil) {
        var linkClass = Class.find(\LinkClock);
        if(linkClass.notNil) {
            ~linkClock = linkClass.new;
        } {
            ~linkClock = TempoClock.new;
        };
    };

    quantum = (~linkClock.tryPerform(\quantum) ?? { 4 });
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~linkClock.tryPerform(\quantum_, quantum);
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
        ~abletonBridgeSend.value("/mixTable/transport/requestRecord", 1);
    };
};

~cancelPendingRecord = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \waiting) {
        ~recordTransportState[\state] = \idle;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~abletonBridgeSend.value("/mixTable/transport/cancelRecord", 1);
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
    ~abletonBridgeSend.value("/mixTable/transport/stopRecord", 1);
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
                ~abletonBridgeSend.value("/mixTable/transport/stopRecord", 1);
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
