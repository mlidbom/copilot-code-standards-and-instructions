# What the catalog's scripts share: where the catalog is checked out on a machine, and what they ask of a checkout of
# it. Sourced by them, not run.
#
# Each machine has one clone of the catalog, the machine clone, at ~/.claude/.claude-shared: ~/.claude's own
# .claude-shared, on main. Every other checkout that consumes the catalog has its .claude-shared as a git worktree of
# the machine clone, on a branch of its own (catalog_branch_for). So the machine has one object store and one set of
# branches: one fetch brings the upstream to every checkout, and a commit made in any checkout is in the machine clone,
# where it outlives the checkout. Nothing in a consuming repository records a commit of the catalog: each checkout is
# brought up to date with the upstream at the start of each session.

machine_clone="$HOME/.claude/.claude-shared"
# In the form git gives paths in, which every shell and tool on the machine takes: on Windows C:/..., where the shell
# this runs in would say /c/... (pwd -W is Git Bash's; elsewhere the path is the same either way).
[ -d "$machine_clone" ] && machine_clone=$(cd "$machine_clone" && { pwd -W 2>/dev/null || pwd; })

# The branch the checkout of the catalog in the consuming checkout $1 is on: checkout/ and the checkout's path, every
# character but a letter or a digit made a dash, as Claude Code names its project folders, so that two checkouts
# with the same folder name don't collide. The path is git's, such as C:/Dev/Deskmancer: checkout/C--Dev-Deskmancer.
# A dash stands in for the slashes too, since a branch can't be both a branch and a folder of branches: that of
# C:/Dev/Deskmancer/.claude/worktrees/x could otherwise not exist beside that of C:/Dev/Deskmancer.
catalog_branch_for() {
   echo "checkout/$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '-' | sed 's/^-*//')"
}

# The git folder shared by every worktree of the repository that the checkout $1 belongs to, or nothing when $1 is no
# checkout. Two checkouts are of the same clone when theirs are the same.
git_common_dir_of() {
   git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

# Whether the folder $1 is a checkout of its own: git, asked in a folder that isn't one, would answer for the
# repository around it.
is_a_checkout_of_its_own() {
   [ -e "$1/.git" ]
}

# Whether the folder $1 is the machine clone or one of its worktrees.
is_a_checkout_of_the_machine_clone() {
   is_a_checkout_of_its_own "$1" && is_a_checkout_of_its_own "$machine_clone" &&
      [ "$(git_common_dir_of "$1")" = "$(git_common_dir_of "$machine_clone")" ]
}

# Fetches the upstream into the checkout $1 of the catalog. Fails when it can't be reached. No prompt for
# credentials: nobody is there to answer one. Bounded where `timeout` exists (Git Bash, Linux), so a connection that
# hangs doesn't hold up a session's start.
#
# Every checkout of the machine clone shares its refs, so the hooks of sessions started at once, such as by reloading
# them all, fetch into the same refs at the same moment, and all but one fail on a lock. A failure on a lock is
# retried, after a pause that grows; any other failure is the upstream out of reach.
fetch_the_upstream_into() {
   attempt=1
   while :; do
      if what_git_said=$(GIT_TERMINAL_PROMPT=0 bounded 20 git -C "$1" fetch --quiet origin 2>&1); then
         return 0
      fi
      case "$what_git_said" in
         *lock*) [ "$attempt" -lt 6 ] || return 1 ;;
         *) return 1 ;;
      esac
      sleep "$attempt"
      attempt=$((attempt + 1))
   done
}

# Runs the command after $1, stopping it after $1 seconds where `timeout` exists.
bounded() {
   seconds=$1
   shift
   if command -v timeout >/dev/null 2>&1; then
      timeout "$seconds" "$@"
   else
      "$@"
   fi
}

# Prints what work of its own the checkout $1 of the catalog has in progress, or nothing when it has none: what a pull
# with nobody watching must leave alone, since rebasing it could stop in a conflict.
work_of_its_own_in_progress() {
   if [ -n "$(git -C "$1" status --porcelain)" ]; then
      echo 'it has uncommitted edits'
   elif [ "$(git -C "$1" rev-list --count origin/main..HEAD)" -gt 0 ]; then
      echo 'it has commits that are not published upstream'
   fi
}

# Prints the heading $1 and the commits of the range $3 in the checkout $2, oldest first, as "<hash> <subject>" lines,
# or the line $4 when there are none.
print_the_commits() {
   commits=$(git -C "$2" log --reverse --format='  %h %s' "$3")
   if [ -z "$commits" ]; then
      echo "$4"
      return
   fi
   echo "$1"
   echo "$commits"
}
