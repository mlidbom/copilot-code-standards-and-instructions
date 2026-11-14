#!/bin/sh
# Session-start step: tells the agent when the consuming repository's own SessionStart hook is no longer the catalog's
# current one, and how to replace it.
#
# Each consuming repository keeps its own copy of copy-into-consuming-repository/verify-shared-claude-config.sessionstart-hook.sh
# in its .claude/ folder, since that file has to work while the catalog submodule is still empty. So a change to the
# file reaches no repository by a pull: without this step nothing said that a copy was old, and the catalog had to go
# on answering to whatever an old copy asked of it (2026-11-15: a script's old name, kept as a hand-over).
#
# A copy that differs in any byte is reported. A repository without the file at that path has wired its hook some
# other way, and is told nothing.
#
# Everything is said on stdout with exit 0: the only way a SessionStart hook reaches the agent. Run by
# sessionstart-hook.sh.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# The paths are asked of git, which gives them in a form that every shell on the machine takes: on Windows C:/..., where
# the shell this runs in would say /c/...
catalog=$(git -C "$dir" rev-parse --show-toplevel)
consuming_repository=$(git -C "$dir" rev-parse --show-superproject-working-tree)
name_of_the_hook='verify-shared-claude-config.sessionstart-hook.sh'
the_current_one="$catalog/git-scripts/copy-into-consuming-repository/$name_of_the_hook"
the_copy_of_the_repository="$consuming_repository/.claude/$name_of_the_hook"

[ -f "$the_copy_of_the_repository" ] || exit 0
cmp -s "$the_current_one" "$the_copy_of_the_repository" && exit 0

echo "This repository's own SessionStart hook, .claude/$name_of_the_hook, is no longer the shared Claude config's current one. Replace it: copy $the_current_one over it, and commit that file by itself."
