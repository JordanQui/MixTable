// Gestion de l'interface avec Ableton Bridge pour la fonction Record
~mixTableLog = ~mixTableLog ?? { |tagOrMessage, message = nil ... extra|
    var prefix, runtime, date, timestamp, tag, content;

    prefix = "[MixTable]";
    runtime = if(Main.respondsTo(\elapsedTime)) { Main.elapsedTime } { 0 };

    if(runtime.isNil) {
        runtime = 0;
    };
    date = Date.getDate;
    timestamp = date.tryPerform(\stamp);

    if(timestamp.isNil) {
        timestamp = date.tryPerform(\asString);
    };

    if(timestamp.isNil) {
        timestamp = "";
    };

    if(timestamp.respondsTo(\asString)) {
        timestamp = timestamp.asString;
    };

    if((message.isNil) and: { extra.isEmpty }) {
        tag = nil;
        content = tagOrMessage;
    } {
        tag = tagOrMessage;
        content = [message] ++ extra;
        content = content.select(_.notNil);
        if(content.isEmpty) {
            content = nil;
        } {
            content = content.collect(_.asString).join(" ");
        };
    };

    if(tag.notNil) {
        prefix = prefix ++ " [" ++ tag.asString ++ "]";
    };

    content = (content ?? { "" }).asString;

    (prefix ++ " [" ++ timestamp ++ " @ " ++ runtime.round(0.001).asString ++ "s] " ++ content).postln;
};

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

~abletonBridgeSend = { |path ... args|
    var socket = ~ensureAbletonBridgeSocket.value;
    if(socket.notNil) {
        var payload = args.asArray.collect { |item| item.asString }.join(", ");
        ~mixTableLog.value("AbletonBridge", "Send % [%]".format(path, payload));
        socket.sendMsg(path, *args);
    } {
        ~mixTableLog.value("AbletonBridge", "Send failed % - socket unavailable".format(path));
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
    var normalizedMeasure, absoluteMeasure;
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~abletonBridgeConfig[\quantum] = quantum;

    rawMeasure = rawMeasure.asInteger.max(1);
    if(isAbsolute) {
        absoluteMeasure = rawMeasure;
        normalizedMeasure = (((rawMeasure - 1) % quantum) + 1).clip(1, quantum);
    } {
        var previousRaw = ~recordTransportState.tryPerform(\at, \rawMeasure) ?? { 1 };
        var previousMeasure = (((previousRaw - 1) % quantum) + 1).clip(1, quantum);
        normalizedMeasure = rawMeasure.clip(1, quantum);
        if(normalizedMeasure > previousMeasure) {
            absoluteMeasure = previousRaw + (normalizedMeasure - previousMeasure);
        } {
            absoluteMeasure = previousRaw + ((quantum - previousMeasure) + normalizedMeasure);
        };
    };

    ~setRecordMeasure.value(normalizedMeasure, quantum, absoluteMeasure);
    ~mixTableLog.value("AbletonBridge", "Measure message: raw:% normalized:% absolute:% quantum:% mode:%".format(
        rawMeasure,
        normalizedMeasure,
        absoluteMeasure,
        quantum,
        if(isAbsolute) { "absolute" } { "relative" }
    ));
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
    ~mixTableLog.value("AbletonBridge", "Record state received: %".format(symbolState));
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
        var quantum = (~abletonBridgeConfig[\quantum] ?? { 4 });
        if(quantum.isNumber.not) { quantum = 4; };
        quantum = quantum.asInteger.max(1);
        ~recordTransportState = (
            state: \idle,
            measure: 1,
            rawMeasure: 1,
            quantum: quantum,
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
        measure: ~recordTransportState[\measure],
        quantum: ~recordTransportState[\quantum]
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
            measure: ~recordTransportState[\measure],
            quantum: ~recordTransportState[\quantum]
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
    var previousState, elapsed;
    ~ensureRecordTransport.value;
    previousState = ~recordTransportState[\state] ?? { \idle };
    ~recordTransportState[\state] = newState;
    if(newState != \stopping) {
        ~recordTransportState[\pendingStop] = false;
    };
    ~notifyRecordTransport.value;
    if(previousState != newState) {
        elapsed = Main.elapsedTime ?? { 0 };
        ~mixTableLog.value("Transport", "Record state changed % -> % (elapsed:%s)".format(
            previousState,
            newState,
            elapsed.round(0.001).asString
        ));
    };
    if(newState == \idle) {
        ~stopServerRecording.tryPerform(\value);
    };
};

~setRecordMeasure = { |measure, quantum = nil, rawMeasure = nil|
    var previousRaw, previousMeasure, normalizedMeasure, nextRaw, wrapped;
    ~ensureRecordTransport.value;

    quantum = (quantum ?? { ~recordTransportState[\quantum] } ?? { 4 });
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~recordTransportState[\quantum] = quantum;

    previousRaw = ~recordTransportState[\rawMeasure] ?? { 1 };
    previousMeasure = ~recordTransportState[\measure] ?? { 1 };

    normalizedMeasure = measure.asInteger.clip(1, quantum);

    if(rawMeasure.notNil) {
        nextRaw = rawMeasure.asInteger.max(1);
        wrapped = nextRaw <= previousRaw;
    } {
        if(previousRaw.isNil) {
            nextRaw = normalizedMeasure;
            wrapped = false;
        } {
            if(normalizedMeasure > previousMeasure) {
                nextRaw = previousRaw + (normalizedMeasure - previousMeasure);
                wrapped = false;
            } {
                nextRaw = previousRaw + ((quantum - previousMeasure) + normalizedMeasure);
                wrapped = normalizedMeasure <= previousMeasure;
            };
        };
    };

    if(previousRaw != nextRaw) {
        ~recordTransportState[\rawMeasure] = nextRaw;
    };

    if(~recordTransportState[\measure] != normalizedMeasure) {
        ~recordTransportState[\measure] = normalizedMeasure;
        ~notifyRecordTransport.value;
        ~mixTableLog.value("Transport", "Measure advanced to %/% (raw %).".format(normalizedMeasure, quantum, nextRaw));
    } {
        wrapped = false;
    };

    if((~recordTransportState[\state] == \waiting) and: { wrapped }) {
        ~confirmRecordStart.value;
    };
    if((~recordTransportState[\state] == \stopping) and: { ~recordTransportState[\pendingStop] } and: { wrapped }) {
        ~finalizePendingStop.value;
    };
};

~ensureRecordingDirectory = {
    var dir = Platform.recordingsDir ?? { Platform.userAppSupportDir +/+ "Recordings" };
    dir = dir.asString;
    PathName(dir).mkdir;
    dir;
};

~startServerRecording = {
    var path, dir, timestamp;
    if(s.serverRunning.not) { ^nil };
    if(s.recording) { ^nil };
    dir = ~ensureRecordingDirectory.value;
    timestamp = Date.getDate.stamp;
    if(timestamp.respondsTo(\replace)) {
        timestamp = timestamp.replace($:, $-);
    };
    path = dir +/+ ("MixTable_" ++ timestamp ++ ".wav");
    s.prepareForRecord(path);
    s.record(path);
    ~currentRecordingPath = path;
};

~stopServerRecording = {
    if(s.recording) {
        s.stopRecording;
    };
};

~ensureLinkClock = {
    var quantum;
    if(~linkClock.isNil) {
        var linkClass = \LinkClock.asClass;
        if(linkClass.notNil) {
            ~linkClock = linkClass.new;
            ~mixTableLog.value("LinkClock", "LinkClock instance created.");
        } {
            ~linkClock = TempoClock.new;
            ~mixTableLog.value("LinkClock", "TempoClock fallback created (LinkClock unavailable).");
        };
    };

    quantum = (~linkClock.tryPerform(\quantum) ?? { 4 });
    if(quantum.isNumber.not) { quantum = 4; };
    quantum = quantum.asInteger.max(1);
    ~linkClock.tryPerform(\quantum_, quantum);

    if((~linkClock.tryPerform(\isPlaying) ?? { false }).not) {
        ~mixTableLog.value("LinkClock", "Clock was stopped - starting playback.");
        ~linkClock.tryPerform(\play);
    };

    ~mixTableLog.value("LinkClock", "Clock ready - tempo:% bpm quantum:% playing:%".format(
        (~linkClock.tryPerform(\tempo) ?? { 0 }).round(0.01),
        quantum,
        (~linkClock.tryPerform(\isPlaying) ?? { false })
    ));
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

    ~mixTableLog.value("LinkClock", "Starting measure sync routine.");

    ~linkMeasureRoutine = Routine({
        var lastMeasure = nil;
        var lastQuantum = nil;
        var lastPlayingState = nil;
        var quantum, beat, measure, linkIsPlaying, tempo, beatDur, elapsed;
        loop {
            linkIsPlaying = (~linkClock.tryPerform(\isPlaying) ?? { true });
            if(linkIsPlaying != lastPlayingState) {
                tempo = (~linkClock.tryPerform(\tempo) ?? { 0 }).round(0.01);
                elapsed = Main.elapsedTime ?? { 0 };
                ~mixTableLog.value("LinkClock", "Playing state changed: % (tempo:% bpm, elapsed:%s)".format(
                    linkIsPlaying,
                    tempo,
                    elapsed.round(0.001).asString
                ));
                lastPlayingState = linkIsPlaying;
            };
            if(linkIsPlaying) {
                quantum = (~linkClock.tryPerform(\quantum) ?? { 4 }).asInteger.max(1);
                beat = (~linkClock.tryPerform(\beats) ?? { 0 }).asFloat;
                measure = (((beat.floor) % quantum) + 1).clip(1, quantum);
                if((lastMeasure != measure) or: { lastQuantum != quantum }) {
                    ~setRecordMeasure.value(measure, quantum);
                    lastMeasure = measure;
                    lastQuantum = quantum;
                    tempo = (~linkClock.tryPerform(\tempo) ?? { 0 }).round(0.01);
                    beatDur = (~linkClock.tryPerform(\beatDur) ?? { 0 }).round(0.001);
                    elapsed = Main.elapsedTime ?? { 0 };
                    ~mixTableLog.value("LinkClock", "Beat update - beat:% measure:%/% tempo:% bpm beatDur:%s elapsed:%s".format(
                        beat.round(0.001),
                        measure,
                        quantum,
                        tempo,
                        beatDur.asString,
                        elapsed.round(0.001).asString
                    ));
                };
            } {
                if(lastMeasure.notNil) {
                    var currentQuantum = (~recordTransportState.tryPerform(\at, \quantum) ?? { quantum ?? { 4 } });
                    if(currentQuantum.isNumber.not) { currentQuantum = 4; };
                    currentQuantum = currentQuantum.asInteger.max(1);
                    ~setRecordMeasure.value(1, currentQuantum);
                    lastMeasure = nil;
                    lastQuantum = currentQuantum;
                    elapsed = Main.elapsedTime ?? { 0 };
                    ~mixTableLog.value("LinkClock", "Link stopped - reset measure to 1/% (elapsed:%s)".format(
                        currentQuantum,
                        elapsed.round(0.001).asString
                    ));
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
        ~mixTableLog.value("Transport", "Record requested for next bar.");
    };
};

~cancelPendingRecord = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \waiting) {
        ~recordTransportState[\state] = \idle;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~abletonBridgeSend.value("/mixTable/transport/cancelRecord", 1);
        ~mixTableLog.value("Transport", "Record request cancelled.");
    };
};

~confirmRecordStart = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] != \recording) {
        ~recordTransportState[\state] = \recording;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~startServerRecording.tryPerform(\value);
        ~mixTableLog.value("Transport", "Recording confirmed at measure %/%".format(
            ~recordTransportState[\measure] ?? { 1 },
            ~recordTransportState[\quantum] ?? { 4 }
        ));
    };
};

~cancelPendingStop = {
    ~ensureRecordTransport.value;
    if(~recordTransportState[\state] == \stopping) {
        ~recordTransportState[\state] = \recording;
        ~recordTransportState[\pendingStop] = false;
        ~notifyRecordTransport.value;
        ~mixTableLog.value("Transport", "Pending stop cancelled.");
    };
};

~finalizePendingStop = {
    ~ensureRecordTransport.value;
    ~recordTransportState[\pendingStop] = false;
    ~recordTransportState[\state] = \idle;
    ~notifyRecordTransport.value;
    ~stopServerRecording.tryPerform(\value);
    ~abletonBridgeSend.value("/mixTable/transport/stopRecord", 1);
    ~mixTableLog.value("Transport", "Recording stopped at wrap.");
};

~stopRecordTransport = {
    ~ensureRecordTransport.value;
    switch(~recordTransportState[\state],
        \recording, {
            ~recordTransportState[\state] = \stopping;
            ~recordTransportState[\pendingStop] = true;
            ~notifyRecordTransport.value;
            ~mixTableLog.value("Transport", "Stop requested at next bar.");
        },
        \stopping, {
            // already waiting for the bar to end
            ~mixTableLog.value("Transport", "Stop already pending.");
        },
        \waiting, {
            ~cancelPendingRecord.value;
        },
        {
            if(~recordTransportState[\state] != \idle) {
                ~recordTransportState[\state] = \idle;
                ~recordTransportState[\pendingStop] = false;
                ~notifyRecordTransport.value;
                ~stopServerRecording.tryPerform(\value);
                ~abletonBridgeSend.value("/mixTable/transport/stopRecord", 1);
                ~mixTableLog.value("Transport", "Immediate stop executed.");
            };
        }
    );
};

~toggleRecordTransport = {
    ~ensureRecordTransport.value;
    ~mixTableLog.value("Transport", "Toggle requested from state %".format(~recordTransportState[\state] ?? { \idle }));
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
