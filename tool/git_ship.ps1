<#
.SYNOPSIS
Commits every local change and pushes it to origin/main.

.DESCRIPTION
Used by the "Git: commit and push" VS Code task. Two safety rails:

  * Refuses to run when there is nothing to commit, so it cannot create an
    empty commit just because the task was clicked twice.
  * Fails before pushing if the working tree is not clean *after* committing,
    which would otherwise silently leave changes unpushed.

The commit message is read from .git/SHIP_MESSAGE if it exists, so a
descriptive message can be written without fighting VS Code's task quoting.
Otherwise a generic message is used.
#>
[CmdletBinding()]
param(
  [string] $Message = 'chore: update'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found on PATH.'
  }

  $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
  Write-Host "==> Branch: $branch" -ForegroundColor Cyan

  $status = & git status --porcelain
  if (-not $status) {
    Write-Host '==> Nothing to commit; working tree is clean.' -ForegroundColor Yellow
    Write-Host '    Skipping commit and push.' -ForegroundColor Yellow
    exit 0
  }

  $changed = @($status).Count
  Write-Host "==> $changed change(s) to commit" -ForegroundColor Cyan
  foreach ($line in @($status) | Select-Object -First 15) {
    Write-Host "    $line"
  }
  if ($changed -gt 15) { Write-Host "    ... and $($changed - 15) more" }

  # Prefer an explicit message file so multi-line messages survive task quoting.
  $msgFile = Join-Path $projectRoot '.git\SHIP_MESSAGE'
  $msg = $Message
  if (Test-Path -LiteralPath $msgFile) {
    $msg = (Get-Content -LiteralPath $msgFile -Raw).Trim()
    Remove-Item -LiteralPath $msgFile -Force
    Write-Host '==> Using message from .git/SHIP_MESSAGE' -ForegroundColor Cyan
  }

  & git add -A
  if ($LASTEXITCODE -ne 0) { throw "git add failed (exit $LASTEXITCODE)" }

  & git commit -m $msg
  if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE)" }

  Write-Host '==> Pushing to origin' -ForegroundColor Cyan
  & git push origin $branch
  if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)" }

  $left = & git status --porcelain
  if ($left) {
    throw "Push completed but the working tree is not clean:`n$($left -join "`n")"
  }

  $sha = (& git rev-parse --short HEAD).Trim()
  Write-Host "==> Pushed $branch at $sha" -ForegroundColor Green
}
finally {
  Pop-Location
}