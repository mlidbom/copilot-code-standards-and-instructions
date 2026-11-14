# Documentation comments that name code without linking it

**This replay has no prompt of its own.** It judges a second time the answers of the replay
`code-where-a-guard-or-a-catch-is-tempting`, whose task has the session write documentation comments:

    python replay-a-rule-change.py replays/code-where-a-guard-or-a-catch-is-tempting --keep-in <results folder> ...
    python replay-a-rule-change.py replays/doc-comments-that-name-code-without-linking-it --judge <results folder>

**The failing** is described in `the-failing.md`. It is narrower than the rule: an ordinary word for a concept, such as
"the voice", isn't counted, since nearly every answer would then fail under any wording.

**The rule under test:** the section on linking tags in `rules/universal/code-standards/060-documentation-comments.md`.

**It doesn't yet tell wordings of the rule apart,** for the same reason as the replay it judges: on 2026-11-14 no
answer of 32 showed the failing, with or without the section. The code around the task links everything already.
