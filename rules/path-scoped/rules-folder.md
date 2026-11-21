---
paths:
  - ".claude/rules/**/*.md"
  - ".claude/rules/**/*.txt"
  - ".claude-shared/rules/**/*.md"
  - ".claude-shared/rules/**/*.txt"
---

# How the rules folder works

This folder replaces CLAUDE.md. It's read by both humans and the agent; this file is the map. It's
*path-scoped* (note the `paths:` frontmatter above), so it loads only when you're actually touching a file
under `.claude/rules/` — i.e. when editing the rules themselves — and costs nothing in a normal session.

## Writing and changing a rule

Every always-on rule is read in every session, by a model that follows what it reads closely. A rule that is a little
wrong does its harm each time it applies, and the user only sees the result. So:

- **Judge a rule by what the rules are for,** which `000-global-speed-through-the-best-work-and-relentless-refactoring.md`
  and `000-tell-me-when-a-rule-gets-in-the-way.md` give in the user's words: the project's speed over months and years,
  through the best possible work and relentless refactoring; how well the agent works as a whole; and far behind that,
  how readable and maintainable the rules are for him. A rule that gets followed and makes the work worse has failed.
- **Before adding a rule, ask whether the agent would do this anyway.** If so, leave it unwritten. A rule is for what
  the agent can't know or wouldn't choose by itself. An agent's own account of what it would do without the rule is not
  evidence; what agents do in real use is (below).
- **A one-off is not worth a rule.** A rule written for one incident costs every session and may well make things
  worse. A correction of behavior waits until the same thing goes wrong again and again, and is then talked over with
  the user: "In dealing with other intelligent beings, I don't start crafting new rules/laws for every mistake that
  happens" (2026-11-19). A fact about the environment that is costly to rediscover may be written down once, short. A
  tool's occasional glitch gets nothing.
- **Facts, not instructions.** Give the agent what it can't derive, and leave what to do with it to its judgment.
  Instructions are for hard limits, the user's taste where it isn't the mainstream's, and protocols between several
  parties. Write as a concise brief to a capable colleague, not a conversation.
- **A rule, or a skill.** Every session loads a rule whole, and only a skill's description:
  - **A skill, when it's a how-to for a task that announces itself,** such as profiling, or upgrading a project's
    packages. Its description says when to use it, in the words the task arrives in, and its body loads next to the
    work, not once at the start of a long session.
  - **A rule, when it's about how to work at all times, or a trap:** something that goes wrong in the middle of other
    work, with nothing to announce it, such as a Unicode escape arriving as the character itself. Give a trap's rule no
    more words than the trap takes.
  - **A rule that matters only around certain files** gets `paths:` frontmatter (below), so it loads only when they're
    touched.
- **Know which kind of rule it is,** since that decides how it's worded:
  - **A hard limit:** breaking it does harm that can't be undone, such as changing an external environment without
    approval. Absolute wording belongs here, and only here.
  - **A fact** the agent can't derive, about a tool, this machine or the project: stated plainly, with a date if it can
    go stale.
  - **The user's taste where it isn't the mainstream's,** such as no defensive coding: what he wants, and why.
  - **A correction** of something an agent did wrong. This is the most suspect kind: it's written for one model's
    failing, and outlives it. Check first whether another rule caused the failing. Its sidecar names the model that
    did it, by its full version, such as Opus 4.6 and not just Opus, with the date. When you don't know the model,
    look in the transcript of the session it happened in, which records it. If that's gone, name the latest Opus of
    that date, as "most likely".
- **State the value and its reason once, in plain words,** the user's own where there are any. The reason is what lets
  the agent apply the rule to cases the wording doesn't list. The incident behind it goes in the sidecar, and so does
  the case for the rule: the evidence, how strongly it's held, who agreed. What stays in the rule is the reason that
  changes what the agent does, and the facts it can't derive, such as what a tool offers.
- **Word it for every case it's meant for.** A rule worded for its incident, such as one that speaks only of classes and
  namespaces, isn't recognised when the same thing happens in a document.
- **Don't tell the agent to distrust its own judgment.** Say what the reader needs instead. Told that its own reading
  doesn't count, the agent solves problems nobody has.
- **When a rule misfires, look first for a sentence to remove,** in that rule or in the one that caused it. A rule that
  corrects another rule is the last resort: the two then have to be weighed against each other in every session.
- **Don't repeat a rule in other rules.** Link to it.
- **When the model changes, go through the corrections again,** those written for earlier models first: their sidecars
  say which. What it took to move an earlier model makes a later one overdo it.
- **Rules are discussed with the user before they're written or changed,** as code is. An agent that writes one unasked
  writes it long, and for the case in front of it.

The always-on rule `000-tell-me-when-a-rule-gets-in-the-way.md` is how a rule that does harm gets noticed. How this
came about is in its sidecar.

## Checking a change to a rule: in real use

Make the change and work as usual; when something misfires, the user or an agent says so (the rule on telling him when
a rule gets in the way). A few test prompts can't show how a rule changes an agent's behavior in practice (the user,
2026-11-19), and each fresh session spends its whole loaded context out of his weekly quota. A changed rule reaches
only the sessions started after it.

`rule-testing/replay-a-rule-change.py` in the catalog runs one prompt under several versions of the rules, or with none
of ours (the skill what-our-rules-do-to-an-answer): useful for an answer free of our conventions, not as proof that a
rule works.

## What loads, and when

- The native loader recursively discovers **`*.md` files only** under `.claude/rules/`. Non-`.md` files
  (`.txt`, `.gitkeep`) are never injected. Verified empirically: a `name.rationale.txt` sidecar does not load.
- A `.md` with **no `paths:` frontmatter** is always-on — loaded every session, same priority as CLAUDE.md.
- A `.md` **with `paths:` frontmatter** is path-scoped — excluded from session start, injected only when the
  agent reads or edits a file matching one of its globs. This file is an example.
- **Frontmatter gates, not the folder.** `universal/` and `path-scoped/` are human signposting only; the
  loader treats every subfolder identically and looks solely at frontmatter. A frontmatter-less file in
  `path-scoped/` would still load always; a globbed file in `universal/` would still be gated.
- **`agents: [claude]` frontmatter marks a rule only for Claude;** without it, a rule is for Codex too. Codex's
  setup is written from these files by ClaudesSetupForCodex (in `~/.claude`), which leaves out what says
  `[claude]`: a rule that names tools or commands Codex hasn't got, such as Claude Code's MCP servers. Claude Code
  ignores the key, `paths:` beside it included (tested 2026-11-21). So it would load a rule only for Codex as well,
  where it would mislead: such a rule goes where Claude Code doesn't look, `~/.claude/rules-for-codex/`.

## Include order

Entries sort alphabetically by name within a directory — files and subfolders intermixed; a subfolder is
expanded depth-first in place at its slot. Order by importance with numeric prefixes (`01-`, `02-`): a
leading digit sorts before any letter, so it jumps the queue past sibling files *and* folders.

## Rationale sidecars (`name.rationale.txt`)

Keep each rule `.md` lean — only what helps you **follow** the rule (the instruction plus the apply-time
*why* that lets you generalize it to cases the wording didn't enumerate). What is needed only when
**changing** the rule goes in a sidecar named `<rule>.rationale.txt` (the rule's base name with the `.md` dropped and
`.rationale.txt` appended — e.g. `051-defensive-coding.md` → `051-defensive-coding.rationale.txt`).

- **A sidecar holds what someone changing the rule must know and can't see in the rule:**
  - the need or the failing behind the rule, in a line or two, with the date, and for a correction the model;
  - what looks removable but isn't, and what was tried and rejected;
  - what is untested, and where to look first if the rule goes wrong;
  - the user's own words behind the rule, where the rule doesn't quote them.
- **It states what is known now. It is not a log.** When the rule changes, rewrite the sidecar; don't append to it.
  What changed, and when, is in git, and the commit message says why.
- **No longer than that takes.** The user reads it too, and doesn't when it has grown into a record of everything ever
  discussed about the rule: "not helpful to me simply because of the length".
- **Self-documenting and co-located.** "rationale" in the name says what it is at a glance, and the shared
  prefix sorts it directly beneath its rule, so humans see it in the tree. The `.txt` extension keeps it out
  of the agent's always-on context.
- **Before editing a rule, read its `.rationale.txt` sidecar if one exists.** That's how the rationale
  reaches whoever is changing the rule — human or agent — at the one moment it matters, without taxing every
  session.
- **Write sidecars in Markdown despite the `.txt` extension.** The `.txt` only dodges the loader; it's not a
  signal to drop to plain prose. The agent and humans still read it as Markdown — as with every `.txt` doc in
  this folder (the `README.txt` too).

Worked example: `universal/code-standards/051-defensive-coding.rationale.txt`.
