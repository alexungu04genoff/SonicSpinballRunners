[CmdletBinding()]
param([string]$GodotPath = 'C:\Program Files\Godot\Godot.exe', [switch]$Bake)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Godot 4 was not found. Pass -GodotPath with its executable path.' }
$acts = @('classic_pinball', 'switch_spinner', 'speedway_lane')
$missing = $acts | Where-Object { -not (Test-Path (Join-Path $projectRoot "data\prototype\$_.bake\green_hill.res")) }
if ($Bake -or $missing) {
    $arguments = @('--headless', '--path', ('"{0}"' -f $projectRoot), 'res://scenes/act_baker.tscn', '--', '--theme=green_hill')
    foreach ($act in $acts) { $arguments += "--act=res://data/prototype/$act.tres" }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'Prototype baking failed. See the Godot log.' }
}
if ($Bake) { return }
# The player explicitly requested an interactive game window.
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', 'res://scenes/prototype_run.tscn')
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Prototype exited with code $($process.ExitCode)." }
