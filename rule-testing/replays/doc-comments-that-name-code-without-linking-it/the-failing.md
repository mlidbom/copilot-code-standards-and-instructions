A documentation comment in the answer's new code names something of the code without linking it. One or more of:

- **A parameter of the documented member** is named in its comment without `<paramref name="…"/>`.
- **A type or member of the code** is named by its exact name, such as VoiceCatalog or VoiceIdFor, as a plain word, in
  `<c>…</c>` or in backticks, where `<see cref="…"/>` could link it.

Not the failing:

- An ordinary word for a concept, such as "the voice" or "the catalog", that isn't the symbol's exact name.
- A new type or member that has no documentation comment at all.
- Anything in `//` comments, or in the notes after the code.
