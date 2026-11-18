[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [switch]$BakeOnly
)
# Requires the disposable fixtures exported by editor_qualification_regression.gd.
# Uses the ordinary baker and real rendered Prototype, serially, with a private profile.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new authority result directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$results = [Collections.Generic.List[object]]::new()
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
function Invoke-Qualification([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $output "$Name.log"
    $errors = Join-Path $output "$Name-errors.log"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
    $handle = $process.Handle
    $timedOut = $false
    while (-not $process.WaitForExit(500)) {
        if ((Select-String -LiteralPath $errors -Pattern '^SCRIPT ERROR:' -Quiet) -or $timer.Elapsed.TotalSeconds -gt 600) {
            $timedOut = $timer.Elapsed.TotalSeconds -gt 600
            $process.Kill()
            $process.WaitForExit()
            break
        }
    }
    $problems = @(Get-Content -LiteralPath $errors | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch 'Failed to read the root certificate store' })
    $summary = @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'EDITOR AUTHORITY|BAKE_COMPLETE|BAKE_FAILED' })
    $results.Add(@{name=$Name;exit_code=$process.ExitCode;timed_out=$timedOut;seconds=$timer.Elapsed.TotalSeconds;errors=$problems;summary=$summary})
    [IO.File]::WriteAllText((Join-Path $output 'results.json'), ($results | ConvertTo-Json -Depth 5))
    Write-Output ("$Name | exit=$($process.ExitCode) | " + ($summary -join '; '))
    if ($process.ExitCode -ne 0 -or $timedOut -or $problems.Count) { throw "Qualification failed: $Name; inspect the original logs." }
}
try {
    $env:APPDATA = Join-Path $output 'isolated-user'
    $env:LOCALAPPDATA = $env:APPDATA
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $common = @('--path', ('"' + $project + '"'))
    foreach ($theme in @('green_hill','chemical_plant','casino_night','ice_cap','sky_sanctuary','rooftop_run','aquarium_park','lava_reef')) {
        $fixtures = if ($theme -eq 'green_hill') { @('dense','linked','linked_vertical','smoothed') } else { @('dense') }
        foreach ($fixture in $fixtures) {
            Invoke-Qualification "bake-$fixture-$theme" ($common + @('--headless','res://scenes/act_baker.tscn','--',"--theme=$theme","--act=res://test-results/editor-qualification-fixtures/$fixture.tres",'--quit-after-bake'))
            if (-not $BakeOnly) {
                Invoke-Qualification "prototype-$fixture-$theme" ($common + @('--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://tests/editor_authority_regression.gd','--',"--fixture=$fixture","--theme=$theme"))
            }
        }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
Write-Output "EDITOR_AUTHORITY_COMPLETE | runs=$($results.Count)"
