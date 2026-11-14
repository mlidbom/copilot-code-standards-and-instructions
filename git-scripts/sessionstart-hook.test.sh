#!/bin/sh
# Tests the catalog's session-start hook as it stands in this working tree, committed or not: runs it in a scratch
# consuming repository, through the situations it must handle, and says for each whether the hook did what it should.
# Run it after changing the hook, pull.ps1 or CatalogSubmodule.psm1:
#
#    sh git-scripts/sessionstart-hook.test.sh [--showing-what-the-hook-said]
#
# With --showing-what-the-hook-said, each case is followed by what the hook told the agent in it: for reading the
# hook's wording as an agent meets it.
#
# The scratch repositories are a bare upstream catalog, a clone that publishes changes to it, and a consuming
# repository that mounts it as its .claude-shared submodule. They are made in a temporary folder, which is removed
# when every case passed, and kept for a look when one failed. Nothing outside that folder is touched, and nothing is
# fetched from the real upstream. Exits non-zero when a case failed.
set -u

this_catalog=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)
scratch=$(mktemp -d)
upstream="$scratch/upstream.git"
publisher="$scratch/publisher"
consumer="$scratch/consumer"
catalog_in_consumer="$consumer/.claude-shared"

export GIT_AUTHOR_NAME='The session-start hook test' GIT_AUTHOR_EMAIL='test@example.invalid'
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
# The scratch repositories' files are written here with LF, and a Windows git would warn of each that it will check
# out with CRLF.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.safecrlf GIT_CONFIG_VALUE_0=false

showing_what_the_hook_said=false
[ "${1:-}" = --showing-what-the-hook-said ] && showing_what_the_hook_said=true

rule_the_test_changes='rules/universal/900-a-rule-the-test-changes.md'
rule_the_test_removes='rules/universal/901-a-rule-the-test-removes.md'
rule_the_test_adds='rules/universal/902-a-rule-the-test-adds.md'

# ---- The scratch repositories ----

set_up_the_scratch_repositories() {
   git clone --quiet --bare "$this_catalog" "$upstream"
   # This catalog may be checked out on no branch, as a submodule is in a fresh clone: the scratch upstream's main is
   # the commit checked out here either way.
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

   git init --quiet "$consumer"
   git -C "$consumer" -c protocol.file.allow=always submodule --quiet add -b main "$upstream" .claude-shared 2>/dev/null
   mkdir "$consumer/.claude"
   cp "$catalog_in_consumer/git-scripts/copy-into-consuming-repository/verify-shared-claude-config.sessionstart-hook.sh" "$consumer/.claude/"
   git -C "$consumer" add --all
   git -C "$consumer" commit --quiet -m 'Mounts the shared Claude config'
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
commit_of_the_catalog_in_the_consumer() { git -C "$catalog_in_consumer" rev-parse HEAD; }

# ---- Running the hook, and saying what it should have done ----

# Starts a session in the consumer as far as the hook goes: runs the consuming repository's SessionStart hook, or the
# script $1 in its place. What the hook said is then in $said, and its exit code in $hook_exit_code.
start_a_session() {
   said=$(sh "${1:-$consumer/.claude/verify-shared-claude-config.sessionstart-hook.sh}" 2>&1)
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
the_catalog_must_be_at() { [ "$(commit_of_the_catalog_in_the_consumer)" = "$1" ] || went_wrong "the catalog in the consumer is at $(commit_of_the_catalog_in_the_consumer), not at $1"; }
the_consumer_must_have_committed_the_pin() {
   [ -z "$(git -C "$consumer" status --porcelain)" ] || went_wrong 'the consuming repository has uncommitted changes, so the new pin is not committed'
   case "$(git -C "$consumer" log -1 --format=%s)" in 'Update .claude-shared to shared Claude config '*) ;; *) went_wrong "the consuming repository's last commit is not the new pin: $(git -C "$consumer" log -1 --format=%s)" ;; esac
}

# The PATH with every directory that holds the program $1 taken out of it.
path_without() {
   remaining=$PATH
   while found=$(PATH="$remaining" command -v "$1" 2>/dev/null); do
      remaining=$(printf '%s' "$remaining" | tr ':' '\n' | grep -vxF "$(dirname -- "$found")" | paste -sd: -)
   done
   printf '%s' "$remaining"
}

# ---- The cases ----

echo "The session-start hook of the catalog at $this_catalog, in scratch repositories under $scratch:"
set_up_the_scratch_repositories

start_case 'The catalog is level with its upstream: the hook says nothing'
start_a_session
must_say_nothing
end_case

start_case 'The catalog is behind: the hook pulls it, commits the pin, and lists the always-on rules that changed'
echo 'A line the test adds.' >> "$publisher/$rule_the_test_changes"
git -C "$publisher" rm --quiet "$rule_the_test_removes"
echo 'A rule the test adds.' > "$publisher/$rule_the_test_adds"
echo 'What only someone changing the rule needs.' > "$publisher/rules/universal/900-a-rule-the-test-changes.rationale.txt"
echo 'A line the test adds.' >> "$publisher/README.md"
publish 'A rule changes, one is removed, one is added, and so is a sidecar'
start_a_session
must_say 'were 1 commit behind their upstream, and have now been pulled'
must_say "/$rule_the_test_changes"
must_say "/$rule_the_test_adds"
must_say 'were removed, and no longer apply'
must_say "  $rule_the_test_removes"
must_not_say 'rationale.txt'
must_say 'A rule changes, one is removed, one is added, and so is a sidecar'
the_catalog_must_be_at "$(upstream_commit)"
the_consumer_must_have_committed_the_pin
end_case

start_case 'The next session start after a pull: the hook says nothing'
start_a_session
must_say_nothing
end_case

start_case 'The catalog is behind by a change to no always-on rule: the hook pulls it and says that none changed'
echo 'Another line the test adds.' >> "$publisher/README.md"
publish 'The README changes'
start_a_session
must_say 'have now been pulled'
must_say 'No always-on rule changed.'
the_catalog_must_be_at "$(upstream_commit)"
the_consumer_must_have_committed_the_pin
end_case

publish_a_change_to_an_always_on_rule 'the change that the cases below leave unpulled'
level_with_the_upstream_before_that_change=$(commit_of_the_catalog_in_the_consumer)

start_case 'Behind, and the catalog here has uncommitted edits: the hook leaves the pull alone and says why'
echo 'An edit in progress.' >> "$catalog_in_consumer/README.md"
start_a_session
must_say 'are 1 commit behind their upstream, and were not pulled'
must_say 'it has uncommitted edits'
the_catalog_must_be_at "$level_with_the_upstream_before_that_change"
end_case
git -C "$catalog_in_consumer" checkout --quiet -- README.md

start_case 'Behind, and the catalog here has commits that are not published: the hook leaves the pull alone and says why'
git -C "$catalog_in_consumer" commit --quiet --allow-empty -m 'A commit that is not published'
start_a_session
must_say 'were not pulled'
must_say 'it has commits that are not published upstream'
end_case
git -C "$catalog_in_consumer" reset --quiet --hard "$level_with_the_upstream_before_that_change"

start_case 'Behind, and the catalog here is on a branch other than main: the hook leaves the pull alone and says why'
git -C "$catalog_in_consumer" switch --quiet --create a-branch-of-its-own
start_a_session
must_say 'were not pulled'
must_say "it is on the branch 'a-branch-of-its-own', not on main"
the_catalog_must_be_at "$level_with_the_upstream_before_that_change"
end_case
git -C "$catalog_in_consumer" switch --quiet main
git -C "$catalog_in_consumer" branch --quiet -D a-branch-of-its-own

start_case 'Behind, on a machine without PowerShell 7: the hook says that the rules were not pulled'
path_without_powershell=$(path_without pwsh)
if PATH="$path_without_powershell" command -v git >/dev/null 2>&1 && PATH="$path_without_powershell" command -v sh >/dev/null 2>&1; then
   said=$(PATH="$path_without_powershell" sh "$consumer/.claude/verify-shared-claude-config.sessionstart-hook.sh" 2>&1)
   hook_exit_code=$?
   must_say 'were not pulled: pull.ps1 runs in PowerShell 7'
   the_catalog_must_be_at "$level_with_the_upstream_before_that_change"
   end_case
else
   echo "  skipped $case_name (here PowerShell shares its folder with git or sh, so it can't be taken off the PATH alone)"
fi

start_case "Behind, and the upstream can't be reached: the hook says that the rules may be behind"
git -C "$catalog_in_consumer" remote set-url origin "$scratch/no-such-upstream.git"
start_a_session
must_say 'could not be compared with their upstream'
the_catalog_must_be_at "$level_with_the_upstream_before_that_change"
end_case
git -C "$catalog_in_consumer" remote set-url origin "$upstream"

start_case "A consuming repository's hook from before 2026-11-15, which hands over by the old name: all of the hook runs"
start_a_session "$catalog_in_consumer/git-scripts/verify-claude-symlinks.sessionstart-hook.sh"
must_say 'have now been pulled'
must_say "/$rule_the_test_changes"
the_catalog_must_be_at "$(upstream_commit)"
the_consumer_must_have_committed_the_pin
end_case

start_case 'A symlink into the catalog that the checkout left as a plain file: the hook tells the agent to stop'
symlink="$consumer/.claude/the-shared-universal-rules"
MSYS=winsymlinks:nativestrict ln -s ../.claude-shared/rules/universal "$symlink" 2>/dev/null
git -C "$consumer" add --all
git -C "$consumer" commit --quiet -m 'Adopts the universal rules'
if git -C "$consumer" ls-tree HEAD -- .claude/the-shared-universal-rules | grep -q '^120000 '; then
   start_a_session
   must_say_nothing
   rm "$symlink"
   echo '../.claude-shared/rules/universal' > "$symlink"
   start_a_session
   must_say 'STOP: this checkout is degraded'
   must_say '.claude/the-shared-universal-rules'
   end_case
else
   echo "  skipped $case_name (no symlink could be made here)"
fi

if [ "$failed_cases" -gt 0 ]; then
   echo "$failed_cases case(s) FAILED. The scratch repositories are kept: $scratch"
   exit 1
fi
rm -rf "$scratch"
echo 'Every case passed.'
