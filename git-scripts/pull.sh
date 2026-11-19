#!/bin/sh
# Brings the checkout of the shared Claude config that this file is in up to date with its upstream: rebases its
# branch onto upstream main, with any commits of its own and uncommitted edits carried along, and prints the upstream
# commits that came in. Run it before editing the catalog, from the consuming checkout:
#
#    sh .claude-shared/git-scripts/pull.sh
#
# The session-start hook does the same when the checkout has no work of its own in progress.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/catalog-checkouts.sh"
catalog=$(git -C "$dir" rev-parse --show-toplevel)

if ! fetch_the_upstream_into "$catalog"; then
   echo "Fetching the upstream of the shared Claude config at $catalog failed: $what_git_said" >&2
   exit 1
fi
before_the_pull=$(git -C "$catalog" rev-parse HEAD)
git -C "$catalog" rebase --quiet --autostash origin/main
print_the_commits 'Received from upstream:' "$catalog" "$before_the_pull..origin/main" 'Nothing new upstream.'
