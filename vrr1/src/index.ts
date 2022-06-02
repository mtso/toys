import path from "path";
import { addressesEqual, parseConfig } from "./config";
import Log from "./Log";
import MessageHub from "./MessageHub";
import Replica from "./Replica";

const config = parseConfig(process.argv);

const serverAddress = config.addresses[config.replica];

const hub = new MessageHub(
  serverAddress,
  config.addresses.filter((address) => !addressesEqual(serverAddress, address))
);

const log = new Log(
  path.join(config.directory, config.logFilename),
  path.join(config.directory, config.metadataFilename)
);

const replica = new Replica(hub, log, config.replica);

replica.serve();
