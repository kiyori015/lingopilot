param(
  [string]$ProjectRef = "ieakvpwzhihqttcxegti",
  [string]$AppUrl = "https://kiyori015.github.io/lingopilot/"
)

$ErrorActionPreference = "Stop"

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

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw "SUPABASE_ACCESS_TOKEN is required. Create one in Supabase Dashboard > Account > Access Tokens."
}

if (-not $env:SUPABASE_DB_PASSWORD -and -not $env:SUPABASE_DB_URL) {
  throw "SUPABASE_DB_PASSWORD or SUPABASE_DB_URL is required to push migrations."
}

if (-not $env:LINGOPILOT_LOGIN_PEPPER) {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $env:LINGOPILOT_LOGIN_PEPPER = [Convert]::ToBase64String($bytes)
  Write-Host "Generated LINGOPILOT_LOGIN_PEPPER for this session."
}

Write-Host "Logging in to Supabase CLI..."
npx supabase login --token $env:SUPABASE_ACCESS_TOKEN

Write-Host "Applying database migrations..."
if ($env:SUPABASE_DB_URL) {
  npx supabase db push --db-url $env:SUPABASE_DB_URL
} else {
  npx supabase db push --linked --password $env:SUPABASE_DB_PASSWORD
}

Write-Host "Setting Edge Function secrets..."
$secretArgs = @(
  "LINGOPILOT_LOGIN_PEPPER=$env:LINGOPILOT_LOGIN_PEPPER",
  "LINGOPILOT_APP_URL=$AppUrl"
)

npx supabase secrets set --project-ref $ProjectRef @secretArgs

Write-Host "Deploying lingopilot-auth Edge Function..."
npx supabase functions deploy lingopilot-auth --project-ref $ProjectRef --no-verify-jwt --use-api

Write-Host "Done. Verify registration from the app admin screen."
