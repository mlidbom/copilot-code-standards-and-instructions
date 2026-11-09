# Publishes this repository's edits to the shared Claude config upstream: commits any uncommitted edits in the
# catalog submodule with -Message, rebases them onto upstream main, pushes, and commits the new pin of the catalog here.
# Prints what came in from upstream and what was published. Run from anywhere in the consuming repository.
#
# Edits can also be committed inside the catalog directly, one commit per change with its own message; then run
# this without -Message to publish them.
param([string]$Message)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CatalogSubmodule.psm1') -Force

$catalog = Get-CatalogSubmodule
$root = $catalog.CatalogRoot
Invoke-Git $root 'fetch', '--quiet', 'origin' | Out-Null
Switch-CatalogToMainBranch $catalog

if (Invoke-Git $root 'status', '--porcelain') {
   if (-not $Message) { throw "The catalog at $root has uncommitted edits. Pass -Message '<why this change>' to commit them, or commit them there yourself." }
   Invoke-Git $root 'add', '--all' | Out-Null
   $Message | git -C $root commit --quiet --file -
   if ($LASTEXITCODE -ne 0) { throw "Committing the catalog edits failed in $root (exit code $LASTEXITCODE)" }
}

# Rebasing onto upstream first lets the push fast-forward over whatever other consuming repositories published.
$received = Receive-UpstreamCatalogChanges $catalog
Write-CommitList -Heading 'Received from upstream:' -Commits $received -WhenNone 'Nothing new upstream.'

$toPublish = Invoke-Git $root 'log', '--reverse', '--format=%h %s', 'origin/main..HEAD'
if ($toPublish) { Invoke-Git $root 'push', '--quiet', 'origin', 'main' | Out-Null }
Write-CommitList -Heading 'Published upstream:' -Commits $toPublish -WhenNone 'Nothing to publish.'
Save-CatalogPin $catalog
