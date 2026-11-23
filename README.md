# Shared Claude Code configuration

Shared Claude Code configuration — rules, skills, and the scripts to manage them — checked out at
`.claude-shared/` in every repository that consumes it. Each machine has one clone of the catalog, the **machine
clone**, at `~/.claude/.claude-shared`, and every other checkout's `.claude-shared/` is a **git worktree** of it, which
the session-start hook creates and keeps up to date. No consuming repository records a commit of the catalog: every
checkout works under the latest rules. Each consuming repository symlinks the parts it adopts from `.claude-shared/`
into its own `.claude/`; the catalog itself auto-loads nothing.

## Layout

| Path | Contents |
| --- | --- |
| `rules/universal/` | Always-on rules (no `paths:` frontmatter) — collaboration rules and the code standards, with `.rationale.txt` sidecars |
| `rules/path-scoped/` | Rules with `paths:` frontmatter — injected only when matching files are touched |
| `skills/` | Skills, one folder per skill |
| `rule-testing/` | `replay-a-rule-change.py`, which replays a situation in fresh sessions under several versions of the rules, the replays it runs, and `todo.md`, what is still to build |
| `git-scripts/` | The scripts that attach the catalog to a checkout and keep it up to date, publish edits to it, verify the symlinks, and run at the start of a session |
| `git-scripts/copy-into-consuming-repository/` | The one file each consuming repository keeps its own copy of |

How the rules loader works — include order, the sidecar convention, what loads when — is documented in
[rules/path-scoped/rules-folder.md](rules/path-scoped/rules-folder.md).

## Adding to a repository

1. Ignore the catalog's checkout: add `/.claude-shared` to the repository's `.gitignore`.
2. Copy [git-scripts/copy-into-consuming-repository/attach-shared-claude-config.sessionstart-hook.sh](git-scripts/copy-into-consuming-repository/attach-shared-claude-config.sessionstart-hook.sh)
   to `.claude/attach-shared-claude-config.sessionstart-hook.sh`, and wire it as the repository's `SessionStart` hook
   (see [Verifying](#verifying)).
3. In the repository's `.gitattributes`, add `*.sh text eol=lf`, so the hook script keeps LF line endings on
   Windows checkouts — CRLF breaks it under `bash`.
4. Start a session, or run the hook by hand: `sh .claude/attach-shared-claude-config.sessionstart-hook.sh`. It
   attaches the catalog at `.claude-shared/`.
5. Symlink the parts the repository adopts into its `.claude/` (next section).

### New clones and worktrees of a consuming repository

Nothing to do: the first session started in one attaches the catalog, as a worktree of the machine clone on a branch
of the checkout's own, `checkout/` and the checkout's path. That session loaded its rules before the hook ran, so the
hook lists every always-on shared rule for the agent to read. A build that checks the symlinks before any session has
run, such as Compze's `C-Build`, says to run the hook by hand.

A machine with no machine clone, a new one or a cloud session, gets one from the repository's own hook, which clones
the catalog from GitHub.

## Selecting what a project adopts

Symlink the parts you want into the project's `.claude/`. Directory links by default — they carry the
`.rationale.txt` sidecars along; per-file links only where finer grain is genuinely needed. The link name is
project-local, so each project slots shared folders into its own numeric ordering scheme. A project that
adopts the code standards but not, say, the specification style simply doesn't create that link.

**For rules, make shared vs local visible in the names**: put the links behind `…-shared` entries — a
single `01-universal-shared` directory link for the universal rules, and a `01-shared/` folder of per-file
links for the adopted path-scoped rules. Rules discovery is recursive and frontmatter-gated, so such
grouping folders are pure organization. Project-local rules live alongside as regular files and folders, so
the split is obvious at a glance.

**Skills cannot be grouped, and the link folder's name IS the skill's name** (verified empirically):
discovery is one folder level deep, so a link inside `skills/01-shared/` is not found at session start —
and the *folder* name, not the SKILL.md frontmatter `name:`, becomes the name the skill registers and is
invoked under. So link each adopted skill flat, with a **`shared-` prefix on the link name**: the prefix is
the visible marker in the tree (IDEs don't reliably show symlink-ness) and deliberately becomes part of the
skill's name, marking it as shared at invocation time too. The catalog keeps canonical, unprefixed folder
names.

```powershell
New-Item -ItemType SymbolicLink .claude\rules\01-universal-shared -Target ..\..\.claude-shared\rules\universal
New-Item -ItemType SymbolicLink .claude\rules\path-scoped\01-shared\csharp-bdd-specifications.md -Target ..\..\..\..\.claude-shared\rules\path-scoped\csharp-bdd-specifications.md
New-Item -ItemType SymbolicLink .claude\skills\shared-team-review-and-fix-code-standard-issues -Target ..\..\.claude-shared\skills\team-review-and-fix-code-standard-issues
```

In the consuming repo's `.gitattributes`, mark committed **directory** symlinks with `symlink=dir` so Git
for Windows creates them correctly regardless of checkout order.

### Windows prerequisites (one-time per machine)

- Turn on **Developer Mode** (Settings > System > For developers) — symlink creation without elevation.
- `git config --global core.symlinks true` — without it, checkouts silently materialize committed symlinks
  as plain text files containing the target path, which Claude Code would load as garbage.

## Verifying

The verifier checks that every symlink the consuming repository's committed tree (HEAD) carries under
`.claude/` is a real, resolving symlink, and reports the broken ones otherwise — silent on success. Two
implementations of the same check:

- [git-scripts/verify-claude-symlinks.ps1](git-scripts/verify-claude-symlinks.ps1) — PowerShell, for Windows
  build/setup scripts (throws on failure).
- [git-scripts/verify-claude-symlinks.sh](git-scripts/verify-claude-symlinks.sh) — POSIX sh + git, no
  PowerShell dependency (exits non-zero with its message on stderr on failure).

Both report failures the build/CI way: non-zero exit + stderr. That is the wrong shape for a `SessionStart`
hook, which reaches the agent ONLY via stdout on exit 0 — stderr on a non-zero exit goes to the user, never
the agent, and cannot block the session. So the hook runs the verifier through an adapter:

- [git-scripts/sessionstart-hook.verify-claude-symlinks.sh](git-scripts/sessionstart-hook.verify-claude-symlinks.sh)
  — runs the `.sh` verifier and, on failure, re-emits its message on stdout (exit 0) so the warning actually
  lands in the agent's context at session start. It is a step of the catalog's session-start hook (see
  [At the start of a session](#at-the-start-of-a-session)).

Wire one into the consuming repo so a degraded checkout fails loudly:

- **Build/setup script** — call the `.ps1` (it throws on failure). If `.claude-shared/` may be missing at that
  point, check for that first and say so: the call itself would otherwise fail with a bare "file not found".
- **`SessionStart` hook** — catches a degraded checkout the moment a session starts, before the agent acts on
  garbage rules. The hook must work while the checkout has no catalog yet, and nothing stored inside the
  catalog can run then — so each consuming repository keeps its own copy of
  [git-scripts/copy-into-consuming-repository/attach-shared-claude-config.sessionstart-hook.sh](git-scripts/copy-into-consuming-repository/attach-shared-claude-config.sessionstart-hook.sh)
  at `.claude/attach-shared-claude-config.sessionstart-hook.sh`. It clones the machine clone when the machine
  has none, and hands over to the catalog's session-start hook, which attaches the catalog. Claude Code only merges settings from a
  project's own `.claude/settings.json` (never from `.claude-shared/`), so add it there. Keep it
  project-level, not user-level: a degraded checkout happens on fresh clones, cloud agents, and teammates,
  which user settings don't reach. Until 2026-11-19 the file was named
  `verify-shared-claude-config.sessionstart-hook.sh`. A copy under that name works as before, and the session start
  says to rename it.

  ```json
  "hooks": {
    "SessionStart": [
      { "hooks": [
          { "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/attach-shared-claude-config.sessionstart-hook.sh\"" }
      ] }
    ]
  }
  ```

  `bash` runs the hook via Git Bash on Windows and natively on Linux/macOS; the quoted `${CLAUDE_PROJECT_DIR}`
  path resolves in both (Claude Code expands the variable before spawning the shell).

## At the start of a session

The consuming repository's `SessionStart` hook (above) hands over to the machine clone's
[git-scripts/sessionstart-hook.sh](git-scripts/sessionstart-hook.sh), which is all the catalog does when a session
starts. It runs five steps, each of which tells the agent what it needs to know and says nothing when all is well:

1. **It attaches the catalog to the checkout**
   ([git-scripts/sessionstart-hook.attach-the-catalog.sh](git-scripts/sessionstart-hook.attach-the-catalog.sh)): when
   the checkout has no `.claude-shared/`, it makes one, a worktree of the machine clone on the checkout's own branch.
   When an earlier checkout at the same path left that branch, it is reused, with any commits of its own.
   - **The agent is given every always-on shared rule to read:** Claude Code loads the rules without waiting for the
     hook, so the session started without them.
   - **A `.claude-shared/` left from when the repository mounted the catalog as a git submodule** is left alone while
     the checkout's branch still mounts it so (see [below](#a-branch-that-still-mounts-the-catalog-as-a-submodule)).
     Once the branch no longer does, it is replaced by a worktree, unless it has work of its own, which is reported.
2. **It pulls the catalog when its upstream has commits the checkout lacks**
   ([git-scripts/sessionstart-hook.pull-when-behind.sh](git-scripts/sessionstart-hook.pull-when-behind.sh)): it
   fetches the upstream and, when behind, fast-forwards the checkout, and the machine clone along with it. Nothing is
   committed in the consuming repository.
   - **The agent is told which always-on rules changed, to read them:** the session may have them as they were
     before the pull.
   - **The pull is left alone, and reported as due,** when the checkout has work of its own in progress: uncommitted
     edits, or commits not published upstream.
   - **When the upstream can't be reached,** as when offline, the agent is told that the rules may be behind.
3. **It clears away what deleted checkouts left in the machine clone**
   ([git-scripts/sessionstart-hook.clean-up-after-deleted-checkouts.sh](git-scripts/sessionstart-hook.clean-up-after-deleted-checkouts.sh)):
   their worktrees' registrations, and their branches when upstream `main` has every commit on them.
   Leaving **Delete local branch** unchecked in Cloyd sets `branch.<name>.cloydKeep=true` in the machine clone and
   keeps that branch even after it is merged. A branch with
   commits that are not published is kept, and reported at every session start until someone publishes or deletes it.
4. **It verifies the `.claude/` symlinks** (the adapter under [Verifying](#verifying)).
5. **It says when the repository's own `SessionStart` hook is no longer the current one**
   ([git-scripts/sessionstart-hook.report-an-outdated-copy-of-the-repositorys-hook.sh](git-scripts/sessionstart-hook.report-an-outdated-copy-of-the-repositorys-hook.sh)):
   the repository keeps a copy of that file, so a change to it under `copy-into-consuming-repository/` reaches no
   repository by a pull. The agent is told to copy the current one over it and commit it.

Sessions started at once, as when they are all reloaded, fetch into the machine clone's one set of refs at the same
moment: a fetch that fails on a lock is retried.

Only the attach step runs from the machine clone, since the checkout may have no catalog yet; the other steps run from
the checkout's own `.claude-shared/`. So an edit to `sessionstart-hook.sh`, `sessionstart-hook.attach-the-catalog.sh`
or `catalog-checkouts.sh` in `~/.claude/.claude-shared` runs in every session start on the machine as soon as it is
saved: edit those in another checkout's worktree.

[git-scripts/sessionstart-hook.test.sh](git-scripts/sessionstart-hook.test.sh) runs the hook in scratch repositories
through each of those situations. Run it after changing the hook or the sync scripts.

## Syncing

Run from the consuming checkout. Each script prints the commits it brought in and published.

- **Pull upstream changes:** `sh .claude-shared/git-scripts/pull.sh`. It rebases the checkout's branch onto upstream
  `main`, with any commits of its own and uncommitted edits carried along.
- **Publish local edits:** `sh .claude-shared/git-scripts/push.sh --message "<what changed and why>"`. Or commit
  inside `.claude-shared/` yourself, one commit per change with its own message, and run `push.sh` without
  `--message`. It rebases the checkout's commits onto upstream `main`, and pushes them there.

Each checkout's branch is its own, but every push goes to upstream `main`. An edit left uncommitted is lost with its
checkout: removing a worktree of a consuming repository removes its catalog worktree too, edits and all, where a
submodule made `git worktree remove` refuse. A commit survives, on the checkout's branch in the machine clone.

## A branch that still mounts the catalog as a submodule

Until 2026-11-19 each consuming repository mounted the catalog as a git submodule, which recorded a commit of it. A
branch from before then still does, and its own copy of the hook runs the catalog's hook from its `.claude-shared/`,
the submodule's checkout. That checkout is kept up to date like any other, and git shows it as changed whenever it
moves past the commit the branch records: don't commit that. Once the branch takes `main`'s commit that removes the
submodule, the next session start replaces the submodule's checkout with a worktree of the machine clone. A checkout
whose `.claude-shared/` is already such a worktree, and which switches to such a branch, is told the same.

Once a checkout's branch no longer mounts it, its session start also removes what the submodule left in the git
folders: the submodule's section in the repository's git config, its repository in the checkout's own git folder, and
the `modules` folders left empty. With the section there, git takes the submodule for initialized on an old branch,
and `git submodule update` would check that branch's old commit out inside the catalog's worktree. While a linked
worktree's git folder has a `modules` folder, even an empty one, `git worktree remove` refuses. An old repository that
holds commits not published upstream is kept, and reported.

To remove the submodule from a branch by hand: `git rm --cached .claude-shared`, delete its section from
`.gitmodules` (or the file, when it has no other), ignore `/.claude-shared`, and commit the index as staged. Don't
commit by path naming `.claude-shared`: `git commit -- .claude-shared` stages the folder on disk again, as a gitlink to
the commit checked out in it, and so commits it moved, not removed.

## Why one clone per machine, and neither a submodule nor a git subtree

- **A git subtree** came first. Publishing from a consuming repository needs `git subtree split`, which walks the
  consuming repository's history recursively, one bash stack frame per commit. On Git for Windows it overflowed
  bash's fixed stack and crashed (segfault, exit 139) once enough of the catalog's history had been merged in, first
  in Compze and then in Deskmancer.
- **A git submodule** came next. It records the commit of the catalog that each commit of the consuming repository
  works with: right for a dependency the code has to match, and wrong for the rules agents work under now.
  - An old commit, another branch or a new worktree came with old rules: on 2026-11-19, the worktrees on other
    branches ran 29 commits behind.
  - Every pull of the catalog was a commit in every consuming repository: 15 to 31 a repository in the first 19 days
    of November 2026.
  - Each clone and worktree of a consuming repository had a clone of the catalog of its own, eleven on one machine,
    each to initialize, and to check for unpublished work.
- **One clone per machine, and a worktree of it in each checkout:** every checkout comes up to the latest at each
  session start, nothing is recorded in the consuming repositories, and a commit made in any checkout is in the
  machine clone. A worktree rather than a link to the one clone, because each checkout's edits in progress then stay
  in its own working tree, and because Claude Code treats a rules symlink that points outside the project as an
  external import, which each project has to approve.
