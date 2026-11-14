# Synchronization: use Compze.Threading, and stop when it doesn't fit

Whenever Compze.Threading or Compze.Threading.Interprocess has what is needed (`IMonitor`, `IAwaitableMonitor`, `IMutex`
and the rest), use it, never a raw `lock`, `Monitor`, `Mutex` or the like.

**Why:** in the user's words it is "a vastly better API than the built in synchronization primitives":

- "safer, easier to use, harder to misuse";
- "reads better, results in fewer lines";
- "identical API's for in-process synchronization and inter process" synchronization;
- it "composes beautifully into abstractions built on it", such as `IInterprocessObject`;
- it diagnoses deadlocks automatically, which "is HUGE in itself".

An agent that compared the two (Claude Fable 5.2, 2026-11-14): "I share that, most of all for waiting on a condition.
What took me 72 lines with `Monitor`, with a pulse to remember in every method that changes the state and a second
mechanism for async, is 17 lines of predicates here. And the built-in primitives have no such wait across processes."

When it doesn't have what is needed, or using it would make the code worse, write neither the worse code nor the raw
primitive. Stop, and tell the user:

- why good code can't be written with what Compze has;
- what change to Compze would fix it.

Unlike the other standards, this one isn't for an [exception marked for review](020-when-to-break-the-rules.md): the
fix belongs in Compze, and that's the user's to decide.
