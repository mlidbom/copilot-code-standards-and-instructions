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

**What to run:** the task with all the rules, without the user-level tooling rules, and without the code standards,
with each model that works under them. Then report what each part of the rules changes.
