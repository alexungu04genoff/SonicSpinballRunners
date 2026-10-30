[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [Parameter(Mandatory = $true)][string]$WindowsTemplate
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$build = Join-Path $repo "test-results\prototype-build\source-$stamp"
$output = Join-Path $repo "test-results\prototype-build\Sonic Spinball Runners-$stamp"
New-Item -ItemType Directory $build, $output | Out-Null
foreach ($folder in @('assets', 'data', 'scenes', 'scripts', 'experiments', 'tests', 'third_party')) {
    & robocopy (Join-Path $repo $folder) (Join-Path $build $folder) /E /XD '*.bake' /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not snapshot $folder" }
}
$project = Get-Content (Join-Path $repo 'project.godot') -Raw
$project = $project -replace 'run/main_scene="[^"]+"', 'run/main_scene="res://scenes/prototype_run.tscn"'
$project = $project -replace '\[rendering\]', "[rendering]`n`ngl_compatibility/driver.windows=`"opengl3_angle`""
$project += "`n[editor]`n`nexport/convert_text_resources_to_binary=false`n"
$project += "`n[editor_plugins]`n`nenabled=PackedStringArray(`"res://addons/prototype_export/plugin.cfg`")`n"
New-Item -ItemType Directory -Force (Join-Path $build 'addons') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'prototype_export') -Destination (Join-Path $build 'addons\prototype_export') -Recurse
[IO.File]::WriteAllText((Join-Path $build 'project.godot'), $project)
$template = (Resolve-Path -LiteralPath $WindowsTemplate).Path.Replace('\', '/')
[IO.File]::WriteAllText((Join-Path $build 'export_presets.cfg'), @"
[preset.0]
name="Prototype"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="assets/**/*.png,scripts/**/*.gd,scripts/**/*.gdshader,scripts/**/*.gdshaderinc"
exclude_filter="addons/prototype_export/*"
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
New-Item -ItemType Directory -Force (Join-Path $profile 'Godot') | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'Godot\editor_settings-4.7.tres'), @'
[gd_resource type="EditorSettings" format=3]
[resource]
text_editor/behavior/files/convert_indent_on_save = false
text_editor/behavior/files/restore_scripts_on_load = false
'@)
function Invoke-BuildStep([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $build "$Name.log"
    $errors = Join-Path $build "$Name-errors.log"
    $process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
    if ($process.ExitCode -ne 0) { throw "$Name failed: $errors" }
    $problems = Get-Content $errors | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' }
    if ($problems) { throw "$Name reported errors: $errors" }
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $profile
    $env:LOCALAPPDATA = $profile
    $common = @('--headless', '--path', ('"{0}"' -f $build))
    Invoke-BuildStep 'import' ($common + @('--import'))
    # Bake the snapshot itself so artwork and pipeline fingerprints cannot race edits in the checkout.
    $bake = $common + @('res://scenes/act_baker.tscn', '--', '--prototype')
    Invoke-BuildStep 'bake' $bake
    Invoke-BuildStep 'import-bakes' ($common + @('--import'))
    Invoke-BuildStep 'export' ($common + @('--export-release', 'Prototype', ('"{0}"' -f (Join-Path $output 'Sonic Spinball Runners.exe'))))
    Invoke-BuildStep 'verify-package' @('--headless', '--main-pack', ('"{0}"' -f (Join-Path $output 'Sonic Spinball Runners.exe')), '--script', 'res://tests/prototype_package_regression.gd')
} finally { $env:APPDATA = $previousAppData; $env:LOCALAPPDATA = $previousLocalAppData }
Copy-Item -LiteralPath (Join-Path $repo 'docs\PLAYABLE_PROTOTYPE.md') -Destination (Join-Path $output 'Read me.md')
$archive = "$output.zip"
Compress-Archive -LiteralPath (Join-Path $output 'Sonic Spinball Runners.exe'), (Join-Path $output 'Read me.md') -DestinationPath $archive
Write-Output "Build: $output"
Write-Output "Archive: $archive"
Write-Output "Logs: $build"
