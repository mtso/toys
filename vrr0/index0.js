// for i in 3
//   node index.js --replica=0 --addresses=0.0.0.0:3000,0.0.0.0:3001
//

const net = require("net");

class MessageHub {
    constructor(address, addresses) {
        this.clientConnections = [];

        addresses.forEach((address) => {
            const [host, port] = address.split(":");
            let client = net.createConnection({ host, port });
            client.on("data", (data) => {

            });
            client.on("connect", () => {

            });
            client.on("error", (e) => {
                console.log("encountered client error", e);
                setTimeout(() => {
                    client = net.createConnection({ host, port });
                }, 1000);
            });
        });
    }

    initClient(address) {
        const [host, port] = address.split(":");
        let client = net.createConnection({ host, port });
        client.on("data", (data) => {

        });
        client.on("connect", () => {

        });
        client.on("error", (e) => {
            console.log("encountered client error", e);
            client.end();
            setTimeout(() => this.initClient(address), 1000);
        });
    }

    init() {
        if (!!this.server) {
            return;
        }
        this.server = net.createServer();
        this.server.on("connection", (socket) => {
            console.log("got connection", socket);
        });
    }

    emit(event, data) {
        const message = createMessage(event, data);
        // for each peer, send data
        this.clientConnections.forEach((client) => {
            if (client.readyState in ["open", "writeOnly"]) {
                client.write(message);
            }
        })
    }
}

class Peer {
    constructor(address) {

    }

    init() {
        const socket = net.connect(this.address);
        socket.on("close", () => {

        });
        socket.on("connect", (connection) => {

        });
        socket.on("data", () => {

        });
        socket.on("end", () => {

        });
        socket.on("error", () => {

        });
        socket.on("ready", () => {

        });
    }
}

class Replica {
    constructor(n, addresses, messageHub) {
        this.messageHub.on("prepareOk", (data) => {
            this.processPrepareOk(data);
        })
        this.messageHub.emit("prepareOk", { id, whatever });
    }

    serve() {
        this.peers = this.addresses.map((address) => new Peer(address));
        this.peers.forEach((p) => p.init());
    }
}

const replica = new Replica(n, addresses);


replica.serve();
