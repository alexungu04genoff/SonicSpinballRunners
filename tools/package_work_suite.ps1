[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SnapshotPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$snapshot = (Resolve-Path -LiteralPath $SnapshotPath).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new output directory; existing work must not be overwritten.' }
New-Item -ItemType Directory -Path $output | Out-Null
foreach ($folder in @('assets', 'data', 'scenes', 'scripts', 'third_party', 'tests')) {
    & robocopy (Join-Path $snapshot $folder) (Join-Path $output $folder) /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not copy $folder" }
}
# Keep experiment code used by the Labs, without screenshot and texture-review evidence.
& robocopy (Join-Path $snapshot 'experiments') (Join-Path $output 'experiments') '*.gd' '*.uid' '*.tscn' '*.tres' '*.cfg' '*.gdshader' '*.gdshaderinc' /S /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Could not copy Lab source' }
New-Item -ItemType Directory -Path (Join-Path $output '.godot\imported') -Force | Out-Null
foreach ($name in @('.gdignore', 'global_script_class_cache.cfg', 'uid_cache.bin')) {
    Copy-Item -LiteralPath (Join-Path $snapshot ".godot\$name") -Destination (Join-Path $output ".godot\$name")
}
$imports = [Collections.Generic.HashSet[string]]::new()
foreach ($folder in @('assets', 'data', 'third_party')) {
    foreach ($descriptor in Get-ChildItem -LiteralPath (Join-Path $output $folder) -Recurse -Filter '*.import') {
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($descriptor.FullName), 'res://\.godot/imported/[^"\s]+')) {
            $relative = $match.Value.Substring(6)
            $imports.Add($relative) | Out-Null
            $checksum = [IO.Path]::ChangeExtension($relative, '.md5')
            if (Test-Path -LiteralPath (Join-Path $snapshot $checksum)) { $imports.Add($checksum) | Out-Null }
        }
    }
}
foreach ($relative in $imports) {
    Copy-Item -LiteralPath (Join-Path $snapshot $relative) -Destination (Join-Path $output $relative)
}
$project = [IO.File]::ReadAllText((Join-Path $repo 'project.godot'))
$project = $project -replace 'config/name="[^"]+"', 'config/name="Sonic Spinball Work Suite"'
[IO.File]::WriteAllText((Join-Path $output 'project.godot'), $project)
Copy-Item -LiteralPath $GodotPath -Destination (Join-Path $output 'Sonic Spinball Runners.exe')
$licenseArguments = @('--headless', '--path', ('"{0}"' -f $output), '--script', ('"{0}"' -f (Join-Path $PSScriptRoot 'write_engine_licenses.gd')), '--', ('"{0}"' -f (Join-Path $output 'GODOT LICENSES.txt')))
$licenseProcess = Start-Process -FilePath $GodotPath -ArgumentList $licenseArguments -WindowStyle Hidden -Wait -PassThru
if ($licenseProcess.ExitCode -ne 0) { throw 'Could not write engine license notices' }
# Godot's self-contained mode keeps editor configuration with this portable workspace.
[IO.File]::WriteAllText((Join-Path $output '_sc_'), '')
$routes = [ordered]@{
    'Play Prototype' = 'res://scenes/prototype_run.tscn'
    'Play Endless' = 'res://scenes/endless_runner.tscn'
    'Act Geometry Editor' = 'res://scenes/act_geometry_editor.tscn'
    'Atmosphere Lab' = 'res://experiments/lighting_lab/lighting_lab.tscn'
    'Visual Lab' = 'res://experiments/visual_lab/visual_lab.tscn'
    'Bake Prototype' = 'res://scenes/act_baker.tscn -- --prototype --quit-after-bake'
    'Bake Endless' = 'res://scenes/act_baker.tscn -- --pool --quit-after-bake'
    'Bake Saved Act' = 'res://scenes/act_baker.tscn'
}
foreach ($name in $routes.Keys) {
    $command = "@echo off`r`ncd /d `"%~dp0`"`r`n`"%~dp0Sonic Spinball Runners.exe`" --path `"%~dp0.`" $($routes[$name]) %*`r`nif errorlevel 1 pause`r`n"
    [IO.File]::WriteAllText((Join-Path $output "$name.cmd"), $command)
}
Copy-Item -LiteralPath (Join-Path $repo 'docs\WORK_SUITE.md') -Destination (Join-Path $output 'START HERE.md')
@{source_head=(& git -C $repo rev-parse HEAD);snapshot=$snapshot;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;imported_files=$imports.Count;retro='Unchanged production settings';note='Writable project plus bundled engine; no Godot installation required.'} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'build-info.json') -Encoding utf8NoBOM
Write-Output "Portable workspace: $output"
Write-Output 'Run both bake audits and launch checks before creating the final ZIP.'
