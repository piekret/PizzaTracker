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

$exitCode = 0
Push-Location -LiteralPath $projectRoot
try {
  & flutter run "--dart-define=SUPABASE_URL=$supabaseUrl" "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey" @args
  $exitCode = $LASTEXITCODE
}
finally {
  Pop-Location
}

exit $exitCode
