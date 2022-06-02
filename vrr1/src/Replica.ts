import Log from "./Log";
import MessageHub from "./MessageHub";

export interface Event {
  event: string;
}

export interface StatEvent extends Event {
  clientId: number;
}

export interface TestEvent extends Event {
  replica: number;
}

export interface TestShareEvent extends Event {
  replica: number;
}

export interface RequestEvent extends Event {
  clientId: number;
  requestNumber: number;
  expr: string[];
}

class Replica {
  constructor(
    private hub: MessageHub,
    private log: Log,
    private replica: number
  ) {
    this.hub.on("test", (event) => this.onTest(event));
    this.hub.on("testShare", (event) => this.onTestShare(event));
    this.hub.on("request", (event) => this.onRequest(event));
  }

  serve() {
    this.hub.initServer((port) => {
      console.log(`Replica ${this.replica} started listening on ${port}`);
    });
  }

  onTest(event: Event) {
    console.log("onTest", JSON.stringify(event));

    this.hub.sendToReplicas({
      event: "testShare",
      replica: this.replica,
    } as TestEvent);
  }

  onTestShare(event: TestShareEvent) {
    console.log("onTestShare", JSON.stringify(event));
  }

  onRequest(event: RequestEvent) {
    this.log.append(0, event);
  }
}

export default Replica;
