param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$Capture,
    [ValidateSet('opengl3', 'opengl3_angle')][string]$RenderingDriver = 'opengl3'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $project 'docs/commerce-evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
foreach ($suite in @(
    @('commerce_tests', 'COMMERCE_RESULT'),
    @('week9_tests', 'WEEK9_RESULT'),
    @('creature_tests', 'CREATURE_RESULT')
)) {
    $output = & $GodotPath --headless --path $project --script "res://tests/$($suite[0]).gd" --quit-after 2400 2>&1
    $exit = $LASTEXITCODE
    $log = Join-Path $evidence "$($suite[0]).log"
    $output | Set-Content -LiteralPath $log -Encoding utf8
    $result = $output | Select-String "$($suite[1]) passed=\d+ failed=0"
    if ($exit -ne 0 -or -not $result -or ($output -match 'SCRIPT ERROR|Parse Error|ERROR:')) {
        $output | Write-Output
        throw "Suite failed: $($suite[0])"
    }
    Write-Output $result
}
if ($Capture) {
    $captures = @()
    foreach ($kind in @('title', 'hud', 'shop', 'backpack', 'pause', 'combat')) {
        foreach ($size in @('wide', 'small')) {
            $captures += @{ Kind = $kind; Size = $size; Bottom = $false }
        }
    }
    $captures += @{ Kind = 'title_shop'; Size = 'wide'; Bottom = $false }
    $captures += @{ Kind = 'shop'; Size = 'small'; Bottom = $true }
    foreach ($shot in $captures) {
        $kind = $shot.Kind
        $size = $shot.Size
        $suffix = if ($shot.Bottom) { "$size-bottom" } else { $size }
        $arguments = @('--path', $project, '--audio-driver', 'Dummy', '--rendering-method',
            'gl_compatibility', '--rendering-driver', $RenderingDriver,
            '--script', 'res://tests/capture_commerce.gd', '--', $kind)
        if ($size -eq 'small') { $arguments += 'small' }
        if ($shot.Bottom) { $arguments += 'bottom' }
        $output = & $GodotPath @arguments 2>&1
        $exit = $LASTEXITCODE
        @("EXIT_CODE=$exit") + $output | Set-Content -LiteralPath (Join-Path $evidence "$kind-$suffix.log") -Encoding utf8
        $image = Join-Path $evidence "$kind-$suffix.png"
        if ($exit -ne 0 -or ($output -match 'SCRIPT ERROR|Parse Error|ERROR:') -or
            -not ($output -match 'COMMERCE_CAPTURE .* status=0') -or
            -not (Test-Path -LiteralPath $image) -or (Get-Item -LiteralPath $image).Length -eq 0) {
            $output | Write-Output
            throw "Render failed: $kind/$suffix (exit $exit)"
        }
        Write-Output "Rendered $kind/$suffix"
    }
}
