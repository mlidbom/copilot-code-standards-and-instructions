#!/bin/sh
# Publishes the edits made in the checkout of the shared Claude config that this file is in: commits its uncommitted
# edits with the message given by --message, rebases its commits onto upstream main, and pushes them there. Prints
# what came in from upstream and what was published. Run it from the consuming checkout:
#
#    sh .claude-shared/git-scripts/push.sh [--message '<what changed and why>']
#
# Edits can also be committed in the catalog directly, one commit per change with its own message: then run this
# without --message to publish them. With --message, every uncommitted edit in the checkout is committed, so leave it
# out where other sessions may have edits of their own in the same checkout, such as ~/.claude's.
set -eu
message=''
case "${1:-}" in
   --message) message=${2:?"--message needs the commit's message: what changed and why"} ;;
   '') ;;
   *) echo "Usage: sh $0 [--message '<what changed and why>']" >&2; exit 2 ;;
esac
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/catalog-checkouts.sh"
catalog=$(git -C "$dir" rev-parse --show-toplevel)

if [ -n "$(git -C "$catalog" status --porcelain)" ]; then
   if [ -z "$message" ]; then
      echo "The shared Claude config at $catalog has uncommitted edits. Pass --message '<what changed and why>' to commit them, or commit them there yourself." >&2
      exit 1
   fi
   git -C "$catalog" add --all
   git -C "$catalog" commit --quiet -m "$message"
fi

# Rebasing onto upstream first lets the push fast-forward over whatever other checkouts published. A push that still
# loses the race to another checkout's is rebased onto that, and tried again.
attempt=1
while :; do
   if ! fetch_the_upstream_into "$catalog"; then
      echo "Fetching the upstream of the shared Claude config at $catalog failed: $what_git_said" >&2
      exit 1
   fi
   before_the_rebase=$(git -C "$catalog" rev-parse HEAD)
   git -C "$catalog" rebase --quiet --autostash origin/main
   print_the_commits 'Received from upstream:' "$catalog" "$before_the_rebase..origin/main" 'Nothing new upstream.'
   to_publish=$(git -C "$catalog" log --reverse --format='  %h %s' origin/main..HEAD)
   if [ -z "$to_publish" ]; then
      echo 'Nothing to publish.'
      exit 0
   fi
   if git -C "$catalog" push --quiet origin HEAD:main; then
      echo 'Published upstream:'
      echo "$to_publish"
      exit 0
   fi
   if [ "$attempt" -ge 3 ]; then
      echo "Pushing the shared Claude config at $catalog failed $attempt times." >&2
      exit 1
   fi
   attempt=$((attempt + 1))
done
