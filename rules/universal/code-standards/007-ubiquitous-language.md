# DDD: Ubiquitous language — the same word for a concept everywhere a human reads it

Each concept has exactly one name, and that name is used everywhere a human reads about it: type and member names,
comments, documentation, commit messages, test and specification names, and the text users see, in throwaway lab code
too. Every time different words are used for the same thing, the reader must do mental mapping and translation. So two
words for one concept is a modeling question, not one of style, and a rename applies everywhere, user-facing text
included.

## A word that other names use is no collision

Only a fully qualified name has to mean one thing. A name is read with what qualifies it, as the `Importing` namespace
and an `Import` action are, or a build server and a card server. A word that other names already use, in the code, the
language or its frameworks, is no reason to avoid it, nor to rename either. The user: "Words do not need to be
absolutely distinct without context."
