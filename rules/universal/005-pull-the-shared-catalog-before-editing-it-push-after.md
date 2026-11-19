# Shared rules and skills: pull before editing them, push right after

The rules and skills under `.claude-shared/` are shared by several repositories, through the catalog repository
`mlidbom/copilot-code-standards-and-instructions`. A rule symlinked into `.claude/`, such as
`.claude/rules/01-universal-shared/`, is the catalog too. Each checkout's `.claude-shared/` is a git worktree of the
machine's one clone of the catalog, `~/.claude/.claude-shared`, on a branch of its own. They're shared, so every edit
is shared at once (the user, 2026-11-11):

1. **Pull before editing:** `sh .claude-shared/git-scripts/pull.sh`. The edit is then made on what the other
   repositories have published.
2. **Edit,** one coherent change per catalog commit: commit each in the catalog itself (`git -C .claude-shared commit`),
   with a message that says what changed and why.
3. **Push right after:** `sh .claude-shared/git-scripts/push.sh`. It rebases the catalog commits onto upstream `main`
   and pushes them there. With `--message '<what changed and why>'`, it first commits whatever edits are uncommitted,
   as one commit.

Never leave an edit to the catalog unpushed: other repositories, and other sessions, would work from rules that are
out of date, and a later edit elsewhere would have to be merged with it. An edit left uncommitted is lost with its
checkout, too: removing a worktree of the consuming repository removes the catalog's worktree in it, edits and all.

Pushing the catalog needs no approval, as pushing never does: see "Commit and push whenever it helps" in the
[collaboration rules](001-collaboration-rules.md).
