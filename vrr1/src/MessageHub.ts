import { AddressInfo, createServer, Server, Socket } from "net";
import EventEmitter from "events";
import { Address } from "./config";
import Connection from "./Connection";
import { Event } from "./Replica";

/**
 * Accepts connections on the port of the specified address
 * and manages outgoing connections to peers.
 */
class MessageHub extends EventEmitter {
  private server: Server;
  private peers: Connection[];

  constructor(
    private serverAddress: Address,
    private peerAddresses: Address[]
  ) {
    super();
    this.peers = peerAddresses.map((address) => new Connection(address));
    this.server = createServer();
    this.attachServerHandlers(this.server);
  }

  private attachServerHandlers(server: Server): Server {
    server.on("connection", (socket) => {
      const connectionId: string = Math.random().toString().substring(2);
      console.log("receive server new connection", connectionId);

      socket.on("data", (buffer) => this.handleData(buffer, socket));

      socket.on("error", (err) => {
        console.error("connection socket error!", err);
      });

      socket.on("close", (hadError) => {
        if (hadError) {
          console.error("connection closed, encountered transmission error!");
        }
      });

      socket.on("end", () => {});

      socket.on("connect", () => {});
    });

    server.on("error", (err) => {
      console.error("receive server error!", err);
      process.exit(1);
    });

    server.on("close", () => {
      console.warn("receive server closing!!");
    });

    return server;
  }

  handleData(buffer: Buffer, socket: Socket) {
    const bufferString = buffer.toString();
    const lines = bufferString
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l !== "");

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      let payload;
      try {
        payload = JSON.parse(line);
      } catch (err) {
        console.warn("failed to JSON.parse data", line, err);
        return;
      }

      if ("event" in payload) {
        if ("clientId" in payload) {
          // TODO handle client ID by storing client connection.
          console.log("client request!");
        }

        try {
          this.emit(payload.event, payload, socket);
        } catch (err) {
          console.error("UNEXPECTED emit error", err);
        }
      } else {
        console.warn("misformatted payload (missing 'event')", payload);
      }
    }
  }

  initServer(cb?: (port: number) => void) {
    const [_, port] = this.serverAddress;
    const listener = this.server.listen(port, () => {
      const info = listener.address() as AddressInfo;
      if (cb) {
        cb(info.port);
      } else {
        console.log(`Listening on ${info.port}`);
      }
    });
  }

  sendToReplicas<T extends Event>(event: T) {
    const serialized = JSON.stringify(event) + "\n";
    this.peers.forEach((peer) => peer.send(serialized));
  }
}

export default MessageHub;
