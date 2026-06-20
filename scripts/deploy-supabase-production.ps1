param(
  [string]$ProjectRef = "ieakvpwzhihqttcxegti",
  [string]$AppUrl = "https://kiyori015.github.io/lingopilot/"
)

$ErrorActionPreference = "Stop"

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

if ($env:SUPABASE_SERVICE_ROLE_KEY) {
  $secretArgs += "SUPABASE_SERVICE_ROLE_KEY=$env:SUPABASE_SERVICE_ROLE_KEY"
}

npx supabase secrets set --project-ref $ProjectRef @secretArgs

Write-Host "Deploying lingopilot-auth Edge Function..."
npx supabase functions deploy lingopilot-auth --project-ref $ProjectRef --no-verify-jwt --use-api

Write-Host "Done. Verify registration from the app admin screen."
