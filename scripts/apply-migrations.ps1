# DBマイグレーションだけを本番Supabaseに適用するスクリプト。
# 使い方:  pwsh ./scripts/apply-migrations.ps1
# .env.local の SUPABASE_DB_PASSWORD を使い、プーラー(ap-south-1)経由で supabase db push を実行する。
param(
  [string]$ProjectRef = "ieakvpwzhihqttcxegti",
  [string]$PoolerHost = "aws-1-ap-south-1.pooler.supabase.com"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($file in @(".env", ".env.local")) {
  $path = Join-Path $repoRoot $file
  if (-not (Test-Path -LiteralPath $path)) { continue }
  Get-Content -LiteralPath $path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $i = $line.IndexOf("=")
    if ($i -lt 1) { return }
    $name = $line.Substring(0, $i).Trim()
    $value = $line.Substring($i + 1).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    if (-not (Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue)) {
      Set-Item -LiteralPath "Env:$name" -Value $value
    }
  }
}

if (-not $env:SUPABASE_DB_PASSWORD) {
  throw "SUPABASE_DB_PASSWORD が .env.local にありません。"
}

# Supabase CLIの状態をリポジトリ内に隔離（Windowsのファイルロック対策）
$supabaseHome = Join-Path $repoRoot "temp\supabase-home"
New-Item -ItemType Directory -Force -Path $supabaseHome | Out-Null
$env:USERPROFILE = (Resolve-Path $supabaseHome).Path
$env:HOME = $env:USERPROFILE
$env:SUPABASE_DISABLE_TELEMETRY = "1"

$encodedPassword = [uri]::EscapeDataString($env:SUPABASE_DB_PASSWORD)
$dbUrl = "postgresql://postgres.${ProjectRef}:$encodedPassword@${PoolerHost}:5432/postgres"

Set-Location $repoRoot
Write-Host "Applying migrations via $PoolerHost ..."
npx supabase db push --db-url $dbUrl
Write-Host "Done."
