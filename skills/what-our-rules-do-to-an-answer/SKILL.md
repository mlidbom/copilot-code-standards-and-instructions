---
name: what-our-rules-do-to-an-answer
description: >-
  Compares a fresh session's answer with all our rules to one with nothing of ours, on the same prompt. Use when the
  user doubts a rule made an answer worse, or for an opinion free of our conventions.
---

# What our rules do to an answer: the same prompt, with all our rules and with nothing of ours

Two fresh sessions get the very same prompt. One has all our rules: the user-level ones, and the consuming repository's
with the catalog's. The other, the bare one, has nothing of ours: no rules at any level, CLAUDE.md, skills, hooks or
memory. Side by side, the two answers show what our rules did to it.

## When

- **The user doubts that a rule made an answer worse,** or you do.
- **An opinion free of our conventions,** such as on names or a design: the bare answer is the model's own.

One answer each shows what can happen, not how often: it doesn't show how a rule changes behavior in practice.

## How

1. **Write the prompt** to `prompt.txt` in a new folder. Neither session runs in the repository, so the prompt holds
   all they need: the situation and the question. Files they are to read go in `documents/` beside it, at the paths the
   prompt names.
2. **Run both,** from the repository root, with `--model` for the model the question is about:

   ```
   python .claude-shared/rule-testing/replay-a-rule-change.py <the folder> --arm with-our-rules=working-tree --arm bare=bare --runs 1
   ```

   It prints both whole answers, and the folder it keeps them in. `working-tree` is the catalog as it is on disk,
   uncommitted changes to its rules included.
3. **Read both answers yourself,** and report what differs, which you think better, and why.

Each fresh session spends its whole loaded context out of the user's weekly quota: 34,000 tokens with all our rules,
6,000 bare, for a one-line question (2026-11-18). Run once each.
