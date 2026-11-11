# DDD: Ubiquitous language — the same word for a concept everywhere a human reads it

We apply 'Eric Evans' **ubiquitous language**, universally.

Every concept in the system should have exactly one name, and that exact name should be used **in every artifact a
human reads**: type and member names, comments, commit messages, documentation, test and specification names,
user-facing text (labels, dialogs, errors). Even throwaway lab and research code.

The inverse is NOT true. As long as the context makes things clear, different classes having members with the same name, multiple namespaces having types with the same name etc. is perfectly fine.
That's how language works: words mean different things in different contexts, and readers tell them apart by the
context. So never avoid the obvious word, such as import, store, save or load, because the codebase uses it elsewhere.

## Why:

* Every time different words are used the reader must do mental mapping and translation making comprehension far harder.

## How

- **Renames apply everywhere.** 
- **Audit user-facing text too.** 
- **Two words for one concept is a modeling question, not a styling one.** 
- **A fully qualified name defines one unique concept, and that is the only definition of that concept.**

See also: [the human mind](005-software-design-and-the-human-mind.md)


