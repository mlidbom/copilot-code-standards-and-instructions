---
name: what-our-rules-do-to-an-answer
description: >-
  Compares a fresh session's answer with all our rules to one with nothing of ours, on the same prompt. Use when the
  user doubts a rule made an answer worse, when evaluating or changing a rule, or for an opinion free of our
  conventions.
---

# What our rules do to an answer: the same prompt, with all our rules and with nothing of ours

Two fresh sessions get the very same prompt. One has all our rules: the user-level ones, and the consuming repository's
with the catalog's. The other, the bare one, has nothing of ours: no rules at any level, CLAUDE.md, skills, hooks or
memory. Side by side, the two answers show what our rules did to it.

In Compze, 2026-11-18, an agent with nothing of ours named a feature better than one with all our rules, and the user
chose its names. No agent had thought of comparing them: the user suggested it.

## When

- **The user doubts that a rule made an answer worse,** or you do.
- **Evaluating or changing a rule:** the bare answer is what the model does without any rule, so it shows whether the
  rule changes anything at all. Whether a replay is worth its cost, and how to read one, is in
  `.claude-shared/rules/path-scoped/rules-folder.md`, under "Checking a change to a rule".
- **An opinion free of our conventions,** such as on names or a design: the bare answer is the model's own.

## How

1. **Write the prompt** to `prompt.txt` in a new folder. Neither session runs in the repository, so the prompt holds
   all they need: the situation and the question. Files they are to read go in `documents/` beside it, at the paths the
   prompt names. A case to keep, for a rule, goes under `.claude-shared/rule-testing/replays`.
2. **Run both,** from the repository root, with `--model` for the model the question is about:

   ```
   python .claude-shared/rule-testing/replay-a-rule-change.py <the folder> --arm with-our-rules=working-tree --arm bare=bare --runs 1
   ```

   It prints both whole answers, and the folder it keeps them in. `working-tree` is the catalog as it is on disk,
   uncommitted changes to its rules included.
3. **Read both answers yourself,** and report what differs, which you think better, and why.

To test a change to a rule against the bare arm as well, add `--arm bare=bare` to the replay's other arms: the script's
`--help` says how.

## What it costs

- **Each fresh session spends its whole loaded context out of the user's weekly quota,** the one with all our rules
  most: 34,000 tokens against the bare one's 6,000, for a one-line question in a test on 2026-11-18. So run once each,
  and more only when one answer each doesn't settle it.
- **One answer's difference shows nothing about how often:** it shows what can happen. A claim that a rule does it
  needs more runs, or real use.
- **A judge is a model too.** With a `the-failing.md` in the folder, a fresh session judges each answer: read the
  answers beside its verdicts.
