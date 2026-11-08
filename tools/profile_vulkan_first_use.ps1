[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputDirectory = '',
    [string[]]$Themes = @('green_hill', 'chemical_plant', 'aquarium_park', 'ice_cap'),
    [ValidateSet('prototype', 'endless')][string]$Mode = 'prototype',
    [ValidateSet('vulkan_first_use_profile', 'vulkan_resource_probe')][string]$ProfileScript = 'vulkan_first_use_profile',
    [string]$SeedProfile = '',
    [ValidateSet('shader', 'pipeline', 'all')][string]$SeedCache = 'all',
    [switch]$SingleRun,
    [switch]$VerboseEngine,
    [string[]]$DiagnosticArguments = @()
)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'endless' -and $ProfileScript -eq 'vulkan_first_use_profile' -and $Themes.Count -ne 1) {
    throw 'Endless is one seed-18 multi-theme tour. Supply one -Themes value as its output label; it does not select the tour themes.'
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (Test-Path -LiteralPath (Join-Path $ProjectRoot '.godot\shader_cache')) {
    throw 'Use a frozen source copy without .godot/shader_cache. An isolated user profile cannot exclude that project-side cache seed.'
}
function Get-GodotProcesses {
    @(Get-CimInstance Win32_Process -Filter "Name='Godot.exe' OR Name='Geometry Editor.exe' OR Name='Atmosphere Lab.exe'")
}
if (Get-GodotProcesses) {
    throw 'Finish other Godot/editor processes, including headless bakes and tests, before measuring.'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $ProjectRoot ('test-results\vulkan-first-use\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory. Existing evidence and profiles are never erased.' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
function Get-CacheReceipt([string]$CacheProfile) {
    @(Get-ChildItem -LiteralPath $CacheProfile -File -Recurse | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($CacheProfile, $_.FullName)
        if ($relative -match '(^|[\\/])(shader_cache|pipeline_cache)[\\/]|(^|[\\/])pipelines\.[^\\/]*\.cache$') {
            @{ path = $relative; bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
        }
    })
}
try {
    foreach ($theme in $Themes) {
        $isolatedProfile = Join-Path $OutputDirectory "$theme-profile"
        $env:APPDATA = Join-Path $isolatedProfile 'roaming'
        $env:LOCALAPPDATA = Join-Path $isolatedProfile 'local'
        New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
        if ($SeedProfile) {
            foreach ($item in (Get-CacheReceipt $SeedProfile)) {
                $shader = $item.path -match 'shader_cache'
                if (($SeedCache -eq 'shader' -and -not $shader) -or ($SeedCache -eq 'pipeline' -and $shader)) { continue }
                $target = Join-Path $isolatedProfile $item.path
                New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
                Copy-Item -LiteralPath (Join-Path $SeedProfile $item.path) -Destination $target
            }
        }
        $conditions = if ($SingleRun) { @('cold') } else { @('cold', 'warm') }
        foreach ($condition in $conditions) {
            $name = "$theme-$condition"
            $before = @(Get-CacheReceipt $isolatedProfile)
            $arguments = @('--path', ('"{0}"' -f $ProjectRoot), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan',
                '--audio-driver', 'Dummy', '--log-file', ('"{0}"' -f (Join-Path $OutputDirectory "$name-engine.log")),
                '--script', "res://tests/$ProfileScript.gd", '--', '--seed=18', '--profile-stages', "--profile-theme=$theme", "--profile-mode=$Mode",
                ('"--profile-output={0}"' -f (Join-Path $OutputDirectory "$name.json").Replace('\', '/'))) + $DiagnosticArguments
            # Verbose shader-cache messages can dominate startup on Windows.
            # Enable them only for cache-consumption evidence, not timing claims.
            if ($VerboseEngine) { $arguments = @('--verbose') + $arguments }
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory "$name.log") -RedirectStandardError (Join-Path $OutputDirectory "$name.err")
            $overlap = @()
            while (-not $process.WaitForExit(2000)) {
                $overlap += @(Get-GodotProcesses | Where-Object { $_.ProcessId -ne $process.Id } | Select-Object ProcessId, CommandLine)
                if ($watch.Elapsed.TotalSeconds -gt 600) { Stop-Process -Id $process.Id; throw "$name exceeded ten minutes" }
            }
            $watch.Stop()
            $after = @(Get-CacheReceipt $isolatedProfile)
            @{ condition = $(if ($SeedProfile -and $condition -eq 'cold') { 'seeded-' + $SeedCache } else { $condition }); process_wall_ms = $watch.Elapsed.TotalMilliseconds; exit_code = $process.ExitCode;
                project = $ProjectRoot; engine_sha256 = (Get-FileHash -LiteralPath $GodotPath).Hash; before = $before; after = $after;
                driver_cache = 'Uncontrolled; never deleted'; seed_profile = $SeedProfile; seed_cache = $SeedCache;
                other_renderer_processes = $overlap; arguments = $arguments } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $OutputDirectory "$name-process.json")
            if ($overlap.Count) { throw "$name overlapped another Godot job. Evidence is retained but timings are invalid." }
            if ($process.ExitCode -ne 0) { throw "$name failed. See $OutputDirectory" }
            if (Select-String -LiteralPath (Join-Path $OutputDirectory "$name.err") -Pattern '^SCRIPT ERROR:' -Quiet) {
                throw "$name reported a script error. See $OutputDirectory"
            }
            $report = Get-Content -LiteralPath (Join-Path $OutputDirectory "$name.json") -Raw | ConvertFrom-Json
            if (-not $report.success) { throw "$name reported invalid/stale bakes or incomplete preparation." }
            $worst = ($report.frames | Measure-Object -Property frame_ms -Maximum).Maximum
            $ready = if ($null -eq $report.ready_from_engine_ms) { 'n/a' } else { '{0:N0} ms' -f $report.ready_from_engine_ms }
            Write-Output ("{0}: ready from engine start {1}, largest completion {2:N0} ms, cache files {3}" -f $name, $ready, $worst, $after.Count)
        }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
Write-Output "Evidence: $OutputDirectory"
