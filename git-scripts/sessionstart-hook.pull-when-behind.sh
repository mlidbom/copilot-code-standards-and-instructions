#!/bin/sh
# Session-start step: brings the shared Claude config here up to date when its upstream has commits it lacks.
#
# A consuming repository gets the catalog's changes only when someone pulls them into it. Left to that, a repository's
# sessions worked a day under rules 34 commits old (Deskmancer, 2026-11-14), such as a gate on pushing that the catalog
# had already dropped. So every session start fetches the catalog's upstream, and when the catalog here is behind it,
# runs pull.ps1: the catalog is updated, and its new pin is committed in the consuming repository, not pushed.
#
# The session that started this hook may have the rules as they were before the pull: Claude Code loads the rules
# without waiting for a SessionStart hook (tried 2026-11-15 with Claude Code 2.1.325: of four sessions whose hook
# rewrote a rule, three had the old text in their context). So the always-on rules that changed are listed for the
# agent to read. Path-scoped rules and skills are read from disk when they are used, which is after the pull.
#
# The pull is left alone, and reported as due, when it could be more than a fast-forward, or can't run:
#   - the catalog here has work of its own in progress: a branch other than main, uncommitted edits, or commits not
#     yet published upstream. Rebasing that with nobody watching could stop in a conflict;
#   - PowerShell 7, which pull.ps1 runs in, isn't on this machine.
# When the upstream can't be reached, as when the machine is offline, the agent is told that the rules may be behind.
#
# Everything is said on stdout with exit 0: the only way a SessionStart hook reaches the agent. Run by
# sessionstart-hook.sh.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
catalog=$(git -C "$dir" rev-parse --show-toplevel)

fetch_the_upstream() {
   # No prompt for credentials: nobody is there to answer one. Bounded where `timeout` exists (Git Bash, Linux), so a
   # connection that hangs doesn't hold up the session's start.
   if command -v timeout >/dev/null 2>&1; then
      GIT_TERMINAL_PROMPT=0 timeout 20 git -C "$catalog" fetch --quiet origin
   else
      GIT_TERMINAL_PROMPT=0 git -C "$catalog" fetch --quiet origin
   fi
}

count_of_commits_the_upstream_has_and_the_catalog_here_lacks() {
   git -C "$catalog" rev-list --count HEAD..origin/main
}

# Prints what work of its own the catalog here has in progress, or nothing when it has none.
work_of_its_own_in_progress() {
   branch=$(git -C "$catalog" symbolic-ref --quiet --short HEAD)
   if [ -n "$branch" ] && [ "$branch" != main ]; then
      echo "it is on the branch '$branch', not on main"
   elif [ -n "$(git -C "$catalog" status --porcelain)" ]; then
      echo 'it has uncommitted edits'
   elif [ "$(git -C "$catalog" rev-list --count origin/main..HEAD)" -gt 0 ]; then
      echo 'it has commits that are not published upstream'
   fi
}

# Prints the always-on rules that the pull from the commit $1 changed in the way $2 names (a git diff filter), one
# path a line, relative to the catalog.
always_on_rules_the_pull_changed() {
   git -C "$catalog" diff --name-only --diff-filter="$2" "$1" HEAD -- rules/universal | grep '\.md$'
}

if ! fetch_the_upstream >/dev/null 2>&1; then
   echo 'The shared rules and skills in .claude-shared could not be compared with their upstream: fetching it failed, as it does when the machine is offline. They may be behind it.'
   exit 0
fi

commit_count=$(count_of_commits_the_upstream_has_and_the_catalog_here_lacks)
[ "$commit_count" -gt 0 ] || exit 0
if [ "$commit_count" -eq 1 ]; then behind='1 commit behind'; else behind="$commit_count commits behind"; fi
are_behind="The shared rules and skills in .claude-shared are $behind their upstream"

in_progress=$(work_of_its_own_in_progress)
if [ -n "$in_progress" ]; then
   echo "$are_behind, and were not pulled, because the catalog here has work of its own in progress: $in_progress. The rules in this session are the older ones. Pull once that work is published, or under it now: .claude-shared/git-scripts/pull.ps1"
   exit 0
fi

if ! command -v pwsh >/dev/null 2>&1; then
   echo "$are_behind, and were not pulled: pull.ps1 runs in PowerShell 7 (pwsh), which isn't on this machine. The rules in this session are the older ones."
   exit 0
fi

before_the_pull=$(git -C "$catalog" rev-parse HEAD)
# A pull that fails while the catalog comes up to date all the same lost to another session's hook pulling at the same
# moment: the catalog is then as this pull would have left it.
if ! what_the_pull_said=$(pwsh -NoProfile -File "$dir/pull.ps1" 2>&1) && [ "$(count_of_commits_the_upstream_has_and_the_catalog_here_lacks)" -gt 0 ]; then
   printf '%s\n%s\n' "$are_behind, and pulling them failed. The rules in this session are the older ones. Tell Magnus, with what the pull said:" "$what_the_pull_said"
   exit 0
fi

echo "The shared rules and skills in .claude-shared were $behind their upstream, and have now been pulled. Their new pin is committed in this repository, and not pushed."

added_or_changed=$(always_on_rules_the_pull_changed "$before_the_pull" AMR)
removed=$(always_on_rules_the_pull_changed "$before_the_pull" D)
if [ -n "$added_or_changed" ]; then
   echo 'The rules in your context may be the ones from before the pull. These always-on rules were added or changed: read each of them now, as it stands.'
   echo "$added_or_changed" | while IFS= read -r rule; do printf '  %s/%s\n' "$catalog" "$rule"; done
fi
if [ -n "$removed" ]; then
   echo 'These always-on rules were removed, and no longer apply:'
   echo "$removed" | while IFS= read -r rule; do printf '  %s\n' "$rule"; done
fi
if [ -z "$added_or_changed$removed" ]; then
   echo 'No always-on rule changed.'
fi

echo 'What came in:'
git -C "$catalog" log --reverse --format='  %h %s' "$before_the_pull..HEAD"
