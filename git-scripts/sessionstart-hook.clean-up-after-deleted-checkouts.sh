#!/bin/sh
# Session-start step: clears away what deleted checkouts left in the machine clone (catalog-checkouts.sh).
#
# A consuming checkout that is deleted, as agents' worktrees under .claude/worktrees are all the time, leaves its
# catalog worktree registered in the machine clone, and its branch there. The registration is pruned. The branch is
# deleted when upstream main has every commit on it. Otherwise its commits are the one thing of value a deleted
# checkout can leave, so the branch is kept, and reported at every session start until someone publishes or deletes
# it.
#
# Everything is said on stdout with exit 0: the only way a SessionStart hook reaches the agent. Run by
# sessionstart-hook.sh.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/catalog-checkouts.sh"
is_a_checkout_of_its_own "$machine_clone" || exit 0

branches_checked_out() {
   git -C "$machine_clone" worktree list --porcelain | sed -n 's|^branch refs/heads/||p'
}

# The hooks of sessions started at once prune and delete at the same moment, and all but one may fail on a lock or
# find the work done: whichever does it, it is done, and what is left is done at the next session start.
git -C "$machine_clone" worktree prune >/dev/null 2>&1
checked_out=$(branches_checked_out)
git -C "$machine_clone" for-each-ref --format='%(refname:short)' refs/heads/checkout/ | while IFS= read -r branch; do
   printf '%s\n' "$checked_out" | grep -qxF "$branch" && continue
   unpublished=$(git -C "$machine_clone" rev-list --count "$branch" --not origin/main)
   if [ "$unpublished" -eq 0 ]; then
      git -C "$machine_clone" branch --quiet --delete --force "$branch" >/dev/null 2>&1
   else
      echo "The machine's clone of the shared Claude config, $machine_clone, has the branch $branch, left by a checkout that no longer exists, with $unpublished commit(s) that are not published upstream. Publish them, or delete the branch if they aren't wanted. They are: git -C $machine_clone log origin/main..$branch"
   fi
done
