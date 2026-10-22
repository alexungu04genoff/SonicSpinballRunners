[CmdletBinding()]
param(
    [string]$GodotPath,
    [ValidateSet('gameplay', 'idle', 'jump', 'trick', 'roll', 'reel')]
    [string]$Capture,
    [switch]$Sequence,
    [ValidateRange(10, 10000)]
    [int]$CaptureFrames = 75,
    [switch]$ImportOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scenePath = 'res://experiments/visual_lab/visual_lab.tscn'

if ($Sequence -and -not $Capture) {
    throw '-Sequence requires -Capture gameplay, idle, jump, trick, roll, or reel.'
}

if ($Capture -eq 'reel' -and -not $Sequence) {
    throw '-Capture reel requires -Sequence.'
}

if ($GodotPath) {
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot executable does not exist: $GodotPath"
    }
    $resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
} else {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Godot\Godot.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
    )
    foreach ($commandName in @('godot4.exe', 'godot.exe', 'godot')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            $candidates = @($command.Source) + $candidates
        }
    }
    $resolvedGodot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $resolvedGodot) {
        throw 'Godot was not found. Pass -GodotPath with the full path to a Godot 4 executable.'
    }
}

Write-Host "Using Godot: $resolvedGodot"
Write-Host "Target worktree: $repoRoot"
# Register global script classes in a fresh worktree using a separate process.
& $resolvedGodot --headless --path $repoRoot --editor --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE. Read the output above for details."
}
if ($ImportOnly) {
    return
}

$assetPath = Join-Path $PSScriptRoot 'local\runtime\sonic.glb'
if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
    Write-Warning 'Local Sonic GLB is missing. The scene will use its spin-ball fallback. See README.md for preparation.'
}

$launchArguments = @('--path', $repoRoot, $scenePath)
if ($Capture) {
    $launchArguments = @('--fixed-fps', '60') + $launchArguments
    $launchArguments += @('--', "--capture=$Capture", "--capture-frames=$CaptureFrames")
    if ($Sequence) {
        $launchArguments += '--sequence'
    }
}
# Run only the requested scene. Never alter project.godot or stop another game/editor.
& $resolvedGodot @launchArguments
if ($LASTEXITCODE -ne 0) {
    throw "Visual lab exited with code $LASTEXITCODE."
}
