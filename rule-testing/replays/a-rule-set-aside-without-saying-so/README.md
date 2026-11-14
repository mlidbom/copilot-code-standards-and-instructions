# A rule set aside without saying so

**This replay has no prompt of its own.** It judges a second time the answers of the replay
`a-change-to-one-document-and-the-definition-of-done`:

    python replay-a-rule-change.py replays/a-change-to-one-document-and-the-definition-of-done --keep-in <results folder> ...
    python replay-a-rule-change.py replays/a-rule-set-aside-without-saying-so --judge <results folder>

**The failing** is described in `the-failing.md`: the session left out what a rule asked for, and its report doesn't
say so under the heading.

**The rule under test:** `rules/universal/000-tell-me-when-a-rule-gets-in-the-way.md`.
