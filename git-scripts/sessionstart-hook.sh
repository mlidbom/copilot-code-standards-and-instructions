#!/bin/sh
# What the shared Claude config does when a session starts in a checkout that consumes it: it attaches the catalog to
# the checkout, brings it up to date with its upstream, clears away what deleted checkouts left in the machine clone,
# verifies the checkout's .claude/ symlinks into the catalog, and compares the checkout's own SessionStart hook with
# the current one. Each step tells the agent what it needs to know, on stdout, and says nothing when all is well.
#
# The consuming checkout's own SessionStart hook (see copy-into-consuming-repository/) runs this from the machine
# clone (catalog-checkouts.sh), with the checkout's root as $1. A copy of that hook from before the catalog was a
# worktree of the machine clone runs this from the checkout's own .claude-shared, with no argument: the consuming
# checkout is then the folder that .claude-shared is in.
#
# The steps are run through sh, not executed directly, so they work whether or not the checkout kept their
# executable bit.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
consuming_checkout=${1:-$(dirname -- "$(git -C "$dir" rev-parse --show-toplevel)")}
sh "$dir/sessionstart-hook.attach-the-catalog.sh" "$consuming_checkout"
sh "$dir/sessionstart-hook.pull-when-behind.sh" "$consuming_checkout"
sh "$dir/sessionstart-hook.clean-up-after-deleted-checkouts.sh"
sh "$dir/sessionstart-hook.verify-claude-symlinks.sh" "$consuming_checkout"
sh "$dir/sessionstart-hook.report-an-outdated-copy-of-the-repositorys-hook.sh" "$consuming_checkout"
