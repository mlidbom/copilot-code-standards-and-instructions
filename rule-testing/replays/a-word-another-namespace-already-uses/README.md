# A word another namespace already uses

**The situation:** work on JAStudio's sentence reservoir, 2026-11-11. A new action reads an Anki package and writes it
into the reservoir's repository. The agent had named it "keep", and Magnus asked for another name: "Import? Save?".
JAStudio already had `JAStudio.Core.Importing`, which turns Anki notes into corpus sentences.

**The failing** is described in `the-failing.md`, which the judging sessions are given. That day the agent, Opus 5.5,
recommended "archive", and wrote: "Not 'import': in JAStudio that already means turning Anki notes into corpus
sentences", "so the word is best kept free for that."

**Not judged here:** it also kept a prefix on every type in the namespace (`KeptJson`, then `ArchiveJson`). That is
another failing, and the rule under test says nothing about it.

**The rule under test:** `rules/universal/code-standards/007-ubiquitous-language.md`. Its sidecar has the results.

`documents` is a part of JAStudio as it was that day, at commit `3024a1872`: the code of the action, three files of
the corpus's import, the design document, and a list of JAStudio.Core's namespaces.
