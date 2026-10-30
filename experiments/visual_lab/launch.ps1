[CmdletBinding()]
param(
    [string]$GodotPath,
    [ValidateSet('Angle', 'Native')]
    [string]$GraphicsBackend = 'Angle',
    [ValidateSet('Sonic', 'Tails', 'Knuckles', 'Shadow')]
    [string]$Character = 'Sonic',
    [ValidateSet('gameplay', 'overview', 'idle', 'jump', 'trick', 'roll', 'reel', 'homing', 'impact', 'fly')]
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
    throw '-Sequence requires -Capture.'
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
# Even --import restores editor state. Use a private import profile so the user's
# tab-conversion preference cannot rewrite this project's space-indented scripts.
$godotVersion = (& $resolvedGodot --version | Out-String).Trim()
if ($godotVersion -notmatch '^(4)\.(\d+)\.') {
    throw "Expected Godot 4; received version: $godotVersion"
}
$settingsName = "editor_settings-$($Matches[1]).$($Matches[2]).tres"
$importProfile = Join-Path $logDirectory 'launcher-profile'
$settingsDirectory = Join-Path $importProfile 'Godot'
New-Item -ItemType Directory -Force -Path $settingsDirectory | Out-Null
$settings = @'
[gd_resource type="EditorSettings" format=3]

[resource]
text_editor/behavior/files/convert_indent_on_save = false
text_editor/behavior/files/restore_scripts_on_load = false
text_editor/behavior/indent/type = 1
text_editor/behavior/indent/size = 1
'@
[System.IO.File]::WriteAllText((Join-Path $settingsDirectory $settingsName), $settings, [System.Text.UTF8Encoding]::new($false))
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $importProfile
    $importProcess = Start-Process -FilePath $resolvedGodot -ArgumentList @('--headless', '--path', ('"{0}"' -f $repoRoot), '--import') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $importOutput -RedirectStandardError $importErrors
} finally {
    $env:APPDATA = $previousAppData
}
$diagnostics = (Get-Content -LiteralPath $importOutput -Raw) + (Get-Content -LiteralPath $importErrors -Raw)
Write-Host $diagnostics
if ($importProcess.ExitCode -ne 0 -or $diagnostics -match '(?m)^(SCRIPT ERROR|ERROR):') {
    throw "Godot import failed. Read the output above for details."
}
if ($ImportOnly) {
    return
}

# All characters currently use procedural ball form; local models are not required.

# Keep Godot's Compatibility renderer, but use Direct3D 11 through ANGLE by
# default. Native NVIDIA OpenGL crashed inside nvoglv64.dll during Zone rebuilds.
# This is a launch override; the user's project/editor settings stay untouched.
$renderingDriver = if ($GraphicsBackend -eq 'Angle') { 'opengl3_angle' } else { 'opengl3' }
$gameLog = Join-Path $logDirectory 'green-hill-game.log'
if (Test-Path -LiteralPath $gameLog -PathType Leaf) {
    Copy-Item -LiteralPath $gameLog -Destination (Join-Path $logDirectory 'green-hill-game.previous.log') -Force
}
Write-Host "Graphics backend: $GraphicsBackend ($renderingDriver)"
Write-Host "Game log: $gameLog"
$launchArguments = @('--path', $repoRoot, '--rendering-method', 'gl_compatibility', '--rendering-driver', $renderingDriver, '--log-file', $gameLog, $scenePath)
$userArguments = @("--character=$($Character.ToLowerInvariant())")
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
    $unsignedExit = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int]$gameProcess.ExitCode), 0)
    $hexExit = '0x{0:X8}' -f $unsignedExit
    throw "Godot exited with code $($gameProcess.ExitCode) ($hexExit). Graphics: $GraphicsBackend. Diagnostic log: $gameLog"
}
