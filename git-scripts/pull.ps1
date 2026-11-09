# Brings upstream changes to the shared Claude config into this repository: updates the catalog submodule's main
# branch from upstream main (local edits ride along) and commits the new pin of the catalog here.
# Prints the upstream commits that came in. Run from anywhere in the consuming repository.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CatalogSubmodule.psm1') -Force

$catalog = Get-CatalogSubmodule
Invoke-Git $catalog.CatalogRoot 'fetch', '--quiet', 'origin' | Out-Null
Switch-CatalogToMainBranch $catalog
$received = Receive-UpstreamCatalogChanges $catalog
Write-CommitList -Heading 'Received from upstream:' -Commits $received -WhenNone 'Nothing new upstream.'
Save-CatalogPin $catalog
