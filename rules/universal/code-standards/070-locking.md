# Synchronization: use Compze.Threading, and stop when it doesn't fit

Whenever Compze.Threading or Compze.Threading.Interprocess has what is needed, use it, never a raw `lock`, `Monitor`,
`Mutex` or the like.

What it gives that the built-in primitives don't, which is also where to look first:

- **State that can't be reached without its lock:** `IThreadShared<T>`, or an `IMonitor` around existing code.
- **Waiting for a condition, as one call with a predicate:** `UpdateWhen`, `ReadWhen` and `Await` on
  `IAwaitableThreadShared<T>`, with async forms that hold no thread. Releasing an update lock notifies the waiters, so
  no notification can be forgotten.
- **The same across processes:** `IMutex`, `IAwaitableMutex`, `IProcessShared<T>`.
- **Deadlocks diagnosed:** taking a lock times out, and the exception has both threads' stack traces.

What it deliberately doesn't have is a gate held across awaits, or released on another thread, such as a limit on how
many requests are in flight: its locks are short, synchronous and tied to the thread that took them. `SemaphoreSlim` does
that job fully, and is the right tool for it.

Apart from that, when it doesn't have what is needed, or using it would make the code worse, write neither the worse code nor the raw
primitive. Stop, and tell the user:

- why good code can't be written with what Compze has;
- what change to Compze would fix it.

Unlike the other standards, this one isn't for an [exception marked for review](020-when-to-break-the-rules.md): the
fix belongs in Compze, and that's the user's to decide.
