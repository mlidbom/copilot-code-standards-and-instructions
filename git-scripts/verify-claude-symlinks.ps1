# Verifies that every symlink the committed tree (HEAD) carries under .claude/ is a real symlink in the
# working tree that resolves to an existing target.
#
# Guards against the silent Windows failure mode: a checkout with core.symlinks=false materializes
# committed symlinks as plain text files containing the target path — which Claude Code would then
# load as garbage rules/skills without complaint.
#
# Silent on success; throws with fix instructions on failure.

# The .claude/ symlinks to check are the consuming checkout's: the folder that this checkout of the catalog, its
# .claude-shared, is in.
$repoRoot = Split-Path -Parent (git -C $PSScriptRoot rev-parse --show-toplevel)

# Whether the symlink $link is a file symlink whose target is a folder. Git for Windows makes one when the target is
# missing at checkout and no symlink=dir attribute says it's a folder; opening it, as ResolveLinkTarget does, is then
# denied.
function IsAFileSymlinkToAFolder($link) {
   if ($link.Attributes -band [System.IO.FileAttributes]::Directory) { return $false }
   $targetPath = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $link.FullName) $link.Target))
   return Test-Path -LiteralPath $targetPath -PathType Container
}

# The committed tree (HEAD) — not the index — is the source of truth for which paths are symlinks. A degraded
# checkout can leave the index ALSO recording a path as a plain file (mode 100644, once the materialized plain
# file is staged); reading the index would then drop that path from the checklist and miss the very corruption
# we exist to catch.
$symlinkPaths = git -C $repoRoot ls-tree -r HEAD -- .claude |
   Where-Object { $_ -match '^120000\s' } |
   ForEach-Object { ($_ -split "`t", 2)[1] }

$broken = @()
foreach ($relativePath in $symlinkPaths) {
   $fullPath = Join-Path $repoRoot $relativePath
   $item = Get-Item $fullPath -Force -ErrorAction SilentlyContinue
   if (-not $item -or $item.LinkType -ne 'SymbolicLink') {
      $broken += "$relativePath — git tracks this as a symlink, but the working tree has a plain file/directory"
      continue
   }
   if (IsAFileSymlinkToAFolder $item) {
      $broken += "$relativePath — a file symlink to a folder, which Windows can't open: git made it before its target existed, with no symlink=dir for it in .gitattributes. Fix: delete it, then git restore --source=HEAD --worktree -- $relativePath ; and add the symlink=dir line that covers it (.claude-shared/README.md)."
      continue
   }
   $target = $item.ResolveLinkTarget($true)
   if (-not $target -or -not $target.Exists) {
      $broken += "$relativePath — symlink does not resolve (target: $($item.Target))"
   }
}

if ($broken.Count -gt 0) {
   throw @"
Claude config symlinks are broken:
$($broken -join "`n")

Fix:
  1. Turn on Windows Developer Mode (Settings > System > For developers) so symlinks can be created without elevation.
  2. git config core.symlinks true     (add --global to cover future clones)
  3. Restore the links: git restore --source=HEAD --staged --worktree -- .claude
"@
}
