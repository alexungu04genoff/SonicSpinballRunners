[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string[]]$Scripts = @('editor_qualification_regression', 'editor_workspace_regression'),
    [switch]$Rendered
)
# Run against an imported disposable snapshot. Fixtures write to its test-results
# and each suite receives an isolated profile. Only explicit restart phases share it.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new qualification result directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$results = [Collections.Generic.List[object]]::new()
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
try {
    foreach ($script in $Scripts) {
        if ($script -notmatch '^[a-z0-9_]+$') { throw "Invalid test script name: $script" }
        $env:APPDATA = Join-Path $output "$script-profile"
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $phases = if ($script -in @('editor_qualification_regression', 'editor_workspace_regression')) { @('initial', 'restart') } else { @('initial') }
        foreach ($phase in $phases) {
            $name = "$script-$phase"
            $arguments = @('--path', ('"' + $project + '"'), '--script', "res://tests/$script.gd")
            if ($Rendered) { $arguments += @('--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan') }
            else { $arguments += '--headless' }
            if ($phase -eq 'restart') { $arguments += @('--', '--restart') }
            $log = Join-Path $output "$name.log"
            $errors = Join-Path $output "$name-errors.log"
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
            $nativeHandle = $process.Handle
            $scriptError = $false
            $timedOut = $false
            while (-not $process.WaitForExit(500)) {
                if (Select-String -LiteralPath $errors -Pattern '^SCRIPT ERROR:' -Quiet) { $scriptError = $true; break }
                if ($clock.Elapsed.TotalSeconds -gt 300) { $timedOut = $true; break }
            }
            if ($scriptError -or $timedOut) { $process.Kill(); $process.WaitForExit() }
            $scriptError = $scriptError -or [bool](Select-String -LiteralPath $errors -Pattern '^SCRIPT ERROR:' -Quiet)
            $summaries = @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'RESULT|REGRESSION|EDITOR QUALIFICATION|EDITOR WORKSPACE|checks.*failures' })
            $results.Add(@{script=$script;phase=$phase;exit_code=$process.ExitCode;script_error=$scriptError;timed_out=$timedOut;seconds=$clock.Elapsed.TotalSeconds;results=$summaries})
            [IO.File]::WriteAllText((Join-Path $output 'results.json'), ($results | ConvertTo-Json -Depth 5))
            Write-Output ("$name | exit=$($process.ExitCode) | " + ($summaries -join '; '))
            if ($phase -eq 'initial' -and ($scriptError -or $timedOut)) { break }
        }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
if (@($results | Where-Object { $_.exit_code -ne 0 -or $_.script_error -or $_.timed_out }).Count) {
    throw 'Editor qualification has failures; inspect results.json and original logs.'
}
Write-Output "ACT_EDITOR_CHECKS_COMPLETE | phases=$($results.Count)"
