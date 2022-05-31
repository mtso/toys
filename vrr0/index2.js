// for i in 0 1 2
// do
//   node index.js --replica=0 --addresses=0.0.0.0:3000,0.0.0.0:3001 &
//   # need to handle PID somehow
// done
//
// Or with automatic kill control:
//     concurrently --kill-others-on-fail \
//         \"node index.js --replica=0 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica0\" \
//         \"node index.js --replica=1 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica1\" \
//         \"node index.js --replica=2 --addresses=0.0.0.0:4000,0.0.0.0:4001,0.0.0.0:4002 --directory=data/replica2\"
//

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
        if (!this.socket || this.socket.destroyed) {
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
            this.socket.on("data", (data) => {
                // Unexpected for send socket to receive data. Replicas
                // are expected to send via their send sockets
                // and received on this server via the receive socket.
                console.warn("send socket data", data.toString());
            });
            this.socket.on("end", () => {
                this.socket.destroy();
                this.socket = null;
            });
        }
    }

    isConnected() {
        // this.socket.readyState in ["open", "writeOnly"]; <- not useful
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
        console.log("flush sendQueue:", this.sendQueue.length, "flushing:", this.flushing);
        if (this.flushing) return;

        this.flushing = true;
        while (this.sendQueue.length > 0) {
            if (!this.socket || this.socket.destroyed) {
                break;
            }

            let message = this.sendQueue.shift();
            if (typeof message !== "string") {
                message = JSON.stringify(message);
            }
            this.socket.write(message);
        }
        this.flushing = false;
    }
}

class MessageHub extends EventEmitter {
    constructor(serverAddress, peerAddresses) {
        super();
        this.serverAddress = serverAddress;
        this.peerConnections = peerAddresses.map((a) => new Connection(a));
    }

    initServer() {
        this.server = net.createServer();
        this.server.on("connection", (socket) => {
            console.log("got connection");
            socket.on("data", (data) => {
                console.log("receive socket data", data.toString());
                // TODO: handle data as message

                try {
                    // {
                    //   "event": "prepare",
                    //   ... other data fields
                    // }
                    const dataString = data.toString().trim();
                    const message = JSON.parse(dataString);
                    if (!message.event) {
                        console.warn("incoming message is missing 'event'", message);
                    } else {
                        this.emit(message.event, message);
                    }
                } catch (err) {
                    console.error("failed to parse message: ", data.toString().trim());
                }
            });
            socket.on("error", (err) => {
                console.error("receive socket error", err);
                socket.destroy();
            });
            socket.on("close", () => {
                console.log("receive socket closed");
                socket.destroy();
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
    constructor(hub, replica, directory) {
        this.hub = hub;
        this.replica = replica;
        this.directory = directory;

        this.hub.on("request", (event) => {
            console.log("request message:", event.message);
            this.appendLog(event.message);
            this.hub.publish({
                "event": "propagate",
                "message": event.message,
                "source": this.replica,
            });
        });

        this.hub.on("propagate", (event) => {
            console.log("propagating", event.message, event.source);
            this.appendLog(event.message);
        });
    }

    appendLog(message) {
        if (typeof message !== "string") {
            message = JSON.stringify(message);
        }
        const filename = path.join(this.directory, "tmp");
        fs.appendFileSync(filename, message.trim() + "\n");
    }
}

const config = parseOpts(process.argv);
console.log(config);

const address = config.addresses[config.replica];
const peerAddresses = config.addresses.filter((a) => a !== address);
const hub = new MessageHub(address, peerAddresses);
const replica = new Replica(hub, config.replica, config.directory);

hub.initServer();
