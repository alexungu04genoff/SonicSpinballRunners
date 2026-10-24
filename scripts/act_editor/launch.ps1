[CmdletBinding()]
param([string]$GodotPath)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:ProgramFiles 'Godot\Godot.exe'
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        $command = Get-Command godot4.exe, godot.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $GodotPath = $command.Source }
    }
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot 4 was not found. Pass -GodotPath with the full executable path.'
}
# This scene uses explicit script preloads and can open without an editor import.
# ANGLE follows the working Windows launch backend used by the physics playground.
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3_angle', 'res://scenes/act_geometry_editor.tscn')
# The visible editor is the interactive application requested by this launcher.
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Act Geometry Editor exited with code $($process.ExitCode)."
}
