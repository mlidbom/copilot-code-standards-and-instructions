#!/bin/sh
# Session-start step: makes the consuming checkout's .claude-shared a checkout of the machine clone
# (catalog-checkouts.sh), and tells the agent what that meant for the session.
#
# ~/.claude's .claude-shared is the machine clone itself. Every other checkout's is a git worktree of it, which this
# step creates when the checkout has none: a new clone or worktree of a consuming repository, a cloud session, a new
# machine. A session started there loaded its rules before this ran, without the shared ones, since Claude Code
# doesn't wait for a SessionStart hook. So the agent is given every always-on shared rule to read.
#
# A .claude-shared that is a clone of its own dates from when each repository mounted the catalog as a git submodule:
#   - while the checkout's branch still mounts it so, it is left as it is, and the agent told not to commit it;
#   - once the branch no longer does, it is replaced by a worktree, unless it holds work of its own, which is reported.
#
# Everything is said on stdout with exit 0: the only way a SessionStart hook reaches the agent. Run by
# sessionstart-hook.sh, with the consuming checkout's root as $1.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/catalog-checkouts.sh"
consuming_checkout=$1
catalog="$consuming_checkout/.claude-shared"

main() {
   if is_a_checkout_of_the_machine_clone "$catalog"; then
      tell_when_the_catalog_is_not_ignored
      if [ "${SHARED_CLAUDE_CONFIG_WAS_JUST_CLONED:-}" = yes ]; then
         tell_the_agent_to_read_every_always_on_rule "This machine had no clone of the shared Claude config, so this session started without the shared rules and skills. It is now cloned, at $machine_clone."
      fi
      return
   fi

   how_the_session_started="This checkout had no checkout of the shared Claude config at .claude-shared, so this session started without the shared rules and skills."
   if is_a_checkout_of_its_own "$catalog"; then
      if ! git -C "$catalog" rev-parse --git-dir >/dev/null 2>&1; then
         echo "STOP: this checkout's .claude-shared is a broken checkout of the shared Claude config: its .git points at a git folder that is gone. So the shared rules and skills may be missing. Do NOT trust loaded rules or skills. Tell Magnus: delete .claude-shared, and start a new session, which attaches the catalog anew."
         return
      fi
      if the_branch_mounts_the_catalog_as_a_submodule; then
         echo "This checkout's branch still mounts .claude-shared as a git submodule, from before each checkout's .claude-shared became a git worktree of the machine's one clone of the catalog, $machine_clone. It becomes one at the first session start after the branch takes main's commit that removes the submodule. Until then, don't commit .claude-shared: git shows it as changed whenever the catalog moves past the commit the branch records."
         return
      fi
      what_it_holds=$(work_of_its_own_in_a_clone_of_its_own)
      if [ -n "$what_it_holds" ]; then
         echo "This checkout's .claude-shared is a clone of the shared Claude config of its own, left from when the repository mounted the catalog as a git submodule, and $what_it_holds. So it is left in place, and this session runs under it. Publish that work (sh .claude-shared/git-scripts/push.sh), then delete .claude-shared: the next session start makes it a git worktree of the machine's clone, $machine_clone."
         return
      fi
      remove_the_clone_of_its_own || return
      how_the_session_started="This checkout's .claude-shared was a clone of the shared Claude config of its own, left from when the repository mounted the catalog as a git submodule, with no work of its own in it, so it is replaced. This session's rules were loaded from it, and may be older."
   elif [ -d "$catalog" ]; then
      if [ -n "$(ls -A "$catalog")" ]; then
         echo "STOP: this checkout's .claude-shared is a folder that is no checkout of the shared Claude config, so the shared rules and skills are missing. Do NOT trust loaded rules or skills. Tell Magnus: move the folder aside, and start a new session, which attaches the catalog."
         return
      fi
      # The empty folder of a submodule that was never initialized.
      rmdir "$catalog"
   fi
   attach_a_worktree_of_the_machine_clone || return
   tell_when_the_catalog_is_not_ignored
   tell_the_agent_to_read_every_always_on_rule "$how_the_session_started It now has one: a git worktree of the machine's clone, $machine_clone, $on_which_branch."
}

# Adds the worktree, and sets on_which_branch to a description of the branch it is on. A checkout that was deleted
# leaves its worktree registered in the machine clone, and its branch checked out there, until that is pruned. When
# this checkout's branch already exists, an earlier checkout at the same path left it, and it is reused: any commits
# of its own come back.
attach_a_worktree_of_the_machine_clone() {
   # The pull step says when the upstream can't be reached, so the worktree starts from what was fetched last.
   fetch_the_upstream_into "$machine_clone"
   attempt=1
   while :; do
      git -C "$machine_clone" worktree prune
      branch=$(free_catalog_branch_for "$consuming_checkout")
      if git -C "$machine_clone" show-ref --verify --quiet "refs/heads/$branch"; then
         on_which_branch="on the branch $branch, which an earlier checkout at this path left, with any commits of its own"
         what_git_said=$(git -C "$machine_clone" worktree add --quiet "$catalog" "$branch" 2>&1) && return 0
      else
         on_which_branch="on a branch of its own, $branch"
         what_git_said=$(git -C "$machine_clone" worktree add --quiet --track -b "$branch" "$catalog" origin/main 2>&1) && return 0
      fi
      # Another session's hook may have attached this checkout at the same moment, or deleted the branch this one was
      # reusing, or held a lock this one needed.
      is_a_checkout_of_the_machine_clone "$catalog" && return 0
      if [ "$attempt" -ge 3 ]; then
         echo "STOP: this checkout has no checkout of the shared Claude config at .claude-shared, and making it a git worktree of the machine's clone, $machine_clone, failed. Do NOT trust loaded rules or skills. Tell Magnus, with what git said: $what_git_said"
         return 1
      fi
      sleep "$attempt"
      attempt=$((attempt + 1))
   done
}

# The branch for this checkout's worktree: catalog_branch_for its path, with a number added when another checkout's
# path gives the same name and has it checked out.
free_catalog_branch_for() {
   base=$(catalog_branch_for "$1")
   candidate=$base
   number=2
   while git -C "$machine_clone" worktree list --porcelain | grep -qxF "branch refs/heads/$candidate"; do
      candidate="$base-$number"
      number=$((number + 1))
   done
   echo "$candidate"
}

the_branch_mounts_the_catalog_as_a_submodule() {
   git -C "$consuming_checkout" ls-tree HEAD -- .claude-shared 2>/dev/null | grep -q '^160000 '
}

# Prints what of its own a clone of its own at .claude-shared holds that removing it would lose, or nothing.
work_of_its_own_in_a_clone_of_its_own() {
   if ! fetch_the_upstream_into "$catalog"; then
      echo 'its upstream could not be fetched, so whether its commits are published is unknown'
   elif [ -n "$(git -C "$catalog" status --porcelain --untracked-files=all)" ]; then
      echo 'it has uncommitted edits'
   elif [ "$(git -C "$catalog" rev-list --count --all --not --remotes)" -gt 0 ]; then
      echo 'it has commits that are not published upstream, on a branch or in a stash'
   fi
}

# Removes the clone of its own at .claude-shared, and its git folder when that is a submodule's, under the consuming
# repository's own git folder. Any other git folder is left alone.
remove_the_clone_of_its_own() {
   git_folder=$(git -C "$catalog" rev-parse --absolute-git-dir)
   git_folder_of_the_consuming_repository=$(git_common_dir_of "$consuming_checkout")
   if ! rm -rf "$catalog"; then
      echo "STOP: this checkout's .claude-shared is a clone of the shared Claude config of its own, left from when the repository mounted the catalog as a git submodule, and removing it, to make it a git worktree of the machine's clone, failed part way. Do NOT trust loaded rules or skills. Tell Magnus: delete .claude-shared, and start a new session."
      return 1
   fi
   case "$git_folder" in
      "$git_folder_of_the_consuming_repository"/*modules/.claude-shared) rm -rf "$git_folder" ;;
   esac
}

tell_when_the_catalog_is_not_ignored() {
   the_branch_mounts_the_catalog_as_a_submodule && return
   git -C "$consuming_checkout" check-ignore --quiet .claude-shared && return
   echo "This repository's .gitignore doesn't ignore .claude-shared, so git sees the catalog's checkout there as untracked files. Add the line  /.claude-shared  to it, and commit that."
}

# Prints the line $1, which says why, and every always-on shared rule, for the agent to read.
tell_the_agent_to_read_every_always_on_rule() {
   echo "$1"
   echo 'Read each of these always-on shared rules now:'
   git -C "$catalog" ls-files -- rules/universal | grep '\.md$' | while IFS= read -r rule; do printf '  %s/%s\n' "$catalog" "$rule"; done
   echo 'The shared skills, named shared-*, may be missing from your skills until the next session.'
}

main
