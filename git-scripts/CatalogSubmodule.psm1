# The shared Claude config catalog, checked out as a git submodule of a consuming repository.
#
# Shared by pull.ps1 and push.ps1. Both keep the submodule on its main branch, bring that branch up to date with
# upstream main, and commit the resulting catalog commit as the consuming repository's new pin of the catalog.

function Invoke-Git {
   <# Runs git in a directory and throws when git fails, so a failed step can never be silently skipped. #>
   param([Parameter(Mandatory)][string]$In, [Parameter(Mandatory)][string[]]$Arguments)
   $output = git -C $In @Arguments
   if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed in $In (exit code $LASTEXITCODE)" }
   $output
}

function Get-CatalogSubmodule {
   <# Locates the catalog this module ships in, and the consuming repository that mounts it as a submodule. #>
   $catalogRoot = Invoke-Git $PSScriptRoot 'rev-parse', '--show-toplevel'
   $consumingRepositoryRoot = Invoke-Git $catalogRoot 'rev-parse', '--show-superproject-working-tree'
   if (-not $consumingRepositoryRoot) {
      throw "$catalogRoot is not mounted as a git submodule. These scripts sync the catalog as a submodule of the repository that consumes it."
   }
   [pscustomobject]@{
      CatalogRoot             = $catalogRoot
      ConsumingRepositoryRoot = $consumingRepositoryRoot
      MountPath               = [IO.Path]::GetRelativePath($consumingRepositoryRoot, $catalogRoot).Replace('\', '/')
   }
}

function Switch-CatalogToMainBranch {
   <#
   Puts the catalog on its main branch, at or beyond the commit the consuming repository pins.

   A fresh clone or a new worktree checks a submodule out as a detached HEAD at the pinned commit. A commit made
   there belongs to no branch and cannot be pushed as main, so both sync scripts attach to main first.
   #>
   param([Parameter(Mandatory)]$Catalog)
   $root = $Catalog.CatalogRoot
   $currentBranch = git -C $root symbolic-ref --quiet --short HEAD
   if ($currentBranch -eq 'main') { return }
   if ($currentBranch) {
      throw "The catalog at $root is on branch '$currentBranch'. The sync scripts work on main: finish or move that work, then switch back to main."
   }

   $pinnedCommit = Invoke-Git $root 'rev-parse', 'HEAD'
   if (-not (Test-LocalBranchExists $root 'main')) {
      Invoke-Git $root 'switch', '--quiet', '--create', 'main', $pinnedCommit | Out-Null
      Invoke-Git $root 'branch', '--quiet', '--set-upstream-to', 'origin/main' | Out-Null
      return
   }

   if (Test-IsAncestor $root 'main' $pinnedCommit) {
      # Fast-forwards the branch to the pinned commit without touching the working tree, so local edits stay put.
      Invoke-Git $root 'branch', '--force', 'main', $pinnedCommit | Out-Null
   } elseif (-not (Test-IsAncestor $root $pinnedCommit 'main')) {
      throw "The catalog's local main and the pinned commit $pinnedCommit have diverged in $root. Reconcile them by hand."
   }
   Invoke-Git $root 'switch', '--quiet', 'main' | Out-Null
}

function Receive-UpstreamCatalogChanges {
   <#
   Rebases the catalog's main onto upstream main, carrying local commits and uncommitted edits along.
   Returns the upstream commits that were new here, oldest first, as "<hash> <subject>" lines.
   #>
   param([Parameter(Mandatory)]$Catalog)
   $root = $Catalog.CatalogRoot
   $previousHead = Invoke-Git $root 'rev-parse', 'HEAD'
   Invoke-Git $root 'pull', '--quiet', '--rebase', '--autostash', 'origin', 'main' | Out-Null
   Invoke-Git $root 'log', '--reverse', '--format=%h %s', "$previousHead..origin/main"
}

function Save-CatalogPin {
   <#
   Commits the catalog's current commit as the consuming repository's pin of it.
   Commits only the pin, never anything else that happens to be staged in the consuming repository.

   Never pins a commit that exists only locally: every other clone of the consuming repository would then pin a
   commit it cannot fetch. Local catalog commits get pinned when push.ps1 publishes them.
   #>
   param([Parameter(Mandatory)]$Catalog)
   $repository = $Catalog.ConsumingRepositoryRoot
   $mountPath = $Catalog.MountPath
   $previousPin = ((Invoke-Git $repository 'ls-tree', 'HEAD', '--', $mountPath) -split '\s+')[2]
   $newPin = Invoke-Git $Catalog.CatalogRoot 'rev-parse', 'HEAD'
   if ($previousPin -eq $newPin) { return }
   if (-not (Test-IsAncestor $Catalog.CatalogRoot $newPin 'origin/main')) {
      Write-Host "Not pinning: the catalog has local commits that are not published upstream. Run push.ps1 to publish and pin them."
      return
   }

   $catalogChanges = Invoke-Git $Catalog.CatalogRoot 'log', '--reverse', '--format=- %s', "$previousPin..$newPin"
   $message = "Update $mountPath to shared Claude config $($newPin.Substring(0, 9))`n`n$($catalogChanges -join "`n")`n"
   Invoke-Git $repository 'add', '--', $mountPath | Out-Null
   $message | git -C $repository commit --quiet --file - -- $mountPath
   if ($LASTEXITCODE -ne 0) { throw "Committing the new pin of $mountPath failed in $repository (exit code $LASTEXITCODE)" }
   Write-Host "Committed the new pin of $mountPath in $repository."
}

function Write-CommitList {
   <# Prints a heading and the given "<hash> <subject>" lines, or the fallback line when there are none. #>
   param([Parameter(Mandatory)][string]$Heading, [string[]]$Commits, [Parameter(Mandatory)][string]$WhenNone)
   if (-not $Commits) { Write-Host $WhenNone; return }
   Write-Host $Heading
   $Commits | ForEach-Object { Write-Host "  $_" }
}

function Test-LocalBranchExists([string]$Root, [string]$Branch) {
   git -C $Root show-ref --verify --quiet "refs/heads/$Branch"
   $LASTEXITCODE -eq 0
}

function Test-IsAncestor([string]$Root, [string]$Ancestor, [string]$Descendant) {
   git -C $Root merge-base --is-ancestor $Ancestor $Descendant
   switch ($LASTEXITCODE) {
      0 { $true }
      1 { $false }
      default { throw "git merge-base --is-ancestor $Ancestor $Descendant failed in $Root (exit code $LASTEXITCODE)" }
   }
}

Export-ModuleMember -Function Invoke-Git, Get-CatalogSubmodule, Switch-CatalogToMainBranch, Receive-UpstreamCatalogChanges, Save-CatalogPin, Write-CommitList
