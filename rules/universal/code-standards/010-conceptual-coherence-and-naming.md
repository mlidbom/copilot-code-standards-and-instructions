# Conceptual coherence and naming come first: each type and member is one clear concept, and its name tells the truth

The user: "Implementation details are a distant, also-ran, in importance to me, while clear intuitive mental models are
the absolute world champion of importance."

Every type and member is one clear concept, held at a consistent level of abstraction, and its name tells the truth
about what it is. A `User` must be a user; a value object holding a user's registration details is
`UserRegistrationData`, or `Users.RegistrationData`, never just `User`.

The test: the code is understood by reading names, not by working out implementations.

- **A type:** its name and its members' names tell what it is, and what each member is for. A documentation comment
  briefly explains what the abstraction is.
- **A method:** it reads as what it does. Anything not obvious as it stands is extracted behind a name, all the way
  down ([everything in its place](031-everything-in-its-place.md)).

**Why:** a human reader has the names to go on, and reads them far more often than the bodies behind them. The user:
"To me, without a great name, I need to go looking things up CONSTANTLY to be sure what I'm looking at."

## Names

- **As long as it takes for a reader new to the code to understand it with no lookup.** "Do not fear typing." Brevity
  only decides between names that are equally clear. Short names aren't the clean ones here, though most code has
  them: "code of a type that I utterly hate that optimizes for characters typed and just loves variable names like
  a,b,c,d and ad-hoc abbreviations and acronyms" (the user).
- **No abbreviations,** unless it's certain both that the reader knows the abbreviation and that it's obvious in
  context.
- **A method's name tells what it does.** If you need to read the method to understand what a line calling it does,
  renaming or other refactoring is in order.
- **Prefer the obvious term if it fits.** If there is a standard term that will almost certainly be understood
  intuitively in context, that is a strong signal in favor of using that over inventing something new.
- **The flowing lambda variable in fluent code is `it`** by default. It means exactly the right thing in English: the
  thing we are already talking about.
- **The name is then the concept's one word, everywhere** it appears: its
  [ubiquitous language](007-ubiquitous-language.md) term.

## Renaming is the most important refactoring there is

The user "100% seriously consider[s] renaming to be the most important refactoring that exists". A name is read at every
call site, so one that tells less than the truth misleads every reader, everywhere. Correcting it is often the whole
fix: when a type's name claims a concept the type isn't, the rename is the design fix.

- **Rename when a truer name occurs to you.** It's a fix to make now, not polish for later.
- **A name being everywhere is no reason to keep it:** every use carries the wrong idea.
- **In review and design, raise the names first.** Proposing a rename is proposing a real fix.

## When the user remarks on code

"When I'm pointing out something about code, unless I'm specifically pointing at a bug, the odds are 90%+ that what I'm
talking about is questionable design in this sense, not implementation."

- **Answer about the concept:** does the name, or the abstraction, fit the concept it calls to mind? How the
  implementation happens to work doesn't answer that. "If the name it is given is messed up given what it is used as,
  that does NOT mean it is OK — it means we have a fundamental modeling error to fix." Propose the rename or the new
  model, and let him choose the direction.
- **Conceptual coherence isn't weighed against usage, performance or YAGNI.** Those bear on how to reach the coherent
  model, not on whether to. Lead with the coherent model, then say what it costs. Whether something is the right kind
  of type, a value or an entity, is a question of coherence too, not a detail.
- **"Clean", "simple" and "maintainable" mean this** when the user says them: conceptual coherence, and extracting
  whenever it reads clearer. Not fewer parts, and not "don't abstract until it's reused".

## What doesn't outweigh conceptual coherence

- **Reuse counts, minimalism, YAGNI:** extract whenever it reads clearer, used once or not
  ([standard wisdom traps](040-standard-wisdom-traps.md)).
- **The size of the refactoring:** total restructurings are not just fine, but encouraged, as long as the resulting
  code reads clearer.
- **Convention:** that something is unconventional, or that the current code already does otherwise, is no reason
  against it.
