[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [Parameter(Mandatory = $true)][string]$WindowsTemplate,
    [ValidatePattern('^[A-Za-z0-9 _-]+$')][string]$OutputName = 'Portable Act Editor'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo ('test-results\portable-build\snapshot-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$output = Join-Path $repo ('test-results\portable-build\' + $OutputName)
New-Item -ItemType Directory -Force $build, $output | Out-Null
foreach ($folder in @('assets', 'data', 'scenes', 'scripts', 'experiments', 'tests', 'third_party')) {
    & robocopy (Join-Path $repo $folder) (Join-Path $build $folder) /E /XD '*.bake' /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not snapshot $folder" }
}
$project = Get-Content (Join-Path $repo 'project.godot') -Raw
$project = $project -replace 'run/main_scene="[^"]+"', 'run/main_scene="res://scenes/portable_editor.tscn"'
$project = $project -replace '\[rendering\]', "[rendering]`n`ngl_compatibility/driver.windows=`"opengl3_angle`""
$project += "`n[editor]`n`nexport/convert_text_resources_to_binary=false`n"
[IO.File]::WriteAllText((Join-Path $build 'project.godot'), $project)
$template = (Resolve-Path -LiteralPath $WindowsTemplate).Path.Replace('\', '/')
$preset = @"
[preset.0]
name="Portable Act Editor"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="assets/**/*.png"
exclude_filter="tools/*,*.bake/*"
script_export_mode=0

[preset.0.options]
custom_template/release="$template"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
codesign/enable=false
application/modify_resources=false
"@
[IO.File]::WriteAllText((Join-Path $build 'export_presets.cfg'), $preset)
# Isolated settings prevent editor startup from rewriting indentation in source files.
$profile = Join-Path $build '.import-profile'
New-Item -ItemType Directory -Force (Join-Path $profile 'Godot') | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'Godot\editor_settings-4.7.tres'), @'
[gd_resource type="EditorSettings" format=3]
[resource]
text_editor/behavior/files/convert_indent_on_save = false
text_editor/behavior/files/restore_scripts_on_load = false
'@)
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $profile
    $process = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"{0}"' -f $build), '--import') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $build 'import.log') -RedirectStandardError (Join-Path $build 'import-errors.log')
    if ($process.ExitCode -ne 0) { throw "Import failed: $build\import-errors.log" }
    if (Select-String -Path (Join-Path $build 'import-errors.log') -Pattern '^(SCRIPT ERROR|ERROR):' -Quiet) { throw "Import reported errors: $build\import-errors.log" }
    $process = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"{0}"' -f $build), '--export-release', '"Portable Act Editor"', ('"{0}"' -f (Join-Path $output 'Act Editor.exe'))) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $build 'export.log') -RedirectStandardError (Join-Path $build 'export-errors.log')
    if ($process.ExitCode -ne 0) { throw "Export failed: $build\export-errors.log" }
    if (Select-String -Path (Join-Path $build 'export-errors.log') -Pattern '^(SCRIPT ERROR|ERROR):' -Quiet) { throw "Export reported errors: $build\export-errors.log" }
} finally { $env:APPDATA = $previousAppData }
New-Item -ItemType Directory -Force (Join-Path $output 'Acts') | Out-Null
foreach ($act in Get-ChildItem (Join-Path $build 'data\acts') -Filter '*.tres' -Recurse) {
    $relative = $act.FullName.Substring((Join-Path $build 'data\acts').Length + 1)
    $destination = Join-Path (Join-Path $output 'Acts') $relative
    New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $act.FullName -Destination $destination
}
$archive = Join-Path (Split-Path $output -Parent) ($OutputName + '.zip')
Compress-Archive -Path (Join-Path $output 'Act Editor.exe'), (Join-Path $output 'Acts') -DestinationPath $archive -Force
Write-Output "Build: $output"
Write-Output "Archive: $archive"
Write-Output "Logs: $build"
