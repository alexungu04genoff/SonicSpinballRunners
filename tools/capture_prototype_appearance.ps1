[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string]$ActPath = 'res://data/acts/Authored/First Try Smooth Decor.tres',
    [string]$OutputDirectory = '',
    [switch]$SkipBake
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot ('test-results\prototype-appearance\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new output directory so old captures cannot be mistaken for this run.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
if ($ActPath.StartsWith('res://')) { $ActPath = Join-Path $projectRoot $ActPath.Substring(6) }
elseif (-not [IO.Path]::IsPathRooted($ActPath)) { $ActPath = Join-Path $projectRoot $ActPath }
$ActPath = (Resolve-Path -LiteralPath $ActPath).Path

function Source-Hashes {
    $hashes = [ordered]@{}
    foreach ($directory in @('data\acts', 'data\atmospheres')) {
        Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -Recurse -File |
            Where-Object { $_.Extension -in '.tres', '.cfg' -and $_.FullName -notmatch '\.bake[\\/]' } |
            Sort-Object FullName | ForEach-Object { $hashes[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    $hashes[$ActPath] = (Get-FileHash -LiteralPath $ActPath -Algorithm SHA256).Hash
    return $hashes
}

function Invoke-Godot([string]$Name, [string[]]$Arguments) {
    $stdout = Join-Path $output ($Name + '.log')
    $stderr = Join-Path $output ($Name + '.err')
    $process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(1200000)) {
        $process.Kill()
        throw "$Name exceeded 20 minutes. See $stdout"
    }
    $process.Refresh()
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $stdout, $stderr -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet)) {
        throw "$Name failed. See $stdout and $stderr"
    }
}

$before = Source-Hashes
$before | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'sources-before.json') -Encoding UTF8
$head = (& git -C $projectRoot rev-parse HEAD) -join "`n"
$worktree = @(& git -C $projectRoot status --short)
@{ head = $head; worktree = $worktree; scope = 'Current working tree, including uncommitted art'; act = $ActPath } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'provenance.json') -Encoding UTF8
$common = @('--path', ('"{0}"' -f $projectRoot))
if (-not $SkipBake) {
    # Supported single-Act baker builds all registry themes and shared backgrounds.
    Invoke-Godot 'bake' ($common + @('--headless', 'res://scenes/act_baker.tscn', '--', ('"--act={0}"' -f $ActPath)))
}
Invoke-Godot 'capture' ($common + @('--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--script', 'res://tests/prototype_appearance_capture.gd', '--', '--seed=18', ('"--act={0}"' -f $ActPath), ('"--output={0}"' -f $output)))
$after = Source-Hashes
$after | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'sources-after.json') -Encoding UTF8
if (($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) { throw 'Authored source or atmosphere changed during verification. Review before trusting the images.' }
$manifest = Get-Content -LiteralPath (Join-Path $output 'manifest.json') -Raw | ConvertFrom-Json
if (-not $manifest.complete -or $manifest.captures.Count -ne 8) { throw 'Incomplete production comparison.' }
# Recheck every receipt at the end so concurrent source edits fail the whole set.
Invoke-Godot 'regression' ($common + @('--headless', '--script', 'res://tests/prototype_appearance_regression.gd', '--', ('"--act={0}"' -f $ActPath), ('"--verify-manifest={0}"' -f (Join-Path $output 'manifest.json'))))
if (($before | ConvertTo-Json -Compress) -ne ((Source-Hashes) | ConvertTo-Json -Compress)) { throw 'Source changed during the final receipt check.' }

Add-Type -AssemblyName System.Drawing
$sheet = New-Object System.Drawing.Bitmap(1440, 2224)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(12, 20, 32))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font('Segoe UI', 18)
$small = New-Object System.Drawing.Font('Segoe UI', 11)
$graphics.DrawString('PROTOTYPE / Eight production themes / Forward+ Vulkan', $font, [System.Drawing.Brushes]::White, 16, 8)
$graphics.DrawString('Same Act, served Ball and camera. Current working-tree art; validated disk bakes. See manifest.json.', $small, [System.Drawing.Brushes]::LightGray, 16, 40)
for ($i = 0; $i -lt $manifest.captures.Count; $i++) {
    $capture = $manifest.captures[$i]
    $x = ($i % 2) * 720
    $y = 72 + [math]::Floor($i / 2) * 538
    $graphics.DrawString(($capture.theme -replace '_', ' ').ToUpperInvariant(), $font, [System.Drawing.Brushes]::White, $x + 12, $y)
    $image = [System.Drawing.Image]::FromFile((Join-Path $output $capture.image))
    try { $graphics.DrawImage($image, [int]$x, [int]($y + 34), 720, 500) } finally { $image.Dispose() }
}
try { $sheet.Save((Join-Path $output 'eight-themes.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
finally { $graphics.Dispose(); $sheet.Dispose(); $font.Dispose(); $small.Dispose() }
Write-Output "Verified Prototype comparison: $output"
