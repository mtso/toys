import { createConnection, Socket } from "net";
import { Address } from "./config";

class Connection {
  private socket: Socket | null = null;
  private sendQueue: string[] = [];
  private sending: boolean = false;

  constructor(private address: Address) {}

  send(data: string) {
    this.sendQueue.push(data);
    this.flush();
  }

  // sendEvent<T extends Event>(event: T) {
  //   const serialized = JSON.stringify(event);
  //   this.sendQueue.push(serialized);
  //   this.flush();
  // }

  flush() {
    if (this.sending) {
      return;
    }

    this.sending = true;
    while (this.sendQueue.length > 0) {
      if (!this.isConnected()) {
        this.sending = false;
        this.ensureConnection();
        return;
      }

      const data = this.sendQueue.shift();
      this.socket && (this.socket as Socket).write(data as string);
    }
    this.sending = false;
  }

  ensureConnection() {
    if (this.isConnected()) {
      return;
    }

    const [host, port] = this.address;
    this.socket = createConnection({ host, port });

    this.socket.on("connect", () => {
      this.flush();
    });

    this.socket.on("error", (err) => {
      console.error("send socket error!", err);
      this.closeConnection();
    });

    this.socket.on("end", () => {
      this.closeConnection();
    });

    this.socket.on("data", (data) => {
      // Unexpected for send socket to receive data. Replicas
      // are expected to send via their send sockets
      // and received on this server via the receive socket.
      console.error("UNEXPECTED send socket received data!", data.toString());
    });
  }

  closeConnection() {
    this.socket && this.socket.destroy();
    this.socket = null;
  }

  isConnected() {
    return this.socket && !this.socket.destroyed;
  }
}

export default Connection;
