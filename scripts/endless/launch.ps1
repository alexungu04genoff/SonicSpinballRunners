[CmdletBinding()]
param(
    [string]$GodotPath,
    [int]$Seed = 18,
    [switch]$Tour,
    [switch]$Bake,
    [switch]$FrameTiming
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Godot\Godot.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
    )
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot 4 was not found. Pass -GodotPath with its executable path.'
}
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3_angle', 'res://scenes/endless_runner.tscn', '--', "--seed=$Seed")
if ($Bake) {
    $arguments = @('--path', ('"{0}"' -f $projectRoot), 'res://scenes/act_baker.tscn', '--', '--pool')
}
if ($Tour) { $arguments += '--tour' }
if ($FrameTiming) { $arguments += '--frame-timing' }
# This launcher explicitly opens the interactive game requested by the player.
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Endless mode exited with code $($process.ExitCode)." }
