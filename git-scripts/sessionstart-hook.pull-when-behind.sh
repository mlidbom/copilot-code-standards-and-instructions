#!/bin/sh
# Session-start step: brings the consuming checkout's .claude-shared up to date when its upstream has commits it lacks.
#
# A checkout gets the catalog's changes only when someone pulls them into it. Left to that, a repository's sessions
# worked a day under rules 34 commits old (Deskmancer, 2026-11-14), such as a gate on pushing that the catalog had
# already dropped. So every session start fetches the catalog's upstream, and when the checkout is behind it,
# fast-forwards it. Nothing is committed in the consuming repository: it records no commit of the catalog.
#
# The machine clone is fast-forwarded along with it, quietly, when it has no work of its own in progress. This
# session's hook ran its scripts, and the next session's runs them too.
#
# The session that started this hook may have the rules as they were before the pull: Claude Code loads the rules
# without waiting for a SessionStart hook (tried 2026-11-15 with Claude Code 2.1.325: of four sessions whose hook
# rewrote a rule, three had the old text in their context). So the always-on rules that changed are listed for the
# agent to read. Path-scoped rules and skills are read from disk when they are used, which is after the pull.
#
# The pull is left alone, and reported as due, when the checkout has work of its own in progress: uncommitted edits,
# or commits not yet published upstream. Rebasing that with nobody watching could stop in a conflict. When the
# upstream can't be reached, as when the machine is offline, the agent is told that the rules may be behind.
#
# Everything is said on stdout with exit 0: the only way a SessionStart hook reaches the agent. Run by
# sessionstart-hook.sh, with the consuming checkout's root as $1.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/catalog-checkouts.sh"
catalog="$1/.claude-shared"

count_of_commits_the_upstream_has_and_the_catalog_here_lacks() {
   git -C "$catalog" rev-list --count HEAD..origin/main
}

# Prints the always-on rules that the pull from the commit $1 changed in the way $2 names (a git diff filter), one
# path a line, relative to the catalog.
always_on_rules_the_pull_changed() {
   git -C "$catalog" diff --name-only --diff-filter="$2" "$1" HEAD -- rules/universal | grep '\.md$'
}

bring_the_machine_clone_up_to_date_quietly() {
   is_a_worktree_of_the_machine_clone || return
   [ -z "$(work_of_its_own_in_progress "$machine_clone")" ] || return
   # Another session's hook may be fast-forwarding it at the same moment: then it comes up to date all the same.
   git -C "$machine_clone" merge --ff-only --quiet origin/main >/dev/null 2>&1
}

# Whether the catalog here is a worktree of the machine clone, not the machine clone itself, which is ~/.claude's.
is_a_worktree_of_the_machine_clone() {
   is_a_checkout_of_the_machine_clone "$catalog" &&
      [ "$(git -C "$catalog" rev-parse --show-toplevel)" != "$(git -C "$machine_clone" rev-parse --show-toplevel)" ]
}

# The attach step has said why the checkout has no catalog.
is_a_checkout_of_its_own "$catalog" || exit 0

if ! fetch_the_upstream_into "$catalog"; then
   echo 'The shared rules and skills in .claude-shared could not be compared with their upstream: fetching it failed, as it does when the machine is offline. They may be behind it.'
   exit 0
fi
bring_the_machine_clone_up_to_date_quietly

commit_count=$(count_of_commits_the_upstream_has_and_the_catalog_here_lacks)
[ "$commit_count" -gt 0 ] || exit 0
if [ "$commit_count" -eq 1 ]; then behind='1 commit behind'; else behind="$commit_count commits behind"; fi
are_behind="The shared rules and skills in .claude-shared are $behind their upstream"

in_progress=$(work_of_its_own_in_progress "$catalog")
if [ -n "$in_progress" ]; then
   echo "$are_behind, and were not pulled, because the catalog here has work of its own in progress: $in_progress. The rules in this session are the older ones. Pull once that work is published, or under it now: sh .claude-shared/git-scripts/pull.sh"
   exit 0
fi

before_the_pull=$(git -C "$catalog" rev-parse HEAD)
# A pull that fails while the catalog comes up to date all the same lost to another session's hook pulling the same
# checkout at the same moment: the catalog is then as this pull would have left it.
if ! what_the_pull_said=$(git -C "$catalog" merge --ff-only --quiet origin/main 2>&1) && [ "$(count_of_commits_the_upstream_has_and_the_catalog_here_lacks)" -gt 0 ]; then
   printf '%s\n%s\n' "$are_behind, and pulling them failed. The rules in this session are the older ones. Tell Magnus, with what the pull said:" "$what_the_pull_said"
   exit 0
fi

echo "The shared rules and skills in .claude-shared were $behind their upstream, and have now been pulled."

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
