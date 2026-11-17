[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$ZipPath
)
# Build-machine packaging only. Do not include device caches, saved preferences,
# benchmark output or generated regression fixtures in the portable delivery.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$destination = [IO.Path]::GetFullPath($ZipPath)
if ($destination.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Place the ZIP outside the project folder to avoid including it in itself.' }
if (Test-Path -LiteralPath $destination) { throw 'Choose a new ZIP path; existing packages are preserved.' }
$manifestPath = Join-Path $project 'grounding-build.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$freshness = Get-Content -LiteralPath (Join-Path $project 'grounding-freshness.json') -Raw | ConvertFrom-Json
if (-not $freshness.complete -or $freshness.stale.Count -ne 0) { throw 'The seven-theme bake freshness check must pass before packaging.' }
$hashes = [ordered]@{}
foreach ($entry in $manifest.source_hashes.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath (Join-Path $project $entry.Name)) -and -not $entry.Name.StartsWith('tests/grounding_')) { throw ('Frozen source is missing: ' + $entry.Name) }
}
foreach ($folder in @('scripts','data','assets','scenes','tests')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $project $folder) -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.gdshaderinc','.tres','.tscn','.png','.res','.cfg' -and $_.FullName -notmatch '\.bake[\\/]' }) {
        $relative = $file.FullName.Substring($project.Length + 1).Replace('\','/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $recorded = $manifest.source_hashes.PSObject.Properties[$relative]
        $diagnostic = $relative.StartsWith('scripts/diagnostics/') -or $relative.StartsWith('tests/grounding_') -or $relative -in @('scripts/endless/endless_game.gd','scripts/retro/retro_filter.gd')
        if (-not $diagnostic -and ($null -eq $recorded -or $recorded.Value -ne $hash)) { throw ('Frozen production source changed: ' + $relative) }
        $hashes[$relative] = $hash
    }
}
$manifest.source_hashes = $hashes
$manifest | Add-Member -NotePropertyName finalized_at -NotePropertyValue (Get-Date).ToString('o') -Force
$manifest | Add-Member -NotePropertyName fresh_seven_theme_variants -NotePropertyValue $freshness.variants.Count -Force
$manifest | Add-Member -NotePropertyName cache_policy -NotePropertyValue 'Device/user/shader caches excluded. Graphics preferences are fresh for each diagnostic run; engine caches can warm between jobs.' -Force
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6))
$prefix = (Split-Path $project -Leaf) + '/'
$excluded = '^(diagnostic-user|build-user|user_data|Results|test-results)/|^\.godot/(editor|shader_cache)/|(^|/)\.git/|\.log$'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($destination, [IO.Compression.ZipArchiveMode]::Create)
$entries = 0
try {
    foreach ($file in Get-ChildItem -LiteralPath $project -Recurse -File -Force) {
        $relative = $file.FullName.Substring($project.Length + 1).Replace('\','/')
        if ($relative -match $excluded) { continue }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $prefix + $relative, [IO.Compression.CompressionLevel]::Fastest) | Out-Null
        $entries++
    }
} finally { $archive.Dispose() }
$digest = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
[IO.File]::WriteAllText($destination + '.sha256.txt', $digest + '  ' + (Split-Path $destination -Leaf) + [Environment]::NewLine)
@{zip=$destination;sha256=$digest;entries=$entries;bytes=(Get-Item -LiteralPath $destination).Length;base_head=$manifest.base_head;fresh_variants=$freshness.variants.Count} | ConvertTo-Json
