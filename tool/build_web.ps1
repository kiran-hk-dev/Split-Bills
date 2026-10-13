<#
.SYNOPSIS
Builds the Flutter web bundle with configuration read from .env.

.DESCRIPTION
`String.fromEnvironment` only sees values passed as --dart-define at compile
time, and .env is never loaded automatically. This script reads .env, converts
it into dart-defines, and builds.

It then verifies the key actually landed in the bundle. That check exists
because a missing --dart-define produces a build that *succeeds* but ships an
empty key, which only fails later as "No API key found in request" - a
confusing symptom far from its cause.

Inline `#` comments in .env are stripped, and the service-role key is never
forwarded so it cannot reach a client bundle.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tool\build_web.ps1
#>
[CmdletBinding()]
param(
  # Defaults to the .env beside this script's parent directory.
  [string] $EnvFile,

  # Overrides the value from .env. Useful for preview vs production builds.
  [string] $SupabaseAnonKey,

  # development | staging | production
  [string] $AppEnv,

  [switch] $NoRelease
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $EnvFile) { $EnvFile = Join-Path $projectRoot '.env' }

function Write-Step($message) {
  Write-Host "==> $message" -ForegroundColor Cyan
}

function Read-DotEnv([string] $path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $path)) { return $values }

  foreach ($line in Get-Content -LiteralPath $path) {
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -notmatch '=') { continue }

    $key, $value = $trimmed -split '=', 2
    $key = $key.Trim()
    # Strip an inline trailing comment, then unwrap quotes.
    $value = ($value -split '\s+#', 2)[0].Trim()
    $value = $value.Trim('"').Trim("'")
    if ($key) { $values[$key] = $value }
  }
  return $values
}

Write-Step "Reading configuration from $EnvFile"
# Deliberately not named $env: PowerShell reserves $env as the environment
# provider, and shadowing it makes indexed lookups behave surprisingly.
$cfg = Read-DotEnv $EnvFile

if (-not $SupabaseAnonKey) { $SupabaseAnonKey = $cfg['SUPABASE_ANON_KEY'] }
if (-not $AppEnv) { $AppEnv = $cfg['APP_ENV'] }
if (-not $AppEnv) { $AppEnv = 'production' }

if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
  throw @'
SUPABASE_ANON_KEY is empty.

Set it in .env (it is not read automatically) or pass it with
  -SupabaseAnonKey sb_publishable_...

Without it the build still succeeds but ships a client with no key, and every
request fails with "No API key found in request".
'@
}

# APP_ENV is compared with == in AppConfig.isProduction, so a stray inline
# comment would silently disable production behaviour.
$AppEnv = ($AppEnv -split '\s+#', 2)[0].Trim()

Write-Step "Supabase URL : $($cfg['SUPABASE_URL']) (defaults in app_config.dart)"
Write-Step "App env      : $AppEnv"
Write-Step "Key          : $($SupabaseAnonKey.Substring(0, [Math]::Min(12, $SupabaseAnonKey.Length)))..."

Push-Location $projectRoot
try {
  $defines = @(
    "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
    "--dart-define=APP_ENV=$AppEnv"
  )

  $flutterArgs = @('build', 'web')
  if (-not $NoRelease) { $flutterArgs += '--release' }
  $flutterArgs += $defines

  # Redacted in the log so a build transcript does not carry the key. It is
  # a publishable key and safe in a client bundle, but it need not be printed.
  Write-Step "flutter build web --dart-define=SUPABASE_ANON_KEY=<$($SupabaseAnonKey.Substring(0, 12))...> --dart-define=APP_ENV=$AppEnv"
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE" }

  $bundle = Join-Path $projectRoot 'build\web\main.dart.js'
  if (-not (Test-Path -LiteralPath $bundle)) {
    throw "Expected bundle not found: $bundle"
  }

  Write-Step 'Verifying the built bundle'
  $js = [System.IO.File]::ReadAllText($bundle)

  if (-not $js.Contains($SupabaseAnonKey)) {
    throw @'
The key is NOT in the built bundle.

The build reported success, so this is almost always a --dart-define that was
dropped. Check that the key is passed as a single argument with no stray
whitespace or quotes, then rebuild.
'@
  }
  Write-Host '    key present in main.dart.js' -ForegroundColor Green

  if ($js.Contains('xcotognshgxvxmxpyinw')) {
    throw 'The retired Supabase project ref is still baked into the bundle.'
  }

  if ($AppEnv -eq 'production' -and $js.Contains('io.supabase.tripsplitworld')) {
    throw @'
The mobile deep-link redirect is present in a production build.
Check APP_ENV is exactly "production".
'@
  }

  $sizeMb = [math]::Round(
    ((Get-ChildItem (Join-Path $projectRoot 'build\web') -Recurse -File |
        Measure-Object Length -Sum).Sum / 1MB), 2)
  Write-Host "    build\web ready ($sizeMb MB)" -ForegroundColor Green
  Write-Step 'Build OK'
}
finally {
  Pop-Location
}