#!/bin/sh
# Tests the catalog's session-start hook as it stands in this working tree, committed or not: runs it in scratch
# consuming checkouts, through the situations it must handle, and says for each whether the hook did what it should.
# Run it after changing the hook, pull.sh, push.sh or catalog-checkouts.sh:
#
#    sh git-scripts/sessionstart-hook.test.sh [--showing-what-the-hook-said]
#
# With --showing-what-the-hook-said, each case is followed by what the hook told the agent in it: for reading the
# hook's wording as an agent meets it.
#
# Everything is made in a temporary folder: a bare upstream catalog, a clone that publishes changes to it, a home
# folder, whose ~/.claude/.claude-shared is the machine clone the hook makes, and consuming checkouts. The folder is
# removed when every case passed, and kept for a look when one failed. HOME points into it, and the catalog's GitHub
# address is redirected to the scratch upstream, so nothing outside it is touched, and nothing is fetched from the
# real upstream. Exits non-zero when a case failed.
set -u

this_catalog=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)
scratch=$(mktemp -d)
upstream="$scratch/upstream.git"
publisher="$scratch/publisher"
the_github_address='https://github.com/mlidbom/copilot-code-standards-and-instructions.git'

export GIT_AUTHOR_NAME='The session-start hook test' GIT_AUTHOR_EMAIL='test@example.invalid'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
# The scratch files are written here with LF, and a Windows git would warn of each that it will check out with CRLF.
# Symlinks are made as this machine's own git config says. Submodules of a local folder are allowed, for the cases of
# a checkout that still mounts the catalog as one.
symlinks_here=$(git config --get core.symlinks || echo false)
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=core.safecrlf GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1="url.$upstream.insteadOf" GIT_CONFIG_VALUE_1="$the_github_address"
export GIT_CONFIG_KEY_2=core.symlinks GIT_CONFIG_VALUE_2="$symlinks_here"
export GIT_CONFIG_KEY_3=protocol.file.allow GIT_CONFIG_VALUE_3=always
export HOME="$scratch/home"
mkdir -p "$HOME"
. "$this_catalog/git-scripts/catalog-checkouts.sh"

showing_what_the_hook_said=false
[ "${1:-}" = --showing-what-the-hook-said ] && showing_what_the_hook_said=true

rule_the_test_changes='rules/universal/900-a-rule-the-test-changes.md'
rule_the_test_removes='rules/universal/901-a-rule-the-test-removes.md'
rule_the_test_adds='rules/universal/902-a-rule-the-test-adds.md'
name_of_the_hook='verify-shared-claude-config.sessionstart-hook.sh'

# ---- The scratch repositories ----

set_up_the_upstream_and_the_publisher() {
   git clone --quiet --bare "$this_catalog" "$upstream"
   # This catalog may be checked out on a branch other than main: the scratch upstream's main is the commit checked out
   # here either way.
   git -C "$upstream" update-ref refs/heads/main "$(git -C "$this_catalog" rev-parse HEAD)"
   git -C "$upstream" symbolic-ref HEAD refs/heads/main
   git clone --quiet "$upstream" "$publisher"

   # The scripts under test are this working tree's, so they are published to the scratch upstream as they stand,
   # with two rules that are the test's own to change and to remove.
   rm -rf "$publisher/git-scripts"
   cp -R "$this_catalog/git-scripts" "$publisher/git-scripts"
   echo 'A rule of the test.' > "$publisher/$rule_the_test_changes"
   echo 'A rule of the test.' > "$publisher/$rule_the_test_removes"
   publish 'The git scripts under test, and two rules of the test'
}

# Makes a consuming repository at $1 that ignores .claude-shared and keeps the current copy of the hook, unless $2 is
# 'not-ignoring-the-catalog'.
make_a_consumer() {
   git init --quiet "$1"
   mkdir "$1/.claude"
   cp "$publisher/git-scripts/copy-into-consuming-repository/$name_of_the_hook" "$1/.claude/$name_of_the_hook"
   [ "${2:-}" = not-ignoring-the-catalog ] || echo '/.claude-shared' > "$1/.gitignore"
   git -C "$1" add --all
   git -C "$1" commit --quiet -m 'Consumes the shared Claude config'
}

# Makes a consuming repository at $1 that mounts the catalog as a git submodule, as each repository did before.
make_a_consumer_that_mounts_the_catalog_as_a_submodule() {
   git init --quiet "$1"
   git -C "$1" submodule --quiet add -b main "$upstream" .claude-shared 2>/dev/null
   mkdir "$1/.claude"
   cp "$publisher/git-scripts/copy-into-consuming-repository/$name_of_the_hook" "$1/.claude/$name_of_the_hook"
   git -C "$1" add --all
   git -C "$1" commit --quiet -m 'Mounts the shared Claude config as a submodule'
}

# Commits everything changed in the publisher's working tree, with the message $1, and publishes it to the upstream.
publish() {
   git -C "$publisher" add --all
   git -C "$publisher" commit --quiet -m "$1"
   git -C "$publisher" push --quiet origin main
}

publish_a_change_to_an_always_on_rule() {
   echo "A line added by: $1." >> "$publisher/$rule_the_test_changes"
   publish "A rule of the test changes: $1"
}

upstream_commit() { git -C "$upstream" rev-parse main; }
commit_checked_out_in() { git -C "$1" rev-parse HEAD; }
path_of() { git -C "$1" rev-parse --show-toplevel; }

# ---- Running the hook, and saying what it should have done ----

# Starts a session in the consuming checkout $1 as far as the hook goes: runs its own SessionStart hook. What the hook
# said is then in $said, and its exit code in $hook_exit_code.
start_a_session_in() {
   said=$(sh "$1/.claude/$name_of_the_hook" 2>&1)
   hook_exit_code=$?
}

failed_cases=0
start_case() { case_name=$1; what_went_wrong=''; }
went_wrong() { what_went_wrong="$what_went_wrong      $1
"; }
end_case() {
   [ "$hook_exit_code" -eq 0 ] || went_wrong "the hook exited with $hook_exit_code: a SessionStart hook reaches the agent only on exit 0"
   if [ -z "$what_went_wrong" ]; then
      echo "  passed  $case_name"
      if "$showing_what_the_hook_said"; then show_what_the_hook_said; fi
      return
   fi
   failed_cases=$((failed_cases + 1))
   echo "  FAILED  $case_name"
   printf '%s' "$what_went_wrong"
   show_what_the_hook_said
}
show_what_the_hook_said() {
   if [ -z "$said" ]; then
      echo '      the hook said nothing'
      return
   fi
   echo '      what the hook said:'
   echo "$said" | while IFS= read -r line; do echo "      | $line"; done
}

must_say() { case "$said" in *"$1"*) ;; *) went_wrong "the hook did not say: $1" ;; esac; }
must_not_say() { case "$said" in *"$1"*) went_wrong "the hook said: $1" ;; esac; }
must_say_nothing() { [ -z "$said" ] || went_wrong 'the hook said something'; }
must_list_every_always_on_rule() {
   must_say 'Read each of these always-on shared rules now:'
   must_say "/.claude-shared/$rule_the_test_changes"
   must_say '/.claude-shared/rules/universal/005-pull-the-shared-catalog-before-editing-it-push-after.md'
}
the_catalog_of_must_be_at() { [ "$(commit_checked_out_in "$1/.claude-shared")" = "$2" ] || went_wrong "the catalog of $1 is at $(commit_checked_out_in "$1/.claude-shared"), not at $2"; }
must_be_a_worktree_of_the_machine_clone_on_its_branch() {
   is_a_checkout_of_the_machine_clone "$1/.claude-shared" || { went_wrong "the .claude-shared of $1 is no worktree of the machine clone"; return; }
   expected=$(catalog_branch_for "$(path_of "$1")")
   actual=$(git -C "$1/.claude-shared" symbolic-ref --quiet --short HEAD)
   [ "$actual" = "$expected" ] || went_wrong "the catalog of $1 is on the branch '$actual', not on $expected"
}
must_have_committed_nothing_in() {
   [ -z "$(git -C "$1" status --porcelain)" ] || went_wrong "the consuming repository $1 has uncommitted changes: $(git -C "$1" status --porcelain | head -3)"
   [ "$(git -C "$1" rev-list --count HEAD)" -eq "$2" ] || went_wrong "the consuming repository $1 has $(git -C "$1" rev-list --count HEAD) commits, not $2"
}
branch_must_exist() { git -C "$machine_clone" show-ref --verify --quiet "refs/heads/$1" || went_wrong "the machine clone has no branch $1"; }
branch_must_not_exist() { git -C "$machine_clone" show-ref --verify --quiet "refs/heads/$1" && went_wrong "the machine clone still has the branch $1"; }

# ---- The cases ----

echo "The session-start hook of the catalog at $this_catalog, in scratch repositories under $scratch:"
set_up_the_upstream_and_the_publisher
home_claude="$HOME/.claude"
consumer="$scratch/consumer"

start_case "A new machine: ~/.claude's own hook clones the machine clone, as its .claude-shared, and lists every always-on rule"
make_a_consumer "$home_claude"
start_a_session_in "$home_claude"
must_say 'This machine had no clone of the shared Claude config'
must_list_every_always_on_rule
is_a_checkout_of_its_own "$machine_clone" || went_wrong 'there is no machine clone'
[ "$(git -C "$machine_clone" symbolic-ref --quiet --short HEAD)" = main ] || went_wrong 'the machine clone is not on main'
end_case

start_case "~/.claude's next session start: the hook says nothing"
start_a_session_in "$home_claude"
must_say_nothing
end_case

start_case "A checkout with no catalog: the hook makes it a worktree of the machine clone, on the checkout's own branch, and lists every always-on rule"
make_a_consumer "$consumer"
start_a_session_in "$consumer"
must_say 'This checkout had no checkout of the shared Claude config at .claude-shared'
must_say 'It now has one: a git worktree of the machine'
must_list_every_always_on_rule
must_be_a_worktree_of_the_machine_clone_on_its_branch "$consumer"
the_catalog_of_must_be_at "$consumer" "$(upstream_commit)"
must_have_committed_nothing_in "$consumer" 1
end_case

start_case 'The next session start: the hook says nothing'
start_a_session_in "$consumer"
must_say_nothing
end_case

start_case 'Behind: the hook pulls it, lists the always-on rules that changed, commits nothing, and brings the machine clone along'
echo 'A line the test adds.' >> "$publisher/$rule_the_test_changes"
git -C "$publisher" rm --quiet "$rule_the_test_removes"
echo 'A rule the test adds.' > "$publisher/$rule_the_test_adds"
echo 'What only someone changing the rule needs.' > "$publisher/rules/universal/900-a-rule-the-test-changes.rationale.txt"
echo 'A line the test adds.' >> "$publisher/README.md"
publish 'A rule changes, one is removed, one is added, and so is a sidecar'
start_a_session_in "$consumer"
must_say 'were 1 commit behind their upstream, and have now been pulled'
must_say "/$rule_the_test_changes"
must_say "/$rule_the_test_adds"
must_say 'were removed, and no longer apply'
must_say "  $rule_the_test_removes"
must_not_say 'rationale.txt'
must_say 'A rule changes, one is removed, one is added, and so is a sidecar'
the_catalog_of_must_be_at "$consumer" "$(upstream_commit)"
the_catalog_of_must_be_at "$home_claude" "$(upstream_commit)"
must_have_committed_nothing_in "$consumer" 1
end_case

start_case 'The next session start after a pull: the hook says nothing'
start_a_session_in "$consumer"
must_say_nothing
end_case

start_case 'Behind by a change to no always-on rule: the hook pulls it and says that none changed'
echo 'Another line the test adds.' >> "$publisher/README.md"
publish 'The README changes'
start_a_session_in "$consumer"
must_say 'have now been pulled'
must_say 'No always-on rule changed.'
the_catalog_of_must_be_at "$consumer" "$(upstream_commit)"
end_case

start_case "~/.claude behind: its own hook pulls the machine clone and lists what changed"
publish_a_change_to_an_always_on_rule "the change ~/.claude's hook pulls"
start_a_session_in "$home_claude"
must_say 'have now been pulled'
must_say "/$rule_the_test_changes"
the_catalog_of_must_be_at "$home_claude" "$(upstream_commit)"
end_case
start_a_session_in "$consumer"

publish_a_change_to_an_always_on_rule 'the change that the cases below leave unpulled'
level_with_the_upstream_before_that_change=$(commit_checked_out_in "$consumer/.claude-shared")

start_case 'Behind, and the catalog here has uncommitted edits: the hook leaves the pull alone and says why'
echo 'An edit in progress.' >> "$consumer/.claude-shared/README.md"
start_a_session_in "$consumer"
must_say 'are 1 commit behind their upstream, and were not pulled'
must_say 'it has uncommitted edits'
must_say 'sh .claude-shared/git-scripts/pull.sh'
the_catalog_of_must_be_at "$consumer" "$level_with_the_upstream_before_that_change"
end_case
git -C "$consumer/.claude-shared" checkout --quiet -- README.md

start_case 'Behind, and the catalog here has commits that are not published: the hook leaves the pull alone and says why'
git -C "$consumer/.claude-shared" commit --quiet --allow-empty -m 'A commit that is not published'
start_a_session_in "$consumer"
must_say 'were not pulled'
must_say 'it has commits that are not published upstream'
end_case
git -C "$consumer/.claude-shared" reset --quiet --hard "$level_with_the_upstream_before_that_change"

start_case "Behind, and the upstream can't be reached: the hook says that the rules may be behind"
git -C "$machine_clone" remote set-url origin "$scratch/no-such-upstream.git"
start_a_session_in "$consumer"
must_say 'could not be compared with their upstream'
the_catalog_of_must_be_at "$consumer" "$level_with_the_upstream_before_that_change"
end_case
git -C "$machine_clone" remote set-url origin "$the_github_address"
start_a_session_in "$consumer"

start_case 'Two checkouts with the same folder name, in different folders: each gets a branch of its own'
make_a_consumer "$scratch/one/Deskmancer"
make_a_consumer "$scratch/another/Deskmancer"
start_a_session_in "$scratch/one/Deskmancer"
start_a_session_in "$scratch/another/Deskmancer"
must_be_a_worktree_of_the_machine_clone_on_its_branch "$scratch/one/Deskmancer"
must_be_a_worktree_of_the_machine_clone_on_its_branch "$scratch/another/Deskmancer"
[ "$(catalog_branch_for "$(path_of "$scratch/one/Deskmancer")")" != "$(catalog_branch_for "$(path_of "$scratch/another/Deskmancer")")" ] || went_wrong 'the two checkouts have the same branch'
end_case

start_case 'A checkout deleted with a commit that is not published: its branch is kept, and reported at every session start'
deleted="$scratch/deleted-with-work"
make_a_consumer "$deleted"
start_a_session_in "$deleted"
branch_of_the_deleted=$(catalog_branch_for "$(path_of "$deleted")")
git -C "$deleted/.claude-shared" commit --quiet --allow-empty -m 'A commit of the deleted checkout'
rm -rf "$deleted"
start_a_session_in "$consumer"
must_say "has the branch $branch_of_the_deleted, left by a checkout that no longer exists, with 1 commit(s) that are not published"
branch_must_exist "$branch_of_the_deleted"
end_case

start_case 'The deleted checkout made again at the same path: it gets its branch back, with the commit'
make_a_consumer "$deleted"
start_a_session_in "$deleted"
must_say 'which an earlier checkout at this path left'
must_be_a_worktree_of_the_machine_clone_on_its_branch "$deleted"
[ "$(git -C "$deleted/.claude-shared" log -1 --format=%s)" = 'A commit of the deleted checkout' ] || went_wrong 'the commit of the deleted checkout is not back'
end_case
git -C "$deleted/.claude-shared" reset --quiet --hard origin/main
start_a_session_in "$consumer"

start_case 'A checkout deleted with nothing that is not published: its branch is deleted, and nothing said'
make_a_consumer "$scratch/deleted-without-work"
start_a_session_in "$scratch/deleted-without-work"
branch_of_the_deleted=$(catalog_branch_for "$(path_of "$scratch/deleted-without-work")")
rm -rf "$scratch/deleted-without-work"
start_a_session_in "$consumer"
must_say_nothing
branch_must_not_exist "$branch_of_the_deleted"
end_case

start_case 'A branch that still mounts the catalog as a submodule: its old hook runs the catalog in it, which says so, pulls, and asks for no new copy of the hook'
mounting="$scratch/still-mounting-it"
make_a_consumer_that_mounts_the_catalog_as_a_submodule "$mounting"
git -C "$mounting/.claude-shared" reset --quiet --hard HEAD~1
said=$(sh "$mounting/.claude-shared/git-scripts/sessionstart-hook.sh" 2>&1)
hook_exit_code=$?
must_say 'still mounts .claude-shared as a git submodule'
must_say "don't commit .claude-shared"
must_say 'have now been pulled'
must_not_say "is no longer the shared Claude config's current one"
the_catalog_of_must_be_at "$mounting" "$(upstream_commit)"
must_have_committed_nothing_in_but_the_catalog() { [ "$(git -C "$1" rev-list --count HEAD)" -eq 1 ] || went_wrong "the consuming repository $1 has a new commit"; }
must_have_committed_nothing_in_but_the_catalog "$mounting"
end_case

start_case 'The branch takes the commit that removes the submodule: the clone it leaves, with no work of its own, is replaced by a worktree'
git -C "$mounting" rm --quiet --cached .claude-shared
git -C "$mounting" rm --quiet .gitmodules
echo '/.claude-shared' > "$mounting/.gitignore"
git -C "$mounting" add .gitignore
git -C "$mounting" commit --quiet -m 'Removes the submodule'
start_a_session_in "$mounting"
must_say 'was a clone of the shared Claude config of its own'
must_list_every_always_on_rule
must_be_a_worktree_of_the_machine_clone_on_its_branch "$mounting"
[ ! -e "$mounting/.git/modules/.claude-shared" ] || went_wrong "the submodule's git folder is still there"
end_case

start_case 'A checkout whose catalog is already a worktree switches back to a branch that still mounts it as a submodule: the hook says not to commit .claude-shared'
git -C "$mounting" checkout --quiet -b still-mounting-it HEAD~1 2>/dev/null
start_a_session_in "$mounting"
must_say 'still mounts .claude-shared as a git submodule'
must_say "Don't commit .claude-shared on this branch"
must_be_a_worktree_of_the_machine_clone_on_its_branch "$mounting"
end_case
git -C "$mounting" checkout --quiet - 2>/dev/null

start_case 'A clone left by the submodule with an uncommitted edit: it is left in place, and the hook says why'
with_work="$scratch/left-with-work"
make_a_consumer_that_mounts_the_catalog_as_a_submodule "$with_work"
git -C "$with_work" rm --quiet --cached .claude-shared
git -C "$with_work" rm --quiet .gitmodules
echo '/.claude-shared' > "$with_work/.gitignore"
git -C "$with_work" add .gitignore
git -C "$with_work" commit --quiet -m 'Removes the submodule'
echo 'An edit in progress.' >> "$with_work/.claude-shared/README.md"
start_a_session_in "$with_work"
must_say 'is a clone of the shared Claude config of its own'
must_say 'it has uncommitted edits'
grep -q 'An edit in progress.' "$with_work/.claude-shared/README.md" || went_wrong 'the uncommitted edit is gone'
end_case

start_case "A repository whose .gitignore doesn't ignore .claude-shared: the hook says to add it"
make_a_consumer "$scratch/not-ignoring" not-ignoring-the-catalog
start_a_session_in "$scratch/not-ignoring"
must_say "doesn't ignore .claude-shared"
must_say '/.claude-shared'
end_case

start_case "A repository whose own hook is outdated: the hook says so; replaced and not yet committed, it says nothing"
echo '# An older copy.' >> "$consumer/.claude/$name_of_the_hook"
git -C "$consumer" commit --quiet -m 'An older copy of the hook' -- .claude
start_a_session_in "$consumer"
must_say "is no longer the shared Claude config's current one"
must_say '/git-scripts/copy-into-consuming-repository/verify-shared-claude-config.sessionstart-hook.sh over it'
cp "$publisher/git-scripts/copy-into-consuming-repository/$name_of_the_hook" "$consumer/.claude/$name_of_the_hook"
start_a_session_in "$consumer"
must_say_nothing
end_case
git -C "$consumer" commit --quiet -m 'The current hook' -- .claude

start_case 'A symlink into the catalog that the checkout left as a plain file: the hook tells the agent to stop'
symlink="$consumer/.claude/the-shared-universal-rules"
MSYS=winsymlinks:nativestrict ln -s ../.claude-shared/rules/universal "$symlink" 2>/dev/null
git -C "$consumer" add --all
git -C "$consumer" commit --quiet -m 'Adopts the universal rules'
if git -C "$consumer" ls-tree HEAD -- .claude/the-shared-universal-rules | grep -q '^120000 '; then
   start_a_session_in "$consumer"
   must_say_nothing
   rm "$symlink"
   echo '../.claude-shared/rules/universal' > "$symlink"
   start_a_session_in "$consumer"
   must_say 'STOP: this checkout is degraded'
   must_say '.claude/the-shared-universal-rules'
   end_case
   git -C "$consumer" checkout --quiet -- .claude/the-shared-universal-rules
else
   echo "  skipped $case_name (no symlink could be made here)"
fi

start_case "pull.sh: rebases the checkout's commits and edits onto upstream main, and says what came in"
publish_a_change_to_an_always_on_rule 'the change pull.sh brings in'
git -C "$consumer/.claude-shared" commit --quiet --allow-empty -m 'A commit of the consumer'
echo 'An edit in progress.' >> "$consumer/.claude-shared/README.md"
said=$(sh "$consumer/.claude-shared/git-scripts/pull.sh" 2>&1)
hook_exit_code=$?
must_say 'Received from upstream:'
must_say 'the change pull.sh brings in'
[ "$(git -C "$consumer/.claude-shared" rev-parse HEAD~1)" = "$(upstream_commit)" ] || went_wrong 'the commit of the consumer is not on top of upstream main'
grep -q 'An edit in progress.' "$consumer/.claude-shared/README.md" || went_wrong 'the uncommitted edit is gone'
end_case

start_case 'push.sh --message: commits the edits, and publishes them, with the commit before them, to upstream main'
said=$(sh "$consumer/.claude-shared/git-scripts/push.sh" --message 'An edit the consumer publishes' 2>&1)
hook_exit_code=$?
must_say 'Published upstream:'
must_say 'A commit of the consumer'
must_say 'An edit the consumer publishes'
[ "$(git -C "$upstream" log -1 --format=%s main)" = 'An edit the consumer publishes' ] || went_wrong 'upstream main does not have the edit'
[ -z "$(git -C "$consumer/.claude-shared" status --porcelain)" ] || went_wrong 'the checkout still has uncommitted edits'
end_case
git -C "$publisher" pull --quiet --rebase

start_case 'push.sh with uncommitted edits and no --message: it publishes nothing, and says why'
echo 'An edit in progress.' >> "$consumer/.claude-shared/README.md"
said=$(sh "$consumer/.claude-shared/git-scripts/push.sh" 2>&1)
[ $? -ne 0 ] || went_wrong 'push.sh succeeded'
hook_exit_code=0
must_say 'has uncommitted edits'
end_case
git -C "$consumer/.claude-shared" checkout --quiet -- README.md

start_case 'A checkout moved to another folder: its catalog stays attached, at its next session start and the one after'
make_a_consumer "$scratch/to-be-moved"
start_a_session_in "$scratch/to-be-moved"
mv "$scratch/to-be-moved" "$scratch/moved"
start_a_session_in "$scratch/moved"
must_say_nothing
start_a_session_in "$scratch/moved"
must_say_nothing
is_a_checkout_of_the_machine_clone "$scratch/moved/.claude-shared" || went_wrong 'the moved checkout lost its catalog'
end_case

start_case "An edit in progress to the steps in ~/.claude's catalog: it runs in ~/.claude's session starts only"
echo 'echo "AN EDIT IN PROGRESS TO THE CLEAN-UP STEP"' >> "$machine_clone/git-scripts/sessionstart-hook.clean-up-after-deleted-checkouts.sh"
start_a_session_in "$consumer"
must_not_say 'AN EDIT IN PROGRESS TO THE CLEAN-UP STEP'
start_a_session_in "$home_claude"
must_say 'AN EDIT IN PROGRESS TO THE CLEAN-UP STEP'
end_case
git -C "$machine_clone" checkout --quiet -- git-scripts/sessionstart-hook.clean-up-after-deleted-checkouts.sh

start_case 'Sessions starting at once in eight checkouts, the upstream ahead: every hook attaches or pulls, and none fails'
publish_a_change_to_an_always_on_rule 'the change the sessions starting at once pull'
at_once="$consumer $scratch/one/Deskmancer $scratch/another/Deskmancer $deleted"
for number in 1 2 3 4; do
   make_a_consumer "$scratch/at-once-$number"
   at_once="$at_once $scratch/at-once-$number"
done
for checkout in $at_once; do
   (sh "$checkout/.claude/$name_of_the_hook" > "$checkout.said" 2>&1; echo $? > "$checkout.exit-code") &
done
wait
said=''
hook_exit_code=0
for checkout in $at_once; do
   said="$said$(cat "$checkout.said")
"
   [ "$(cat "$checkout.exit-code")" -eq 0 ] || hook_exit_code=$(cat "$checkout.exit-code")
   must_be_a_worktree_of_the_machine_clone_on_its_branch "$checkout"
   the_catalog_of_must_be_at "$checkout" "$(upstream_commit)"
done
must_not_say 'could not be compared'
must_not_say 'failed'
must_not_say 'STOP'
end_case

if [ "$failed_cases" -gt 0 ]; then
   echo "$failed_cases case(s) FAILED. The scratch repositories are kept: $scratch"
   exit 1
fi
rm -rf "$scratch"
echo 'Every case passed.'
