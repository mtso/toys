# 1. Heap-allocated queue for numbers.
# 2. Make heap-allocated queue generic with compile-time types.
# 3. User-managed nodes in the queue.

## Use case: event loop

> When an action is requested (like reading from a file)
it is placed on the queue. And at each loop of the event
queue, the action is pulled from the queue and acted upon.

> If the action is not yet ready to be completed,
it gets placed back at the end.
