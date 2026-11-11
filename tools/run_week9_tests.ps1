param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $project 'docs/week9-evidence'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$log = Join-Path $logs 'automated-tests.log'
& $GodotPath --headless --editor --path $project --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
& $GodotPath --headless --path $project --script 'res://tests/scenes/week9_tests.gd' --quit-after 2400 --log-file $log
$exitCode = $LASTEXITCODE
$text = Get-Content -LiteralPath $log -Raw
if ($exitCode -ne 0 -or $text -notmatch 'WEEK9_RESULT passed=\d+ failed=0' -or $text -match 'SCRIPT ERROR|Parse Error') {
    throw "Week 9 tests failed or did not finish. See $log"
}
Write-Output "Verified: $log"
