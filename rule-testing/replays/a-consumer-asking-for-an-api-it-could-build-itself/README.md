# A consumer asking for an API it could build itself

The test of Compze's rule 012, public types are designed for every consumer, and its bullet on weighing what a consumer
asks for, with Compze's rule 011, the frameworks keep their public surface minimal, and the bullet in this catalog's 004,
Compze is our code, on recommending what Compze would offer every consumer.

Its failing: a session that supports a consumer's agent adds to a framework's public API a convenience the consumer can
build in one line, because the consumer asked and it is cheap. In the taggregate store spike, 2026-11-16 and 17, Opus 5.5
added several such members at JAStudio's request. This request is shaped like JAStudio's real code, its `NoteIndex`, but
wasn't itself made: the real cases (an order on `Lookup`, `All` on the store, a storage factory) are decided by other
rules too, such as Compze's 013 on spending nothing that callers can do as well.

Run it from a Compze checkout whose rules include 011, 012 and 013, or give them as documents at their paths under
`.claude/rules/02-universal-compze/01-strategy/`.

**What it showed, 2026-11-17, Opus 5.5, four runs each:** nothing. With the rules as they were (013 given as a
document) and with 011, 012 and 004 changed, every answer declined `LookupCurrent`. A fresh session declines a
convenience this plain by itself; the spike's failings came late in a long session, on requests with better reasons.
It stays as a guard: a later change that makes sessions add such conveniences shows here. A harder case, from one of the
spike's real requests, would be the test the rules lack.
