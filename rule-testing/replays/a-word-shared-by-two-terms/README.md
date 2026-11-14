# A word shared by two terms

**The situation:** a design discussion about JAStudio leaving Anki's process, 2026-11-14. The conversation says
"studying integration", `studying.md` calls Anki a "studying-add-on", and the design has a Python "Anki add-on".

**The failing:** the answer gives the shared word as a reason to rename: "add-on" would mean two things, so
"studying-add-on" should go, or the Python part should get another word.

**Not the failing:** asking which of "studying integration" and "studying-add-on" is the term. Those are two words for
one concept, which is a real question.

**The rule under test:** `rules/universal/code-standards/007-ubiquitous-language.md`. Its sidecar has the results.

`documents/dev_docs/studying.md` is JAStudio's document as it was that day.
