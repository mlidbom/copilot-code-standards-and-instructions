# Shared Claude Code configuration

Shared Claude Code configuration — rules, skills, and the scripts to manage them — designed to live at
`.claude-shared/` in any repository, mounted as a **git submodule**. Each consuming repository symlinks the
parts it adopts from `.claude-shared/` into its own `.claude/`; the catalog itself auto-loads nothing.

## Layout

| Path | Contents |
| --- | --- |
| `rules/universal/` | Always-on rules (no `paths:` frontmatter) — collaboration rules and the code standards, with `.rationale.txt` sidecars |
| `rules/path-scoped/` | Rules with `paths:` frontmatter — injected only when matching files are touched |
| `skills/` | Skills, one folder per skill |
| `git-scripts/` | Submodule sync and symlink verification scripts |
| `git-scripts/copy-into-consuming-repository/` | The one file each consuming repository keeps its own copy of |

How the rules loader works — include order, the sidecar convention, what loads when — is documented in
[rules/path-scoped/rules-folder.md](rules/path-scoped/rules-folder.md).

## Adding to a repository

From the repository root:

```powershell
git submodule add -b main https://github.com/mlidbom/copilot-code-standards-and-instructions.git .claude-shared
```

`-b main` records `branch = main` in `.gitmodules`, which the sync scripts follow. Then:

1. Symlink the parts the repository adopts into its `.claude/` (next section).
2. Wire the verification hook (see [Verifying](#verifying)).
3. In the repository's `.gitattributes`, add `*.sh text eol=lf`, so the hook script keeps LF line endings on
   Windows checkouts — CRLF breaks it under `bash`.

### Cloning a consuming repository, and new worktrees

Clone with `--recurse-submodules`, or run `git submodule update --init` afterwards. The same goes for every new
`git worktree`: each worktree has its own submodule checkout and starts empty. Until then `.claude-shared/` is
empty and every `.claude/` symlink into it dangles — the verification hook says so at session start.

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
the agent, and cannot block the session. So the hook is wired through an adapter:

- [git-scripts/verify-claude-symlinks.sessionstart-hook.sh](git-scripts/verify-claude-symlinks.sessionstart-hook.sh)
  — runs the `.sh` verifier and, on failure, re-emits its message on stdout (exit 0) so the warning actually
  lands in the agent's context at session start.

Wire one into the consuming repo so a degraded checkout fails loudly:

- **Build/setup script** — call the `.ps1` (it throws on failure). If `.claude-shared/` may be empty at that
  point, check for that first and say so: the call itself would otherwise fail with a bare "file not found".
- **`SessionStart` hook** — catches a degraded checkout the moment a session starts, before the agent acts on
  garbage rules. The hook must work even when the submodule is empty, and nothing stored inside an empty
  submodule can run — so each consuming repository keeps its own copy of
  [git-scripts/copy-into-consuming-repository/verify-shared-claude-config.sessionstart-hook.sh](git-scripts/copy-into-consuming-repository/verify-shared-claude-config.sessionstart-hook.sh)
  at `.claude/verify-shared-claude-config.sessionstart-hook.sh`. It reports an uninitialized submodule
  itself, and otherwise hands over to the catalog's adapter. Claude Code only merges settings from a
  project's own `.claude/settings.json` (never from `.claude-shared/`), so add it there. Keep it
  project-level, not user-level: a degraded checkout happens on fresh clones, cloud agents, and teammates,
  which user settings don't reach.

  ```json
  "hooks": {
    "SessionStart": [
      { "hooks": [
          { "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/verify-shared-claude-config.sessionstart-hook.sh\"" }
      ] }
    ]
  }
  ```

  `bash` runs the hook via Git Bash on Windows and natively on Linux/macOS; the quoted `${CLAUDE_PROJECT_DIR}`
  path resolves in both (Claude Code expands the variable before spawning the shell).

## Syncing

Run from anywhere in the consuming repository. Each script prints the commits it brought in and published,
and commits the catalog's new commit as the consuming repository's pin of it — that commit contains only
the pin, and its message lists the catalog commits it brings in.

- **Pull upstream changes:** `.claude-shared/git-scripts/pull.ps1`
- **Publish local edits:** `.claude-shared/git-scripts/push.ps1 -Message "<why this change>"`. Or commit
  inside `.claude-shared/` yourself, one commit per change with its own message, and run `push.ps1`
  without `-Message`.

Both scripts first put the submodule on its `main` branch — a fresh clone or worktree checks a submodule out
on no branch, where a commit could not be pushed as `main` — and then rebase local work onto upstream `main`,
so a push fast-forwards over whatever the other consuming repositories published. Neither pins a catalog
commit that is not published upstream, since other clones of the consuming repository could not fetch it:
while local catalog commits are unpublished, `pull.ps1` leaves the pin alone and says so.

## Switching to a branch that predates the submodule

A repository that used to carry the catalog as a git subtree has older branches where `.claude-shared/` is
an ordinary folder. Checking such a branch out from one where it is a submodule fails — even with
`--recurse-submodules` — with "untracked working tree files would be overwritten". Remove the submodule's
checkout first:

```powershell
git submodule deinit -f .claude-shared
Remove-Item -Recurse -Force .claude-shared
git switch <older-branch>
```

The other direction just works: switch, then `git submodule update --init`. So does merging `main` into an
older branch, which is what ends the problem for that branch.

## Why a submodule and not a git subtree

The catalog used to be a git subtree. Publishing from a consuming repository needs `git subtree split`, which
walks the consuming repository's history recursively, one bash stack frame per commit. On Git for Windows it
overflowed bash's fixed stack and crashed (segfault, exit 139) once enough of the catalog's history had been
merged in, first in Compze and then in Deskmancer. A submodule is an ordinary clone of this repository:
publishing is a plain commit and push, and the catalog's history stays out of the consuming repositories'
history.
