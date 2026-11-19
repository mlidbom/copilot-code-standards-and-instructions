# Conceptual coherence and naming come first: each type and member is one clear concept, and its name tells the truth

The user: "Implementation details are a distant, also-ran, in importance to me, while clear intuitive mental models are
the absolute world champion of importance." And: "without a great name, I need to go looking things up CONSTANTLY to be
sure what I'm looking at."

Each type and member is one clear concept, and its name tells the truth about what it is: a value object holding a
user's registration details is `UserRegistrationData`, never `User`. Whether it is the right kind of type, a value or an
entity, is part of that.

## Names

- **Understood where it is used, with no lookup:** by a reader who hasn't read its doc comment or its body. A name that
  is true once you know what it does isn't enough: the user chose `SnapshotRoundTrip.DifferencesBetweenItAndItsCopy`
  over `DifferencesOf`, since with it "I don't need to read the doc comment to understand what in the world is meant by
  Of here."
- **As long as that takes.** "Do not fear typing." Brevity decides only between names that are equally clear. The user
  hates code "that optimizes for characters typed and just loves variable names like a,b,c,d and ad-hoc abbreviations
  and acronyms": an abbreviation only where every reader certainly knows it.
- **A standard term the reader will understand in context** beats an invented one.
- **The flowing lambda variable in fluent code is `it`:** in English, the thing we are already talking about.
- **One word for each concept,** everywhere: the [ubiquitous language](007-ubiquitous-language.md).

## Renaming

The user considers renaming "the most important refactoring that exists": a name that tells less than the truth misleads
everywhere it is read, and when a type's name claims a concept the type isn't, the rename is often the whole design fix.
Rename when a truer name occurs to you, however widely the name is used. In review and design, raise the names first.

## What the user means

- **When he remarks on code** and isn't pointing at a bug, the odds are 90% or more that he means the concept: does the
  name, or the abstraction, fit what it is used as? How the implementation works doesn't answer that. "If the name it is
  given is messed up given what it is used as, that does NOT mean it is OK — it means we have a fundamental modeling
  error to fix." Propose the rename or the new model, and let him choose.
- **"Clean", "simple" and "maintainable"** mean conceptual coherence, and extracting whenever it reads clearer: not fewer
  parts.
- **Coherence isn't traded against usage counts, performance, YAGNI, the size of the refactoring, convention or what the
  code does now.** Those decide how to reach the coherent model, not whether to: lead with the model, then say what it
  costs.
