param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$SupabaseArgs
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
  $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pwsh) {
    throw "PowerShell 7 (pwsh) is required but was not found."
  }

  & $pwsh -NoLogo -NoProfile -File $PSCommandPath @SupabaseArgs
  exit $LASTEXITCODE
}

function Import-DotEnvFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) {
      return
    }

    $separatorIndex = $line.IndexOf("=")
    if ($separatorIndex -lt 1) {
      return
    }

    $name = $line.Substring(0, $separatorIndex).Trim()
    $value = $line.Substring($separatorIndex + 1).Trim()

    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    if (-not (Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue)) {
      Set-Item -LiteralPath "Env:$name" -Value $value
    }
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-DotEnvFile -Path (Join-Path $repoRoot ".env")
Import-DotEnvFile -Path (Join-Path $repoRoot ".env.local")

$supabaseHome = Join-Path $repoRoot "temp\supabase-home"
New-Item -ItemType Directory -Force -Path $supabaseHome | Out-Null
$resolvedHome = (Resolve-Path $supabaseHome).Path

$env:USERPROFILE = $resolvedHome
$env:HOME = $resolvedHome
$env:SUPABASE_DISABLE_TELEMETRY = "1"

if (-not $SupabaseArgs.Count) {
  Write-Host "Usage: ./scripts/invoke-supabase-cli.ps1 <supabase args>"
  Write-Host "Example: ./scripts/invoke-supabase-cli.ps1 projects list"
  exit 1
}

Write-Host "Using pwsh $($PSVersionTable.PSVersion) with HOME=$resolvedHome"
& npx supabase @SupabaseArgs
exit $LASTEXITCODE
