#!/bin/sh
# What the shared Claude config does when a session starts in a repository that mounts it: it brings itself up to date
# with its upstream, verifies the repository's .claude/ symlinks into it, and compares the repository's own
# SessionStart hook with the current one. Each step tells the agent what it needs to know, on stdout, and says nothing
# when all is well.
#
# The consuming repository's own SessionStart hook hands over to this once it has confirmed that the catalog submodule
# is initialized (see copy-into-consuming-repository/). The steps are run through sh, not executed directly, so they
# work whether or not the checkout kept their executable bit.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$dir/sessionstart-hook.pull-when-behind.sh"
sh "$dir/sessionstart-hook.verify-claude-symlinks.sh"
sh "$dir/sessionstart-hook.report-an-outdated-copy-of-the-repositorys-hook.sh"
