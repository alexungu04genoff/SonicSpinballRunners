[CmdletBinding()]
param([string]$GodotPath = 'C:\Program Files\Godot\Godot.exe', [switch]$Bake, [string]$Atmosphere = '', [string]$ActPath = '', [string]$Theme = 'green_hill')
$ErrorActionPreference = 'Stop'
if ($Atmosphere -and $Atmosphere -notmatch '^[a-z_][a-z0-9_]*:[a-z_][a-z0-9_]*$') { throw 'Atmosphere must be theme_id:variant_id.' }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Godot 4 was not found. Pass -GodotPath with its executable path.' }
$acts = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'data\acts\Authored') -Filter '*.tres' -File)
$registry = Get-Content -LiteralPath (Join-Path $projectRoot 'scripts\themes\theme_registry.gd') -Raw
$ids = [regex]::Match($registry, '(?m)^const IDS := \[(.+)\]').Groups[1].Value
$themes = @([regex]::Matches($ids, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if (-not $themes.Count) { throw 'No production themes found in the theme registry.' }
if ($ActPath) {
    if ($Bake) { throw 'Use the editor Bake action for an individual Act. Act testing builds its own preview.' }
    if ($Atmosphere) { $Theme = $Atmosphere.Split(':')[0] }
    if ($Theme -notin $themes) { throw "Unknown theme: $Theme" }
    if ($ActPath.StartsWith('res://')) { $ActPath = Join-Path $projectRoot $ActPath.Substring(6) }
    elseif (-not [IO.Path]::IsPathRooted($ActPath)) { $ActPath = Join-Path $projectRoot $ActPath }
    $ActPath = (Resolve-Path -LiteralPath $ActPath).Path
    $arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', 'res://scenes/prototype_run.tscn', '--', '--act', ('"{0}"' -f $ActPath), "--theme=$Theme")
    if ($Atmosphere) { $arguments += "--atmosphere=$Atmosphere" }
    # This launcher was explicitly invoked to open an interactive playtest.
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Act test exited with code $($process.ExitCode)." }
    return
}
if ($acts.Count -lt 3) { throw 'The prototype requires at least three Acts in data\acts\Authored.' }
$missing = @(foreach ($act in $acts) {
    foreach ($theme in $themes) {
        $baked = Join-Path $act.DirectoryName ($act.BaseName + ".bake\$theme.res")
        if (-not (Test-Path -LiteralPath $baked) -or (Get-Item -LiteralPath $baked).LastWriteTimeUtc -lt $act.LastWriteTimeUtc) { $baked }
    }
})
$missing += @(foreach ($theme in $themes) {
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
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', 'res://scenes/prototype_run.tscn')
if ($Atmosphere) { $arguments += @('--', "--atmosphere=$Atmosphere") }
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Prototype exited with code $($process.ExitCode)." }
