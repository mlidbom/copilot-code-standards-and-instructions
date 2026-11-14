# Shared rules and skills: pull before editing them, push right after

The rules and skills under `.claude-shared/` are shared by several repositories, through the catalog repository they're
a submodule of. A rule symlinked into `.claude/`, such as `.claude/rules/01-universal-shared/`, is the catalog too.
They're shared, so every edit is shared at once (the user, 2026-11-11):

1. **Pull before editing:** `.claude-shared/git-scripts/pull.ps1`. The edit is then made on what the other repositories
   have published, and the pull commits the catalog's new pin in this repository.
2. **Edit,** one coherent change per catalog commit: commit each in the catalog itself (`git -C .claude-shared commit`),
   with a message that says what changed and why.
3. **Push right after:** `.claude-shared/git-scripts/push.ps1`. It rebases the catalog commits onto upstream, pushes
   them, and commits the new pin in this repository. With `-Message '<what changed and why>'`, it first commits whatever
   edits are uncommitted, as one commit.

Never leave an edit to the catalog unpushed: other repositories, and other sessions, would work from rules that are
out of date, and a later edit elsewhere would have to be merged with it.

Pushing the catalog needs no approval, as pushing never does: see "Commit and push whenever it helps" in the
[collaboration rules](001-collaboration-rules.md).
