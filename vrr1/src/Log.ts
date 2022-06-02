import { existsSync, readFileSync, writeFileSync } from "fs-extra";
import { RequestEvent } from "./Replica";

export interface Metadata {
  commit: number;
}

const DEFAULT_METADATA: Metadata = {
  commit: 0,
};

class Log {
  constructor(private logFilepath: string, private metadataFilepath: string) {
    this.ensureMetadata();
  }

  append(op: number, request: RequestEvent) {
    const entry = [op, request];
    writeFileSync(this.logFilepath, JSON.stringify(entry) + "\n");
  }

  ensureMetadata() {
    if (!existsSync(this.metadataFilepath)) {
      this.writeMetadata({});
    }
  }

  writeMetadata(newMetadata: Partial<Metadata>) {
    const existing = this.readMetadata();
    const combined = Object.assign({}, existing, newMetadata);
    writeFileSync(this.metadataFilepath, JSON.stringify(combined, null, 2));
  }

  readMetadata(): Metadata {
    try {
      const contents = readFileSync(this.metadataFilepath);
      if (contents.length < 1) {
        return DEFAULT_METADATA;
      } else {
        return JSON.parse(contents.toString());
      }
    } catch (err: any) {
      if (err.code !== "ENOENT") {
        console.error(
          "UNEXPECTED file metadata read error",
          this.metadataFilepath
        );
      }
      return DEFAULT_METADATA;
    }
  }
}

export default Log;
