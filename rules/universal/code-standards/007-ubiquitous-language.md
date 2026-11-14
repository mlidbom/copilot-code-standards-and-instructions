# DDD: Ubiquitous language — the same word for a concept everywhere a human reads it

We apply 'Eric Evans' **ubiquitous language**, universally.

Every concept in the system should have exactly one name, and that exact name should be used **in every artifact a
human reads**: type and member names, comments, commit messages, documentation, test and specification names,
user-facing text (labels, dialogs, errors). Even throwaway lab and research code.

The inverse is not true: the same word can mean different things in different contexts. Only a fully qualified name
has to mean one thing.

## A word that two names share is not a collision

A name is read with what qualifies it, as the `Importing` namespace and an `Import` action are, or a build server
and a card server. Don't rename either for the shared word, and don't propose to: in code, in documents or in
conversation.

## Why:

* Every time different words are used the reader must do mental mapping and translation making comprehension far harder.

## How

- **Renames apply everywhere.** 
- **Audit user-facing text too.** 
- **Two words for one concept is a modeling question, not a styling one.** 

See also: [the human mind](005-software-design-and-the-human-mind.md)


