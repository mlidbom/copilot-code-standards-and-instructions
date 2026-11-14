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

- **Before adding a rule, ask whether the agent would do this anyway.** If so, leave it unwritten. A rule is for what
  the agent can't know or wouldn't choose by itself. An agent's own account of what it would do without the rule is not
  evidence: replay the case without the rule, as below.
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
came about is in its sidecar, and in `fixing-bad-rules-worklist.txt` in the catalog's `rules` folder while that work
lasts.

## Testing a change to a rule: replay the case in fresh sessions

`rule-testing/replay-a-rule-change.py` in the catalog replays a situation in which a rule went wrong, under two or more
versions of the catalog's rules, and prints what each fresh session answered on the point. Its own help says how.

- **Why fresh sessions:** a session, and the agents it starts, keep the rules they started with. A changed rule
  reaches only the sessions started after the change.
- **A replay** is a folder under `rule-testing/replays`: the prompt, which gives the situation as it stood and the
  user's message, and the documents the prompt has the session read. `a-word-shared-by-two-terms` is one.
- **Test before committing.** By default it runs the last commit against the working tree: the uncommitted change is
  one arm, and the rules without it are the control. `--arm name=none` adds what the model does with no shared rules.
- **Read what the answers say.** The script shows the passages; whether the failing happened is yours to judge. A
  difference of one answer shows nothing.
- **A session sees the name of the folder it runs in.** Folders named after what was tested, such as
  `with-the-sentence`, once made a sentence look as if it worked, ten answers of ten. The script gives the folders
  plain names. Do the same when replaying by hand.
- **Run the control at the same time as the change,** not from memory of an earlier run.
- **Keep the replay** when the case may come back. It is the rule's test.

## What loads, and when

- The native loader recursively discovers **`*.md` files only** under `.claude/rules/`. Non-`.md` files
  (`.txt`, `.gitkeep`) are never injected. Verified empirically: a `name.rationale.txt` sidecar does not load.
- A `.md` with **no `paths:` frontmatter** is always-on — loaded every session, same priority as CLAUDE.md.
- A `.md` **with `paths:` frontmatter** is path-scoped — excluded from session start, injected only when the
  agent reads or edits a file matching one of its globs. This file is an example.
- **Frontmatter gates, not the folder.** `universal/` and `path-scoped/` are human signposting only; the
  loader treats every subfolder identically and looks solely at frontmatter. A frontmatter-less file in
  `path-scoped/` would still load always; a globbed file in `universal/` would still be gated.

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
