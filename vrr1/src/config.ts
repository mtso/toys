import { resolve } from "path";
import { ensureDirSync } from "fs-extra";

export type Address = [string, number];

export const parseAddress = (address: string): Address => {
  const pieces = address.split(":");
  if (pieces.length < 2) {
    throw new Error("Invalid address: " + address);
  }
  const [host, port] = pieces;
  if (!host.match(/^([0-9]{1,3}\.){3}[0-9]{1,3}$/)) {
    throw new Error("Invalid host: " + address);
  }
  if (isNaN(+port)) {
    throw new Error("Invalid port: " + port);
  }
  return [host, +port];
};

export const addressesEqual = (a: Address, b: Address) => {
  return a[0] === b[0] && a[1] === b[1];
};

export interface Config {
  replica: number;
  addresses: Address[];
  directory: string;
  logFilename: string;
  metadataFilename: string;
}

export const parseConfig = (args: string[]): Config => {
  let replica: number | null = null;
  let addresses: Address[] | null = null;
  let directory: string | null = null;

  args.forEach((arg: string) => {
    if (arg.startsWith("--replica=")) {
      replica = +arg.replace("--replica=", "");
    }
    if (arg.startsWith("--addresses=")) {
      addresses = arg.replace("--addresses=", "").split(",").map(parseAddress);
    }
    if (arg.startsWith("--directory=")) {
      directory = resolve(arg.replace("--directory=", ""));
    }
  });

  if (null === addresses) {
    console.error("Invalid --addresses", addresses);
    process.exit(1);
  }

  if (
    null === replica ||
    isNaN(replica) ||
    replica > (addresses as Address[]).length - 1
  ) {
    console.error("Invalid --replica", replica);
    process.exit(1);
  }

  if (null === directory) {
    console.error("Invalid --directory", directory);
    process.exit(1);
  } else {
    ensureDirSync(directory);
  }

  return {
    replica,
    addresses,
    directory,
    logFilename: "journal.log",
    metadataFilename: "metadata.json",
  };
};
