[CmdletBinding()]
param([string]$GodotPath = 'C:\Program Files\Godot\Godot.exe', [switch]$Bake)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Godot 4 was not found. Pass -GodotPath with its executable path.' }
$acts = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'data\acts\Authored') -Filter '*.tres' -File)
if ($acts.Count -lt 3) { throw 'The two-Zone prototype requires at least three Acts in data\acts\Authored.' }
$missing = @(foreach ($act in $acts) {
    foreach ($theme in @('green_hill', 'chemical_plant')) {
        $baked = Join-Path $act.DirectoryName ($act.BaseName + ".bake\$theme.res")
        if (-not (Test-Path -LiteralPath $baked) -or (Get-Item -LiteralPath $baked).LastWriteTimeUtc -lt $act.LastWriteTimeUtc) { $baked }
    }
})
$missing += @(foreach ($theme in @('green_hill', 'chemical_plant')) {
    $baked = Join-Path $projectRoot "data\endless\themes.bake\$theme.res"
    if (-not (Test-Path -LiteralPath $baked)) { $baked }
})
if ($Bake -or $missing) {
    $arguments = @('--headless', '--path', ('"{0}"' -f $projectRoot), 'res://scenes/act_baker.tscn', '--', '--prototype')
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'Prototype baking failed. See the Godot log.' }
}
if ($Bake) { return }
# The player explicitly requested an interactive game window.
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', 'res://scenes/prototype_run.tscn')
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Prototype exited with code $($process.ExitCode)." }
