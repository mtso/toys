# 1. Heap-allocated queue for numbers.
# 2. Make heap-allocated queue generic with compile-time types.
# 3. User-managed nodes in the queue.

## Use case: event loop for asynchronous actions where results are polled.

> When an action is requested (like reading from a file)
it is placed on the queue.

> And at each loop of the event loop,
an action is pulled from the queue and acted upon.

> If the action is not yet ready to be completed,
it gets placed back at the end.

pseudocode:
while (true): // loop forever
    run program logic
        potentially enqueue actions (with a callback)
    run event loop
        if there are outstanding actions
            pop and try executing (invoke callback)
            if ready to do, do
            if not ready to do, enqueue back into the end
