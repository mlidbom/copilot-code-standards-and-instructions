# To do in rule testing

## Measure what the rules buy in design quality

Decided 2026-11-14 by Magnus, to be done later: "Add a todo somewhere permanent about this, but do not do it now."

**The gap:** the rules are judged by guesswork on the thing that matters most. Magnus, the same day, on what he wants
of the rules: "Most important by far: How well you function as a whole. Hard to define, but hard adherence to the rules
in every situation is probably NOT the most important thing. Solving your tasks with well designed code that adheres
to the spirit of the code standards is about it." Nobody knows what the always-loaded rules buy or cost by that
measure: about 17,900 words in a JAStudio session that day. And an agent's own account of what it would do without a
rule has been wrong when tested.

**What to build:**

- **A replay of a real design or coding task,** where design quality shows in the answer. The replays so far each
  test one failing of one rule.
- **A description of "good" for the judging sessions,** in the spirit of the code standards, and checked against
  answers Magnus has judged himself.
- **A way to take the user-level rules out of an arm.** The script controls only the catalog's rules: those under
  `~/.claude/rules` load in every arm.

**A smaller step on the way:** a coding replay in which the failing shows at all. The first one,
`code-where-a-guard-or-a-catch-is-tempting`, shows none, even with no shared rules: its code is already written the
way the standards ask, and the models go on as the code around them does. So the standards may matter most where
the surrounding code doesn't follow them, and that is the task to build.

**What to run:** the task with all the rules, without the user-level tooling rules, and without the code standards,
with each model that works under them. Then report what each part of the rules changes.
