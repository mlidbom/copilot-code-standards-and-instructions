#!/bin/sh
# Kept for the consuming repositories whose copy of the SessionStart hook was made before 2026-11-15: that copy hands
# over to this file by name. The catalog's session-start hook is sessionstart-hook.sh, which this runs, so those
# repositories get all of it. The step that verifies the symlinks, which this file used to be, is
# sessionstart-hook.verify-claude-symlinks.sh.
#
# todo: delete this file once every consuming repository's .claude/verify-shared-claude-config.sessionstart-hook.sh
#    hands over to sessionstart-hook.sh, as the copy under copy-into-consuming-repository/ does (Claude, 2026-11-15).
#    A repository whose copy is older is told so at each session start, by
#    sessionstart-hook.report-an-outdated-copy-of-the-repositorys-hook.sh.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "$dir/sessionstart-hook.sh"
