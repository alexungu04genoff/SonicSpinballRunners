[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string]$OutputDirectory = ''
)
# Optional current-code measurement. This does not replace or modify Thursday's package.
# Requires the current checkout and its existing validated Rooftop recipes; never bakes.
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $project ('test-results\theme-motion\optional-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh optional benchmark output directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$cases = @(
    @{label='current'; state='C'; tier='NATIVE'},
    @{label='clock-signature'; state='A'; tier='SIGNATURE'},
    @{label='static'; state='C'; tier='STATIC'}
)
$rows = @()
foreach ($case in $cases) {
    $destination = Join-Path $output $case.label
    & (Join-Path $PSScriptRoot 'run_theme_motion.ps1') -GodotPath $GodotPath -OutputDirectory $destination -BenchmarkOnly -Themes @('rooftop_run') -States @($case.state) -Tier $case.tier -Focus right
    $manifest = Get-Content -LiteralPath (Join-Path $destination 'manifest.json') -Raw | ConvertFrom-Json
    if (-not $manifest.complete) { throw ('Incomplete optional case: ' + $case.label) }
    $measurement = $manifest.rows[0].benchmark
    $rows += [pscustomobject]@{
        case=$case.label; candidate=$case.state; tier=$case.tier
        median_ms=$measurement.frame.median_ms; p95_ms=$measurement.frame.p95_ms
        p99_ms=$measurement.frame.p99_ms; max_ms=$measurement.frame.max_ms
        draws=$measurement.counters.draws; primitives=$measurement.counters.primitives
        motion_ms=$measurement.motion_update.median_ms
    }
}
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'optional-motion.json')
$rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $output 'optional-motion.csv')
Write-Output ('OPTIONAL_MOTION_COMPLETE | ' + $output)
