[CmdletBinding()]
param(
    [string]$GodotPath,
    [ValidateRange(0, 2147483647)]
    [int]$Seed = 18,
    [ValidateSet('Catalogue', 'Base', 'Variant')]
    [string]$Grid = 'Catalogue',
    [switch]$Playground,
    [switch]$NoModel,
    [ValidateSet('gameplay', 'idle', 'jump', 'trick', 'roll', 'reel')]
    [string]$Capture,
    [switch]$Sequence,
    [ValidateRange(10, 10000)]
    [int]$CaptureFrames = 75,
    [switch]$ImportOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scenePath = if ($Playground) { 'res://scenes/playground.tscn' } else { 'res://experiments/visual_lab/visual_lab.tscn' }

if ($Playground -and $Capture) {
    throw 'Capture options target Green Hill; omit -Playground.'
}

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
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'),
        (Join-Path $env:ProgramFiles 'Godot\Godot.exe')
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
# Explicit waiting also supports Godot's GUI executable under Windows PowerShell.
$logDirectory = Join-Path $repoRoot '.godot'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$importOutput = Join-Path $logDirectory 'green-hill-import.log'
$importErrors = Join-Path $logDirectory 'green-hill-import-errors.log'
$importProcess = Start-Process -FilePath $resolvedGodot -ArgumentList @('--headless', '--path', ('"{0}"' -f $repoRoot), '--editor', '--quit') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $importOutput -RedirectStandardError $importErrors
$diagnostics = (Get-Content -LiteralPath $importOutput -Raw) + (Get-Content -LiteralPath $importErrors -Raw)
Write-Host $diagnostics
if ($importProcess.ExitCode -ne 0 -or $diagnostics -match '(?m)^(SCRIPT ERROR|ERROR):') {
    throw "Godot import failed. Read the output above for details."
}
if ($ImportOnly) {
    return
}

$assetPath = Join-Path $PSScriptRoot 'local\runtime\sonic.glb'
if (-not $Playground -and -not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
    Write-Warning 'Local Sonic GLB is missing. The scene will use its spin-ball fallback. See README.md for preparation.'
}

$launchArguments = @('--path', $repoRoot, $scenePath)
$userArguments = @("--seed=$Seed", "--grid=$(@{Catalogue=0; Base=1; Variant=2}[$Grid])")
if ($NoModel) { $userArguments += '--no-model' }
if ($Capture) {
    $launchArguments = @('--fixed-fps', '60') + $launchArguments
    $userArguments += @("--capture=$Capture", "--capture-frames=$CaptureFrames")
    if ($Sequence) {
        $userArguments += '--sequence'
    }
}
$launchArguments += @('--') + $userArguments
# Run only the requested scene. Never alter project.godot or stop another game/editor.
$quotedArguments = $launchArguments | ForEach-Object { '"{0}"' -f $_ }
# This is the interactive game window requested by the player.
$gameProcess = Start-Process -FilePath $resolvedGodot -ArgumentList $quotedArguments -Wait -PassThru
if ($gameProcess.ExitCode -ne 0) {
    throw "Game exited with code $($gameProcess.ExitCode)."
}
