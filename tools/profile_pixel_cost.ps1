[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [ValidateSet('small', 'dense', 'multi', 'busy')][string[]]$Workloads = @('small', 'dense', 'multi', 'busy'),
    [int]$Samples = 600
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = Join-Path $repo ('test-results\pixel-cost\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $output | Out-Null
# Run alone: other Godot instances, exports and tests contaminate GPU timings.
if (Get-Process -Name 'Godot', 'Geometry Editor', 'Atmosphere Lab' -ErrorAction SilentlyContinue) { throw 'Close other Godot/editor/portable processes before measuring.' }
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $output 'profile'
    $env:LOCALAPPDATA = Join-Path $output 'local-profile'
    New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    & git -C $repo rev-parse HEAD | Set-Content (Join-Path $output 'base-commit.txt')
    & git -C $repo diff --binary | Set-Content (Join-Path $output 'worktree.diff')
    foreach ($workload in $Workloads) {
        $arguments = @('--path', ('"{0}"' -f $repo), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--audio-driver', 'Dummy',
            '--log-file', ('"{0}"' -f (Join-Path $output "$workload-engine.log")), '--script', 'res://tests/pixel_cost_profile.gd', '--', '--seed=18',
            "--workload=$workload", "--profile-samples=$Samples", ('"--profile-output={0}"' -f (Join-Path $output "$workload.json").Replace('\', '/')))
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $output "$workload.log") -RedirectStandardError (Join-Path $output "$workload.err")
        if (-not $process.WaitForExit(600000)) { Stop-Process -Id $process.Id; throw "$workload exceeded ten minutes" }
        if ($process.ExitCode -ne 0) { throw "$workload failed: $output" }
        $problems = Get-Content -LiteralPath (Join-Path $output "$workload.err") | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' }
        if ($problems) { throw "$workload reported renderer/script errors: $output" }
        $report = Get-Content -LiteralPath (Join-Path $output "$workload.json") -Raw | ConvertFrom-Json
        if ($report.failures -ne 0 -or $report.phases.Count -ne 10) { throw "$workload produced an invalid report" }
        Write-Output "$workload passed: $output"
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
Write-Output "Evidence: $output"
