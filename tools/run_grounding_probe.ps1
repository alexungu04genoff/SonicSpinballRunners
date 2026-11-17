[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('interactive','audit','visual','matrix','tour','smoke','lifecycle','controls','proxy-sweep')][string]$Task = 'smoke',
    [ValidateSet('prototype','endless')][string]$Runtime = 'prototype',
    [string]$Theme = 'rooftop_run',
    [ValidateSet('production','shadow-light','balanced','balanced-no-retro','reduced-retro')][string]$Quality = 'production',
    [ValidateSet('forward_plus','mobile','gl_compatibility')][string]$Renderer = 'forward_plus',
    [double]$Seconds = 3,
    [int]$TimeoutSeconds = 240,
    [switch]$Interactive,
    [switch]$Detailed,
    [switch]$EngineVerbose
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path $PSScriptRoot -Parent }
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new result folder.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
# A second Godot process invalidates these comparisons. Do not stop an editor
# or another chat's run; fail with a useful receipt and let the user close it.
$otherEngines = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(Godot|Sonic Spinball Runners)' } | Select-Object Id,ProcessName)
if ($otherEngines.Count) {
    [IO.File]::WriteAllText((Join-Path $output 'concurrent-processes.json'), ($otherEngines | ConvertTo-Json))
    throw 'Another Godot/editor/lab process is running. Close it before starting this matrix.'
}
$driver = if ($Renderer -eq 'gl_compatibility') { 'opengl3_angle' } else { 'vulkan' }
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', $Renderer, '--rendering-driver', $driver,
    '--script', 'res://tests/grounding_lab.gd', '--', '--seed=18', '--retro=production', '--profile-stages', '--grounding-lab',
    ('--grounding-task=' + $Task), ('--grounding-runtime=' + $Runtime), ('--theme=' + $Theme),
    ('--grounding-quality=' + $Quality), ('--grounding-seconds=' + $Seconds.ToString([Globalization.CultureInfo]::InvariantCulture)),
    ('"--output={0}"' -f $output))
if ($Quality -eq 'balanced-no-retro') { $arguments += '--grounding-retro=off' }
elseif ($Quality -eq 'reduced-retro') { $arguments += '--grounding-retro=n64' }
if ($Detailed) { $arguments += '--grounding-detailed' }
if ($EngineVerbose) { $arguments = @('--verbose') + $arguments }
$instrumentHashes = @{}
# Use the built-in .NET implementation so the portable launcher also works
# when another PowerShell installation supplied the inherited module path.
$hasher = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($relative in @('tests/grounding_lab.gd','scripts/diagnostics/render_audit.gd','scripts/diagnostics/render_sampler.gd','scripts/diagnostics/grounding_control.gd','scripts/diagnostics/scenery_shadow_trial.gd')) {
        $stream = [IO.File]::OpenRead((Join-Path $project $relative))
        try { $instrumentHashes[$relative] = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose() }
    }
} finally { $hasher.Dispose() }
# Isolate Godot application preferences and telemetry. Native graphics-driver
# caches may still be shared; the report never labels these runs driver-cold.
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$privateAppData = Join-Path $project 'diagnostic-user\Roaming'
$privateLocalAppData = Join-Path $project 'diagnostic-user\Local'
New-Item -ItemType Directory -Path $privateAppData,$privateLocalAppData -Force | Out-Null
$start = [Diagnostics.Stopwatch]::StartNew()
$process = $null
$timedOut = $false
$scriptError = $false
$errorLength = 0L
try {
    $env:APPDATA = $privateAppData
    $env:LOCALAPPDATA = $privateLocalAppData
    $launch = @{FilePath=$GodotPath;ArgumentList=$arguments;WorkingDirectory=$project;PassThru=$true;
        RedirectStandardOutput=(Join-Path $output 'console.log');RedirectStandardError=(Join-Path $output 'errors.log')}
    if (-not $Interactive) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    # Retain the native handle before WaitForExit. Windows PowerShell 5.1 can
    # otherwise return a null ExitCode after the child has already terminated.
    $nativeHandle = $process.Handle
    while (-not $process.WaitForExit(500)) {
        $errorFile = Get-Item -LiteralPath (Join-Path $output 'errors.log')
        if ($errorFile.Length -ne $errorLength) {
            $errorLength = $errorFile.Length
            if (Select-String -LiteralPath $errorFile.FullName -Pattern 'SCRIPT ERROR:' -Quiet) {
                $scriptError = $true
                $process.Kill()
                $process.WaitForExit()
                break
            }
        }
        if (-not $Interactive -and $start.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            $timedOut = $true
            $process.Kill()
            $process.WaitForExit()
            break
        }
    }
    $process.Refresh()
    $receipt = @{renderer_requested=$Renderer;driver_requested=$driver;arguments=$arguments;elapsed_seconds=$start.Elapsed.TotalSeconds;
        process_cpu_seconds=$process.TotalProcessorTime.TotalSeconds;exit_code=$process.ExitCode;timed_out=$timedOut;script_error=$scriptError;instrumentation_sha256=$instrumentHashes;
        cache_directory=(Join-Path $project 'diagnostic-user');
        source='Bundled engine process; OS CPU time includes startup, all phases and cleanup, not per-frame CPU attribution. Private driver/engine caches may be warm; graphics preferences use a new explicit path for every run.'}
    [IO.File]::WriteAllText((Join-Path $output 'process.json'), ($receipt | ConvertTo-Json -Depth 5))
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
if ($timedOut) { throw "Diagnostic exceeded $TimeoutSeconds seconds; partial results retained in $output" }
if ($process.ExitCode -ne 0) { throw "Diagnostic failed with exit code $($process.ExitCode): $output" }
if (Select-String -LiteralPath (Join-Path $output 'errors.log') -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet) { throw "Diagnostic logged errors: $output" }
Write-Output "GROUNDING_PROBE_OK | $output"
