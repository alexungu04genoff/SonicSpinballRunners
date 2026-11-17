[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe'
)
# The existing supported 32-suite baseline, once per invocation. This is a
# build-machine runner, not part of the Thursday laptop matrix.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new baseline result directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$rendered = @('authored_gimmick','pinball_mechanics','soft_retry','ramp_height_theme','endless_reuse',
    'foreground_contribution','traversal_prototype','prototype_setup','prototype_budget','prototype_run','prototype_archive','prototype_appearance')
$suites = @('authored_gimmick','pinball_mechanics','soft_retry','ramp_height_theme','theme_texture','endless_reuse',
    'scorecraft','buddy_scoring','enemy','authored_main_game','traversal_authoring','traversal_prototype',
    'flipper_contact_response','telemetry_evidence','prototype_plan','prototype_setup','prototype_archive',
    'foreground_contribution','geometry_bake','act_geometry','geometry_density','economy_v1','pinball_vocabulary',
    'gimmick_batch','scoring_flow','rail_rings','profile','prototype_budget','prototype_run','run_telemetry','prototype_appearance','endless_bake_audit')
$results = [Collections.Generic.List[object]]::new()
$savedAppData = $env:APPDATA
$env:APPDATA = Join-Path $output 'isolated-user'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
try {
    foreach ($suite in $suites) {
        $script = if ($suite -eq 'endless_bake_audit') { $suite } else { $suite + '_regression' }
        $arguments = @('--path',('"' + $project + '"'),'--script',('res://tests/' + $script + '.gd'))
        if ($suite -in $rendered) { $arguments += @('--rendering-method','forward_plus','--rendering-driver','vulkan') }
        else { $arguments += '--headless' }
        if ($suite -eq 'endless_bake_audit') { $arguments += @('--','--prototype') }
        $log = Join-Path $output ($suite + '.log')
        $errors = Join-Path $output ($suite + '-errors.log')
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
        $nativeHandle = $process.Handle
        $timeout = $false
        $scriptError = $false
        while (-not $process.WaitForExit(500)) {
            if (Select-String -LiteralPath $errors -Pattern 'SCRIPT ERROR:' -Quiet) { $scriptError = $true; break }
            if ($clock.Elapsed.TotalSeconds -gt 900) { $timeout = $true; break }
        }
        if ($timeout -or $scriptError) { $process.Kill(); $process.WaitForExit() }
        $lines = @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'RESULT|REGRESSION|CONTACT RESPONSE|GEOMETRY_DENSITY|ENDLESS_BAKE_AUDIT|regression checks' })
        $entry = @{suite=$suite;exit_code=$process.ExitCode;timed_out=$timeout;script_error=$scriptError;seconds=$clock.Elapsed.TotalSeconds;rendered=($suite -in $rendered);results=$lines}
        $results.Add($entry)
        [IO.File]::WriteAllText((Join-Path $output 'baseline.json'), ($results | ConvertTo-Json -Depth 5))
        Write-Output ($suite + ' | exit=' + $process.ExitCode + ' | ' + ($lines -join '; '))
    }
} finally { $env:APPDATA = $savedAppData }
if (@($results | Where-Object { $_.exit_code -ne 0 -or $_.timed_out }).Count) { throw 'Baseline has failures; inspect baseline.json and the original logs.' }
Write-Output 'SUPPORTED_BASELINE_COMPLETE | suites=32'
