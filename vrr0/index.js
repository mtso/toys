// INFO
// ====
// This implements viewstamped replication over an append-only log.
//
// TEST
// ====
//
// 0. Clean cluster data
//     rm -r ./data/*
//
// 1. Start cluster
//     concurrently \
//         \"node index.js --replica=0 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica0\" \
//         \"node index.js --replica=1 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica1\" \
//         \"node index.js --replica=2 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica2\"
//
// 2. Send messages as client
//     nc 0.0.0.0 4000
//     > {"event":"request","clientId":1,"message":"hi","requestNumber":0}
//       {"ok":1,"op":2,"view":0,"requestNumber":0}
//     > {"event":"request","clientId":1,"message":"hello, world","requestNumber":1}
//       {"ok":1,"op":2,"view":0,"requestNumber":1}
//     > {"event":"request","clientId":1,"message":"hello, world!!!","requestNumber":2}
//       {"ok":1,"op":2,"view":0,"requestNumber":2}
//     > {"event":"request","clientId":1,"message":"HELLO, WORLD!!!!!~~","requestNumber":3}
//       {"ok":1,"op":2,"view":0,"requestNumber":3}
//

/**
 * 
 * MESSAGES
 * ========
 * Stat Request
 * { "event": "stat",
 *   "clientId": <int>}
 * e.g. response: {"replica":0,"view":0,"status":"normal","op":2,"commit":2,"primary":0}
 *
 * Client Request
 * { "event": "request",
 *   "clientId": <int>,
 *   "requestNumber": <int>,
 *   "message": <string> }
 * e.g. request: {"event":"request","clientId":1,"message":"hello, world!","requestNumber":0}
 *
 * Prepare
 * { "event": "prepare",
 *   "view": <int> }
 */


const fs = require("fs");
const path = require("path");
const net = require("net");
const EventEmitter = require('events');

function parseOpts(args) {
    let replica = null;
    let addresses = [];
    let directory = null;
    args.forEach((arg) => {
        if (arg.startsWith("--replica")) {
            replica = +arg.replace("--replica=", "");
        }
        if (arg.startsWith("--addresses")) {
            addresses = arg.replace("--addresses=", "").split(",");
        }
        if (arg.startsWith("--directory")) {
            directory = path.resolve(arg.replace("--directory=", ""));
        }
    });
    if (replica === null) {
        console.error("Missing --replica");
        process.exit(1);
    }
    if (addresses.length < 1) {
        console.error("Missing --addresses");
        process.exit(1);
    }
    if (replica >= addresses.length) {
        console.error("Replica greater than available addresses");
        process.exit(1);
    }
    if (!directory) {
        console.error("Missing --directory");
        process.exit(1);
    }
    ensureDir(directory);
    return { replica, addresses, directory };
}

function ensureDir(dirname) {
    try {
        const info = fs.statSync(dirname);
        if (!info.isDirectory()) {
            console.error("specified path is not a directory", info);
            process.exit(1);
        }
    } catch (err) {
        console.warn("failed to stat, attempting to create directory...", dirname);
        try {
            fs.mkdirSync(dirname);
            console.log("created directory", dirname);
        } catch (err) {
            console.error("failed to create directory");
            process.exit(1);
        }
    }
}

class Connection {
    constructor(address) {
        this.address = address;
        this.socket = null;
        this.sendQueue = [];
        this.flushing = false;
    }

    ensureConnection() {
        if (!this.isConnected()) {
            const [host, port] = this.address.split(":");
            this.socket = net.createConnection({ host, port });
            this.socket.on("connect", () => {
                console.log("send socket connect");
                this.flush();
            });
            this.socket.on("error", (err) => {
                console.log("send socket error", err);
                this.socket.destroy();
                this.socket = null;
            });
            this.socket.on("end", () => {
                this.socket.destroy();
                this.socket = null;
            });
            this.socket.on("data", (data) => {
                // Unexpected for send socket to receive data. Replicas
                // are expected to send via their send sockets
                // and received on this server via the receive socket.
                console.error("unexpected send socket received data!", data.toString());
            });
        }
    }

    isConnected() {
        return this.socket && !this.socket.destroyed;
    }

    send(message) {
        this.sendQueue.push(message);
        if (!this.isConnected()) {
            this.ensureConnection();
        } else {
            this.flush();
        }
    }

    flush() {
        if (this.flushing) return;

        this.flushing = true;
        while (this.sendQueue.length > 0) {
            if (!this.isConnected()) {
                this.flushing = false;
                return this.ensureConnection();
            }

            let message = this.sendQueue.shift();
            if (typeof message !== "string") {
                message = JSON.stringify(message);
            }
            this.socket.write(message);
            // setTimeout(() => this.socket.write(message), 50);
            // setImmediate(() => this.socket.write(message));
        }
        this.flushing = false;
    }
}

class MessageHub extends EventEmitter {
    constructor(serverAddress, peerAddresses) {
        super();
        this.serverAddress = serverAddress;
        this.peerConnections = peerAddresses.map((a) => new Connection(a));
        this.clientConnections = [];
    }

    addClient(clientConnection) {
        const { clientId } = clientConnection;
        const existing = this.clientConnections.find((c) => c.clientId === clientId);
        if (existing && existing.socket !== clientConnection.socket) {
            console.warn("existing client connection found where socket is different! overwriting with newer one");
            this.clientConnections = this.clientConnections.filter((c) => c.clientId !== clientId);
            this.clientConnections.push(clientConnection);
        } else if (!existing) {
            this.clientConnections.push(clientConnection);
        } else {
            console.log("new request with existing client, skipping...");
        }
    }

    sendToClient(clientId, message) {
        if (typeof message !== "string") {
            message = JSON.stringify(message);
        }
        const connection = this.clientConnections.find((c) => c.clientId === clientId);
        if (!connection || connection.socket.destroyed) {
            console.error("client connection invalid!! clientId:", clientId);
        } else {
            console.log("writing message back to clientId", clientId, message);
            const socket = connection.socket;
            socket.write(message + "\n");
        }
    }

    closeConnection(connectionId) {
        const connection = this.clientConnections.find((c) => c.connectionId === connectionId);
        if (connection) {
            console.log("closing connection", connectionId);
            this.clientConnections = this.clientConnections.filter((c) => c.connectionId !== connectionId);
            const socket = connection.socket;
            socket.destroy();
        }
    }

    initServer() {
        this.server = net.createServer();
        this.server.on("connection", (socket) => {
            const connectionId = Math.random().toString().substring(2);
            console.log("got connection", connectionId);
            socket.on("data", (buffer) => {
                // Handle buffer that contains two JSON string-encoded messages
                // with "}{" joiner heuristic.
                const dataRaw = buffer.toString().split("}{");
                const dataStrings = dataRaw.map((m, i) => {
                    if (i < dataRaw.length - 1) m = m + "}";
                    if (i > 0) m = "{" + m;
                    return m;
                });

                dataStrings.forEach((dataString) => {
                    let message;
                    try {
                        message = JSON.parse(dataString.trim());
                    } catch (err) {
                        return console.error("failed to parse message:", JSON.stringify(dataString), err);
                    }

                    if (!message.event) {
                        return console.warn("incoming message is missing 'event'", message);
                    }

                    // We can add a client connection on their
                    // request if it contains a client ID.
                    if (message.clientId) {
                        this.addClient({
                            connectionId,
                            socket,
                            clientId: message.clientId,
                        });
                    }

                    try {
                        this.emit(message.event, message);
                    } catch (err) {
                        console.error("message handling error", err);
                    }
                });
            });
            socket.on("error", (err) => {
                console.error("receive socket error", err);
                this.closeConnection(connectionId);
            });
            socket.on("close", () => {
                console.log("receive socket closed");
                this.closeConnection(connectionId);
            });
        });
        this.server.on("error", (err) => {
            console.log("server error", err);
            setTimeout(() => this.initServer(), 100);
        });

        const port = this.serverAddress.split(":")[1];
        this.server.listen(port, () => {
            console.log("server listening on", port);
        });
    }

    publish(message) {
        this.peerConnections.forEach((connection) => {
            connection.send(message);
        });
    }
}

class Replica {
    constructor(hub, replica, directory, replicaCount) {
        this.hub = hub;
        this.replica = replica;
        this.directory = directory;
        this.requests = [];
        this.replicaCount = replicaCount;
        this.f = Math.ceil((replicaCount - 1) / 2);

        this.view = 0;
        this.status = "normal"; // "view_change", "recovering"
        this.viewLastNormal = this.view;
        this.op = 0;
        this.commit = 0;
        this.primary = 0;
        this.prepareOkReceived = {};
        this.commitQueue = {};

        this.clientTable = {};
        this.opToClientId = {};

        this.startViewChangeCount = {};
        this.doViewChangeCount = {};
        this.doViewChangeInfo = {};

        this.hub.on("stat", (event) => {
            this.hub.sendToClient(event.clientId, {
                replica: this.replica,
                // directory: this.directory,
                // requestCount: this.requests.length,
                view: this.view,
                status: this.status,
                op: this.op,
                commit: this.commit,
                primary: this.primary,
                clientTable: this.clientTable,
            });
        });

        this.hub.on("request", (event) => {
            if (!this.isPrimary()) {
                return console.warn("request received into backup, dropping...", event);
            }
            const { clientId, message, requestNumber } = event;
            const existingRequestNumber = this.getClientTableRequestNumber(event.clientId);
            if (existingRequestNumber === requestNumber) {
                return this.hub.sendToClient(clientId, this.getClientTableResponse(clientId));
            } else if (requestNumber < existingRequestNumber) {
                return console.warn("Invalid request number, dropping request...", "requestNumber=" + requestNumber, "existing=" + existingRequestNumber);
            }

            this.op += 1;
            this.clientTable[clientId] = this.clientTable[clientId] || { requestNumber: -1, response: { "error": "notInitialized" } };
            this.clientTable[clientId].requestNumber = requestNumber;
            this.opToClientId[this.op] = clientId;
            this.appendLog(this.op, message);

            console.log("publishing prepare");
            this.hub.publish({
                "event": "prepare",
                "view": this.view,
                "message": message,
                "messageFull": event,
                "op": this.op,
                "commit": this.commit,
            });
        });

        this.hub.on("prepare", (event) => {
            console.log("handling prepare");
            const { op, view, message, messageFull } = event;
            const { clientId, requestNumber } = messageFull;
            if (op - this.op !== 1) {
                // TODO do state transfer if needed.
                console.warn("missing previous ops, dropping prepare", "op=" + this.op, "prepareOp=" + op);
                return;
            }

            // Execute step 4 of "Normal Operation"!
            this.op += 1;
            if (this.op !== op) console.error("UNEXPECTED op increment to mismatch prepare!!", "op=" + this.op, "prepareOp=" + op);
            this.appendLog(this.op, message);
            this.clientTable[clientId] = this.clientTable[clientId] || { requestNumber: -1, response: { "error": "notInitialized" } };
            this.clientTable[clientId].requestNumber = requestNumber;

            this.hub.publish({
                "event": "prepare_ok",
                "view": this.view,       // v
                "op": this.op,           // n
                "replica": this.replica, // i
            });
        });

        this.hub.on("prepare_ok", (event) => {
            if (!this.isPrimary()) return;
            console.log("handling prepare_ok", event);

            const { op, replica } = event;
            if (this.commit >= op) {
                console.log("received prepare_ok for op number that was already committed, skipping...", "commit=" + this.commit, "prepareOkOp=" + op);
                return;
            }

            this.prepareOkReceived[op] = this.prepareOkReceived[op] || 0;
            this.prepareOkReceived[op] = this.prepareOkReceived[op] | (0x1 << replica);

            console.log("prepareOkRecv", "prepareOkOp=" + op, this.bitsOn(this.prepareOkReceived[op]), this.prepareOkReceived);

            if (this.bitsOn(this.prepareOkReceived[op]) >= this.f) {
                // operation is now considered committed
                // TODO: distinguish up-call from appendLog
                // commit number can now be incremented
                this.commitQueue[op] = true;
                this.attemptCommit(op);
            }
        });

        this.hub.on("commit", (event) => {
            if (event.replica !== this.primary) {
                console.warn("commit asked for from replica that's not the current leader! skipping...", event);
                return;
            }

            this.commitQueue[event.commit] = true;
            this.attemptCommitBackup(event.commit);
        });

        this.hub.on("triggerStartViewChange", (event) => {
            const { view, replica } = event;
            this.view += 1;
            this.status = "view_change";
            this.hub.publish({
                "event": "startViewChange",
                "view": this.view,       // v
                "replica": this.replica, // i
            });
        });

        this.hub.on("startViewChange", (event) => {
            console.log("received startViewChange", JSON.stringify(event));
            const { view, replica } = event;

            if (view > this.view) {
                // noticed view change needed!
                this.view += 1;
                this.status = "view_change";
                this.hub.publish({
                    "event": "startViewChange",
                    "view": this.view,       // v
                    "replica": this.replica, // i
                });
            } else if (view === this.view) {
                this.startViewChangeCount[view] = this.startViewChangeCount[view] || 0;
                this.startViewChangeCount[view] = this.startViewChangeCount[view] | (0x1 << replica);

                if (this.bitsOn(this.startViewChangeCount[view]) >= this.f) {
                    const nextPrimary = (this.primary + 1) % this.replicaCount;
                    const doViewChangeEvent = {
                        "event": "doViewChange",
                        "nextPrimary": nextPrimary,
                        "view": this.view,                     // v
                        "viewLastNormal": this.viewLastNormal, // v'
                        "op": this.op,                         // n
                        "commit": this.commit,                 // k
                        "log": this.getLogEntries(),           // l
                        "replica": this.replica,
                    };
                    this.hub.publish(doViewChangeEvent);
                    // Immediately inform this replica of doViewChange.
                    if (nextPrimary === this.replica) {
                        this.doViewChangeCount[this.view] = this.doViewChangeCount[this.view] || 0;
                        this.doViewChangeCount[this.view] = this.doViewChangeCount[this.view] | (0x1 << this.replica);
                        this.doViewChangeInfo[this.view] = this.doViewChangeInfo[this.view] || [];
                        this.doViewChangeInfo[this.view] = this.doViewChangeInfo[this.view].filter((i) => i.replica !== this.replica);
                        this.doViewChangeInfo[this.view].push(doViewChangeEvent);
                    }
                }

            } else {
                console.log("received startViewChange for lower view number!", "view=" + this.view, "startView=" + view);
            }
        });

        this.hub.on("doViewChange", (event) => {
            if (this.replica !== event.nextPrimary) return;

            const { view, replica, nextPrimary } = event;

            if (this.view > view) {
                return console.log("skipping doViewChange event", "view=" + this.view, "newView=" + view0);
            }

            if (view > this.view) {
                // noticed view change needed!
                console.log("noticed doViewChange before startViewChange", "view=" + this.view, "newView=" + view, "replica=" + this.replica);
                this.view += 1;
                this.status = "view_change";
                this.hub.publish({
                    "event": "startViewChange",
                    "view": this.view,       // v
                    "replica": this.replica, // i
                });
            }

            this.doViewChangeCount[view] = this.doViewChangeCount[view] || 0;
            this.doViewChangeCount[view] = this.doViewChangeCount[view] | (0x1 << replica);
            this.doViewChangeInfo[view] = this.doViewChangeInfo[view] || [];
            this.doViewChangeInfo[view] = this.doViewChangeInfo[view].filter((i) => i.replica !== replica);
            this.doViewChangeInfo[view].push(event);

            // Execute Step 3 of "View Change"!
            if (this.bitsOn(this.doViewChangeCount[view]) >= this.f + 1 && this.status === "view_change") {
                console.log("handling doViewChange", "view=" + this.view, "replica=" + this.replica);
                this.view = view;
                const best = this.getBestInfo(this.doViewChangeInfo[view]);
                // console.log("getBestInfo", this.doViewChangeInfo[view], best);
                this.op = this.repairLog(best.log);
                const maxCommit = this.doViewChangeInfo[view].map((info) => info.commit)
                  .reduce((a, b) => Math.max(a, b), -1);
                this.commit = maxCommit;
                this.status = "normal";
                this.primary = this.replica;
                this.hub.publish({
                    "event": "startView",
                    "view": this.view,           // v
                    "log": this.getLogEntries(), // l
                    "op": this.op,               // n
                    "commit": this.commit,       // k
                    "replica": this.replica,
                });
                // TODO: Step 4 of "View Change!"
                // perhaps distinguish appendLog from up-calls
            }
        });

        this.hub.on("startView", (event) => {
            if (this.status === "view_change" && event.view >= this.view) {
                // "View Change" Step 5
                const { log, view, replica } = event;
                this.op = this.repairLog(log);
                this.view = view;
                this.status = "normal";
                this.primary = replica;
                // TODO how to update client table?
                // TODO send prepareOks to the new primary for any non-committed transactions.
            }
        });
    }

    repairLog(newLog) {
        const oldLog = this.getLogEntries();
        const lastOp = (oldLog[oldLog.length - 1] || {}).op;
        const newEntries = lastOp ? newLog.filter((entry) => entry.op > lastOp) : [];
        console.log("repairLog entries", "count=" + newEntries.length);
        newEntries.forEach((newEntry) => {
            console.log("repairLog newEntry", "op=" + newEntry.op);
            this.appendLog(newEntry.op, newEntry.message);
        });
        return newEntries.length > 0 ? newEntries[newEntries.length - 1].op : (lastOp || this.op);
    }

    // "View Change" Step 3
    // "...selects as the new log the one contained in the message with the
    // largest v'; if several messages have the same v' it selects the one
    // among them with the largest n."
    // (v' is the largest view where the state was normal, n is op-number)
    getBestInfo(doViewChangeInfoList) {
        const largestViewLastNormal = doViewChangeInfoList
                                        .map((i) => i.viewLastNormal)
                                        .reduce((a, b) => Math.max(a, b), -1);
        const largestInfos = doViewChangeInfoList.filter((info) => info.viewLastNormal === largestViewLastNormal);
        if (largestInfos.length === 1) {
            return largestInfos[0];
        }
        // If there is more than one infos with the largest normal-state view,
        // then use the largest op to determine.
        const largestOp = largestInfos
            .map((i) => i.op)
            .reduce((a, b) => Math.max(a, b), -1);
        const largestOpInfos = largestInfos.filter((info) => info.op === largestOp);
        // Return the first no matter one or more.
        return largestOpInfos[0];
    }

    attemptCommit(op) {
        console.log("attemptCommit", "prepareOkOp=" + op);
        if (this.commit >= op) return;

        const opsToCommit = this.inclusiveRange(this.commit + 1, op);
        const actuallyCommitted = [];

        for (let i = 0; i < opsToCommit.length; i++) {
            const toCommitOp = opsToCommit[i];
            if (!this.commitQueue[toCommitOp]) {
                console.log("attemptCommit failed, waiting for other ops to complete...",
                    "commit=" + this.commit,
                    "prepareOkOp=" + op,
                    "toCommitOps=" + JSON.stringify(opsToCommit),
                    "commitQueue=" + JSON.stringify(opsToCommit.map((i) => this.commitQueue[i])));
                return;
            }

            // EXECUTE SERVICE UP-CALL AND COMMIT
            // TODO up-call to service code that's different from appendLog
            if (this.commit + 1 !== toCommitOp) {
                console.error("UNEXPECTED attemptCommit", "toCommitOp=" + toCommitOp, "commit=" + this.commit);
            }
            this.commit = toCommitOp;
            actuallyCommitted.push(toCommitOp);

            // Send request back!
            const clientId = this.opToClientId[toCommitOp];
            if (!clientId) {
                return console.error("UNEXPECTED missing client ID", "toCommitOp=" + toCommitOp);
            }
            if (!this.clientTable[clientId]) {
                return console.error("UNEXPECTED client table missing client ID", "toCommitOp=" + toCommitOp, "clientId=" + clientId);
            }
            const { requestNumber } = this.clientTable[clientId];
            const response = {
                "ok": 1,                        // x
                "view": this.view,              // v
                "requestNumber": requestNumber, // s
                "op": toCommitOp,
            };

            this.clientTable[clientId].response = response;
            this.hub.sendToClient(clientId, response);

            // Send commit!
            // TODO: make this optional (if it is send in the next prepare)
            this.hub.publish({
                "event": "commit",
                "view": this.view,     // v
                "commit": this.commit, // k
                "replica": this.replica,
            });
        }

        // Remove actually-committed ops from commitQueue.
        actuallyCommitted.forEach((op) => {
            delete this.commitQueue[op];
        });
        console.log("flushed commitQueue", "committed=" + JSON.stringify(actuallyCommitted));
    }

    attemptCommitBackup(op) {
        console.log("attemptCommitBackup", "commit=" + op);
        if (this.commit >= op) return;

        const opsToCommit = this.inclusiveRange(this.commit + 1, op);
        const actuallyCommitted = [];

        for (let i = 0; i < opsToCommit.length; i++) {
            const toCommitOp = opsToCommit[i];
            if (!this.commitQueue[toCommitOp]) {
                console.log("attemptCommitBackup failed, waiting for other ops to complete...",
                    "commit=" + this.commit,
                    "prepareOkOp=" + op,
                    "toCommitOps=" + JSON.stringify(opsToCommit),
                    "commitQueue=" + JSON.stringify(opsToCommit.map((i) => this.commitQueue[i])));
                return;
            }

            // EXECUTE SERVICE UP-CALL AND COMMIT
            // TODO up-call to service code that's different from appendLog
            if (this.commit + 1 !== toCommitOp) {
                console.error("UNEXPECTED attemptCommitBackup", "toCommitOp=" + toCommitOp, "commit=" + this.commit);
            }
            this.commit = toCommitOp;
            actuallyCommitted.push(toCommitOp);
        }

        // Remove actually-committed ops from commitQueue.
        actuallyCommitted.forEach((op) => {
            delete this.commitQueue[op];
        });
        console.log("flushed commitQueue", "committed=" + JSON.stringify(actuallyCommitted));
    }

    inclusiveRange(from, to) {
        return Array(from - to + 1).fill(0).map((_, i) => from + i);
    }

    bitsOn(mask) {
        let on = 0;
        for (let i = 0; i < 32; i++) {
            if ((mask & (0x1 << i)) > 0) {
                on += 1;
            }
        }
        return on;
    }

    isPrimary() {
        return this.primary === this.replica;
    }

    serve() {
        this.hub.initServer();
    }

    appendLog(op, message) {
        if (typeof message !== "string") {
            message = JSON.stringify(message);
        }
        const filename = path.join(this.directory, "tmp");
        fs.appendFileSync(filename, op + "," + JSON.stringify(message.trim()) + "\n");
    }

    getLogEntries() {
        const filename = path.join(this.directory, "tmp");
        try {
            const contents = fs.readFileSync(filename).toString();
            const log = contents.split("\n").filter((l) => l !== "").map((l) => {
                const firstComma = l.indexOf(",");
                return {
                    op: +l.substring(0, firstComma),
                    message: l.substring(firstComma + 1),
                };
            });
            return log;
        } catch (err) {
            if (err.code !== "ENOENT") { // file does not exist yet.
                console.error("UNEXPECTED getLogEntries", err);
            }
            return [];
        }
    }

    getClientTableRequestNumber(clientId) {
        let requestNumber = -1;
        if (this.clientTable[clientId]) {
            requestNumber = this.clientTable[clientId].requestNumber;
        }
        return requestNumber;
    }

    getClientTableResponse(clientId) {
        if (!this.clientTable[clientId]) {
            console.error("attempted to get response for missing client entry", clientId);
            return { "error": "invalidClientId" };
        }
        return this.clientTable[clientId].response;
    }
}

const config = parseOpts(process.argv);
console.log(config);

const address = config.addresses[config.replica];
const peerAddresses = config.addresses.filter((a) => a !== address);
const hub = new MessageHub(address, peerAddresses);
const replica = new Replica(hub, config.replica, config.directory, config.addresses.length);

replica.serve();
