# 1. Heap-allocated queue for numbers.
  - `queue2/src/main.zig::IntQueue`
# 2. Make heap-allocated queue generic with compile-time types.
  - `queue2/src/main.zig::Queue`
# 3. User-managed nodes in the queue.
  - `queue3/src/main.zig::Queue`

## Use case: event loop for asynchronous actions where results are polled.

> When an action is requested (like reading from a file)
it is placed on the queue.

> And at each loop of the event loop,
an action is pulled from the queue and acted upon.

> If the action is not yet ready to be completed,
it gets placed back at the end.

### pseudocode:
```
START: add tasks to event loop
if there are outstanding tasks
    pop the task
        check the task's readiness
            (for a timer, check expire time)
            (for an async action, poll for event/result)
        if ready
            execute the task's callback
        else
            push the task back into the queue
    jump to START
```
