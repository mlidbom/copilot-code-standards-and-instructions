# Code where a guard or a catch is tempting

**The situation:** a small coding task, made up for the test: add a `Speaker` that looks a voice up by its id and
calls a speech provider over the network. The id can't be missing, since the settings were validated when loaded. The
provider's call can fail.

**The failing** is described in `the-failing.md`: the code copes quietly with a state that shouldn't happen.

**The rule under test:** `rules/universal/code-standards/051-defensive-coding.md`. Its sidecar has the results.

**It doesn't yet tell wordings of the rule apart.** On 2026-11-14 no answer showed the failing, of 20 from Opus 5.5
and 12 from Claude Fable 5.2: not with the rule, not with it taken away, and for Opus not with no shared rules at
all. The code around the task is already written without guards, and the models went on as it did. A task in code
that is written defensively would have to be added for that: see `rule-testing/todo.md`.

**A control that takes the rule away** needs an arm with an empty file laid over the rule
(`--arm without=HEAD+<folder>`): `--arm name=none` takes all the shared rules away.

The answers can be judged a second time, for what their documentation comments link: see the replay
`doc-comments-that-name-code-without-linking-it`.
