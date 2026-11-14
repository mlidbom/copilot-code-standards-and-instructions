# Name for the human who must look it up — your own comprehension is a broken gauge

The single reader of these names is the user, and they are not you: they do **not** already know what a symbol
is, so a name that doesn't tell the truth costs them a real lookup — every time, forever. Name for
that reader. The test is never "will *I* understand this," because by that test every name passes: you resolve
a terse or even lying name instantly from context you've already absorbed, so your own comprehension stays
green on names that would send the user looking things up. Switch the test: **does the name tell someone who
does not already know what this thing is and what it is for?** If not, it is not named yet.

Two forces push you the wrong way. Treat both as suspect signals, not as taste:

- **Trained terseness.** Most code you have seen rewards characters-saved — `mgr`, `ctx`, `tmp`, `h`, `i`/`j`,
  ad-hoc abbreviations and acronyms. That is the distribution you came from, not good taste, and it masquerades
  as "clean = short." The urge to shorten is a training artifact to resist, not an instinct to trust. Here
  "clean" means clear, never terse (see [naming-and-conceptual-fit-are-preeminent](011-naming-and-conceptual-fit-are-preeminent.md)).
- **Your omniscience.** A bad name costs you almost nothing — you already know the domain, the APIs, the
  surrounding code — so self-comprehension is worthless as a quality check.

Operationally: **do not fear typing.** A name is as long as it must be to be understood with no lookup, never
shorter; brevity is only a tie-breaker between equally clear names. Keep distinct domain words distinct (a `chord` is
the key combination; a `hotkey` is the bound, globally-caught action).

Pairs with [conceptual coherence](010-conceptual-coherence-and-naming.md),
[naming-and-conceptual-fit-are-preeminent](011-naming-and-conceptual-fit-are-preeminent.md), and
[renaming-is-the-most-important-refactoring](012-renaming-is-the-most-important-refactoring.md).
