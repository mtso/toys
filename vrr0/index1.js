// for i in 3
//   node index.js --replica=0 --addresses=0.0.0.0:3000,0.0.0.0:3001
//

const net = require("net");

function parseOpts(args) {
    let replica = null;
    let addresses = [];
    args.forEach((arg) => {
        if (arg.startsWith("--replica")) {
            replica = +arg.replace("--replica=", "");
        }
        if (arg.startsWith("--addresses")) {
            addresses = arg.replace("--addresses=", "").split(",");
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
    return { replica, addresses };
}

class MessageHub {
    constructor(serverAddress) {
        this.serverAddress = serverAddress;
    }

    initServer() {
        this.server = net.createServer();
        this.server.on("connection", (socket) => {
            console.log("got connection");
            socket.on("data", (data) => {
                console.log("socket data", data.toString());
            })
        });
        this.server.on("error", (err) => {
            console.log("server error", err);
            setTimeout(() => this.initServer(), 100);
        });
        const port = this.serverAddress.split(":")[1];
        this.server.listen(port, () => {
            console.log("replica listening on", port);
        });
    }
}

const config = parseOpts(process.argv);
console.log(config);

const hub = new MessageHub(config.addresses[config.replica]);
hub.initServer();
