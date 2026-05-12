$ErrorActionPreference = 'Stop'

function Read-DotEnv {
  param([string] $Path)

  $values = @{}
  foreach ($line in [System.IO.File]::ReadLines($Path)) {
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) {
      continue
    }

    if ($trimmed.StartsWith('export ')) {
      $trimmed = $trimmed.Substring(7).TrimStart()
    }

    $parts = $trimmed -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($value.Length -ge 2) {
      $first = $value[0]
      $last = $value[$value.Length - 1]
      if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
        $value = $value.Substring(1, $value.Length - 2)
      }
    }

    $values[$key] = $value
  }

  return $values
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'

if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  [Console]::Error.WriteLine('Missing .env in the project root.')
  exit 1
}

$envValues = Read-DotEnv -Path $envPath
$supabaseUrl = $envValues['SUPABASE_URL']
$supabaseAnonKey = $envValues['SUPABASE_ANON_KEY']

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  [Console]::Error.WriteLine('SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env.')
  exit 1
}

$assetEnvDir = Join-Path $projectRoot 'assets/env'
New-Item -ItemType Directory -Path $assetEnvDir -Force | Out-Null

$content = @(
  '# Client-safe Flutter config only.'
  '# assets/env/client.env is bundled for local `flutter run`, so never add server secrets here.'
  ''
  "SUPABASE_URL=$supabaseUrl"
  "SUPABASE_ANON_KEY=$supabaseAnonKey"
)

$encoding = New-Object System.Text.UTF8Encoding($false)
$targets = @(
  (Join-Path $projectRoot '.env.client')
  (Join-Path $assetEnvDir 'client.env')
)

foreach ($target in $targets) {
  $text = ($content -join [Environment]::NewLine) + [Environment]::NewLine
  [System.IO.File]::WriteAllText($target, $text, $encoding)
}

[Console]::WriteLine('Updated .env.client and assets/env/client.env with client-safe Supabase values.')
