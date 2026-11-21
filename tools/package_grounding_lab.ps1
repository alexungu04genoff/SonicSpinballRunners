[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$BaseRevision = 'HEAD',
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
$base = (& git -C $repo rev-parse $BaseRevision).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the requested source revision.' }
$owned = @('scripts/endless/endless_game.gd','scripts/retro/retro_filter.gd')
function Is-Owned([string]$Path) {
    return $Path.StartsWith('scripts/diagnostics/') -or $Path.StartsWith('tests/grounding_') -or
        $Path -match '^tools/(run|package|prepare|verify|summarize|finalize)_grounding' -or $Path -in $owned
}
$foreign = @(& git -C $repo diff --name-only HEAD) | Where-Object { -not (Is-Owned $_) }
$untracked = @(& git -C $repo ls-files --others --exclude-standard) |
    Where-Object { $_ -match '\.(gd|gdshader|gdshaderinc|tscn|tres|ps1|cmd)$' -and -not (Is-Owned $_) }
& (Join-Path $PSScriptRoot 'package_work_suite.ps1') -SnapshotPath $repo -OutputDirectory $output -GodotPath $GodotPath
# Other chats keep editing the shared tree. Restore only the private package
# copies to the recorded committed base; never touch their source files.
$archive = Join-Path (Split-Path $output -Parent) ((Split-Path $output -Leaf) + '-source.zip')
$experimentPaths = @(& git -C $repo ls-tree -r --name-only $base -- experiments) | Where-Object { $_ -match '\.(gd|gdshader|gdshaderinc|tres|tscn|cfg)$' }
& git -C $repo archive --format=zip ('--output=' + $archive) $base -- project.godot assets data scenes scripts tests third_party @experimentPaths
if ($LASTEXITCODE -ne 0) { throw 'Could not freeze the committed source snapshot' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($archive, $output, $true)
$configuration = [IO.File]::ReadAllText((Join-Path $output 'project.godot')) -replace 'config/name="[^"]+"', 'config/name="Sonic Spinball Work Suite"'
[IO.File]::WriteAllText((Join-Path $output 'project.godot'), $configuration)
foreach ($relative in $owned) { Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination (Join-Path $output $relative) }
foreach ($relative in $untracked) {
    $target = [IO.Path]::GetFullPath((Join-Path $output $relative))
    if (-not $target.StartsWith($output + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe package path' }
    if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target }
}
# A second pass catches new source files created by another chat while copying.
$committed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relative in (& git -C $repo ls-tree -r --name-only $base)) { $committed.Add($relative) | Out-Null }
foreach ($folder in @('scripts','data','scenes','tests','experiments','third_party')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $output $folder) -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.gdshaderinc','.tscn','.tres','.cfg' -and $_.FullName -notmatch '\.bake[\\/]' }) {
        $relative = $file.FullName.Substring($output.Length + 1).Replace('\','/')
        if (-not $committed.Contains($relative) -and -not (Is-Owned $relative)) { Remove-Item -LiteralPath $file.FullName }
    }
}
New-Item -ItemType Directory -Path (Join-Path $output 'tools') -Force | Out-Null
foreach ($name in @('run_grounding_probe.ps1','run_grounding_matrix.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $output ('tools\' + $name))
}
$matrix = '@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_grounding_matrix.ps1"' + "`r`n" + 'pause' + "`r`n"
$lab = '@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_grounding_matrix.ps1" -Lab' + "`r`n" + 'if errorlevel 1 pause' + "`r`n"
[IO.File]::WriteAllText((Join-Path $output 'Run Work Laptop Matrix.cmd'), $matrix)
[IO.File]::WriteAllText((Join-Path $output 'Visual Grounding Lab.cmd'), $lab)
Copy-Item -LiteralPath (Join-Path $repo 'docs\THURSDAY_LAPTOP_TEST.md') -Destination (Join-Path $output 'README - Thursday Laptop Test.md')
$hashes = [ordered]@{}
foreach ($folder in @('scripts','data','assets','scenes','tests')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $output $folder) -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.gdshaderinc','.tres','.tscn','.png','.res','.cfg' -and $_.FullName -notmatch '\.bake[\\/]' }) {
        $relative = $file.FullName.Substring($output.Length + 1).Replace('\','/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}
$manifest = @{base_head=$base;starting_head='6f9f5c59db237002c37dcd482a964136f2bbe023';excluded_concurrent_changes=$foreign;
    excluded_untracked_sources=$untracked;source_hashes=$hashes;engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash;
    diagnostic_themes=@('green_hill','rooftop_run','casino_night','ice_cap','aquarium_park');
    defaults='Unchanged production defaults. Grounding code loads only through the explicit lab script.'}
[IO.File]::WriteAllText((Join-Path $output 'grounding-build.json'), ($manifest | ConvertTo-Json -Depth 6))
Write-Output "GROUNDING_PACKAGE_PREPARED | $output"
Write-Output 'Validate freshness and both launchers before zipping this directory.'
