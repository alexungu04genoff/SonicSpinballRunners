[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [Parameter(Mandatory = $true)][string]$WindowsTemplate
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$build = Join-Path $repo "test-results\authoring-tools\source-$stamp"
$output = Join-Path $repo "test-results\authoring-tools\Sonic Spinball Authoring Tools-$stamp"
$template = (Resolve-Path -LiteralPath $WindowsTemplate).Path.Replace('\', '/')
New-Item -ItemType Directory -Path $build, $output | Out-Null
foreach ($folder in @('assets', 'data', 'scenes', 'scripts', 'experiments', 'tests', 'third_party')) {
    & robocopy (Join-Path $repo $folder) (Join-Path $build $folder) /E /XD '*.bake' /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not snapshot $folder" }
}
$project = Get-Content -LiteralPath (Join-Path $repo 'project.godot') -Raw
$project = $project -replace 'run/main_scene="[^"]+"', 'run/main_scene="res://scenes/portable_editor.tscn"'
$project = $project -replace 'config/name="[^"]+"', 'config/name="Sonic Spinball Authoring Tools"'
$project += "`n[editor]`nexport/convert_text_resources_to_binary=false`n"
$project += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/prototype_export/plugin.cfg`")`n"
$project += "`n[portable_tools]`nenabled=true`ndefault_tool=`"geometry`"`n"
[IO.File]::WriteAllText((Join-Path $build 'project.godot'), $project)
New-Item -ItemType Directory -Path (Join-Path $build 'addons') | Out-Null
# Preserve raw PNGs used by current local material loaders as well as imported textures.
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'prototype_export') -Destination (Join-Path $build 'addons\prototype_export') -Recurse
[IO.File]::WriteAllText((Join-Path $build 'export_presets.cfg'), @"
[preset.0]
name="AuthoringTools"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="assets/**/*.png,data/**/*.scenery.cfg,data/atmospheres/*.cfg"
exclude_filter="addons/prototype_export/*,*.bake/*"
script_export_mode=0

[preset.0.options]
custom_template/release="$template"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
codesign/enable=false
application/modify_resources=false
"@)
$profile = Join-Path $build '.import-profile'
New-Item -ItemType Directory -Force -Path (Join-Path $profile 'Godot') | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'Godot\editor_settings-4.7.tres'), @'
[gd_resource type="EditorSettings" format=3]
[resource]
text_editor/behavior/files/convert_indent_on_save = false
text_editor/behavior/files/restore_scripts_on_load = false
'@)
function Invoke-BuildStep([string]$Name, [string[]]$Arguments) {
    $errors = Join-Path $build "$Name-errors.log"
    $process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $build "$Name.log") -RedirectStandardError $errors
    if ($process.ExitCode -ne 0) { throw "$Name failed: $errors" }
    $problems = Get-Content -LiteralPath $errors | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' }
    if ($problems) { throw "$Name reported errors: $errors" }
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $profile
    $env:LOCALAPPDATA = $profile
    $common = @('--headless', '--path', ('"{0}"' -f $build))
    Invoke-BuildStep 'import' ($common + @('--import'))
    Invoke-BuildStep 'geometry-export' ($common + @('--export-release', 'AuthoringTools', ('"{0}"' -f (Join-Path $output 'Geometry Editor.exe'))))
    [IO.File]::WriteAllText((Join-Path $build 'project.godot'), $project.Replace('default_tool="geometry"', 'default_tool="atmosphere"'))
    Invoke-BuildStep 'atmosphere-export' ($common + @('--export-release', 'AuthoringTools', ('"{0}"' -f (Join-Path $output 'Atmosphere Lab.exe'))))
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
Copy-Item -LiteralPath (Join-Path $repo 'docs\PORTABLE_AUTHORING_TOOLS.md') -Destination (Join-Path $output 'Read me.md')
foreach ($policy in @('legacy', 'conservative')) {
    $launcher = "@echo off`r`n`"%~dp0Geometry Editor.exe`" -- --portable-play --no-bakes --seed=18 --atmosphere=green_hill:default --foreground-contribution=$policy %*`r`n"
    [IO.File]::WriteAllText((Join-Path $output "Compare Prototype $policy.cmd"), $launcher)
}
$pixelLauncher = "@echo off`r`n`"%~dp0Geometry Editor.exe`" -- --portable-play --no-bakes --seed=18 --atmosphere=green_hill:default --pixel-controls --world-msaa=4 --world-scale=100 %*`r`n"
[IO.File]::WriteAllText((Join-Path $output 'Compare Prototype pixels.cmd'), $pixelLauncher)
Compress-Archive -LiteralPath (Join-Path $output 'Geometry Editor.exe'), (Join-Path $output 'Atmosphere Lab.exe'), (Join-Path $output 'Read me.md'), (Join-Path $output 'Compare Prototype legacy.cmd'), (Join-Path $output 'Compare Prototype conservative.cmd'), (Join-Path $output 'Compare Prototype pixels.cmd') -DestinationPath "$output.zip"
Write-Output "Build: $output"
Write-Output "Archive: $output.zip"
Write-Output "Logs: $build"
