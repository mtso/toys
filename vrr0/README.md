- `index` current viewstamped replication impl with view changes;
punted on client-table repair after view change.
- `index0` mind-to-paper sketch of a message hub and Peer class
- `index1` removed Peer class and added command line arg parsing
- `index2` server-client replica cluster implementation that sends logs
to other backups in a "fire-and-forget" manner (`propagate` event)
- `index3` server-client append-log cluster of replicas where the replica that
handles a client's request sends the log to replicas and waits for acks (`propagate_ok`)
from every other replica before returning an `ok` response to client
- `index4` viewstamped replication implementation of "Normal Operation"
