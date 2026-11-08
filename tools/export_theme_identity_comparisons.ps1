[CmdletBinding()]
param(
    [string]$CaptureRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'test-results\theme-identity'),
    [string]$OutputRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\theme-identity')
)
# Arrange canonical framebuffer pixels only; never render a substitute scene.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$CaptureRoot = (Resolve-Path -LiteralPath $CaptureRoot).Path
if (Test-Path -LiteralPath $OutputRoot) { throw 'Choose a new output directory; do not mix comparison runs.' }
$pairs = @()
foreach ($view in @('', '-sky-edge')) {
    $before = Get-Content -LiteralPath (Join-Path $CaptureRoot "before$view/manifest.json") -Raw | ConvertFrom-Json
    $after = Get-Content -LiteralPath (Join-Path $CaptureRoot "after$view/manifest.json") -Raw | ConvertFrom-Json
    $expected = if ($view) { @('sky_sanctuary') } else { @('green_hill', 'chemical_plant', 'rooftop_run', 'casino_night', 'sky_sanctuary', 'ice_cap', 'lava_reef', 'aquarium_park') }
    foreach ($manifest in @($before, $after)) {
        if (-not $manifest.complete -or $manifest.authority -ne 'Prototype') { throw "Incomplete/noncanonical manifest: $view" }
        if ((($manifest.captures.theme | Sort-Object) -join ',') -cne (($expected | Sort-Object) -join ',')) { throw "Unexpected theme set: $view" }
        foreach ($capture in $manifest.captures) {
            if ($null -eq $capture.graphics -or $capture.graphics.msaa_3d -ne 2 -or $capture.graphics.scale_3d -ne 1 -or $capture.graphics.fxaa -ne 0 -or $capture.graphics.smooth_shadows -or $capture.graphics.shadow_atlas -ne 8192 -or $capture.graphics.shadow_cascades -ne 4) {
                throw 'Identity evidence requires explicit, unchanged 4x/100% and default shadow receipts.'
            }
        }
    }
    foreach ($theme in $expected) {
        $a = @($before.captures | Where-Object theme -eq $theme)[0]
        $b = @($after.captures | Where-Object theme -eq $theme)[0]
        foreach ($field in @('state', 'graphics', 'atmosphere', 'act_fingerprint', 'source_sha256', 'scenery_fingerprint', 'seed', 'theme', 'surface_detail')) {
            if (($a.$field | ConvertTo-Json -Depth 30 -Compress) -cne ($b.$field | ConvertTo-Json -Depth 30 -Compress)) { throw "Unmatched $field in $theme$view" }
        }
        foreach ($field in @('api', 'device', 'driver', 'engine', 'renderer')) {
            if ($a.renderer.$field -cne $b.renderer.$field) { throw "Unmatched renderer $field in $theme$view" }
        }
        $pairs += @{ theme = $theme; view = $view; before = "before$view/$theme.png"; after = "after$view/$theme.png" }
    }
}
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$index = @()
$font = [Drawing.Font]::new('Segoe UI', 18)
try {
    foreach ($pair in $pairs) {
        $stem = $pair.theme + $pair.view
        $canvas = [Drawing.Bitmap]::new(2880, 1060)
        $graphics = [Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(12, 20, 32))
            $originals = @()
            $column = 0
            foreach ($side in @('before', 'after')) {
                $source = Join-Path $CaptureRoot $pair[$side]
                $name = "$stem-$side.png"
                Copy-Item -LiteralPath $source -Destination (Join-Path $OutputRoot $name)
                $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
                if ((Get-FileHash -LiteralPath (Join-Path $OutputRoot $name) -Algorithm SHA256).Hash -ne $hash) { throw "Copy mismatch: $name" }
                $image = [Drawing.Bitmap]::new($source)
                try {
                    if ($image.Width -ne 1440 -or $image.Height -ne 1000) { throw "Unexpected dimensions: $source" }
                    $graphics.DrawString(($stem.Replace('_', ' ') + ' / ' + $side.ToUpper() + ' / 1:1 pixels'), $font, [Drawing.Brushes]::White, $column * 1440 + 12, 12)
                    $graphics.DrawImageUnscaled($image, $column * 1440, 60)
                } finally { $image.Dispose() }
                $originals += @{ path = $name; source = $pair[$side]; sha256 = $hash }
                $column++
            }
            $canvas.Save((Join-Path $OutputRoot "$stem-pair.png"), [Drawing.Imaging.ImageFormat]::Png)
            $index += @{ pair = "$stem-pair.png"; originals = $originals; header_height = 60; pixel_scale = 1 }
        } finally { $graphics.Dispose(); $canvas.Dispose() }
    }
} finally { $font.Dispose() }
foreach ($run in @('before', 'after', 'before-sky-edge', 'after-sky-edge')) {
    foreach ($receipt in @('manifest', 'provenance')) {
        Copy-Item -LiteralPath (Join-Path $CaptureRoot "$run/$receipt.json") -Destination (Join-Path $OutputRoot "$run-$receipt.json")
    }
}
$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $OutputRoot 'index.json') -Encoding UTF8
# Native detail crops make the calibration motifs readable without enlarging pixels.
$regions = @(
    @{ stem='green_hill'; name='sunflower'; rect=[Drawing.Rectangle]::new(900,650,320,270) },
    @{ stem='green_hill'; name='loop'; rect=[Drawing.Rectangle]::new(1150,180,290,480) },
    @{ stem='rooftop_run'; name='clock'; rect=[Drawing.Rectangle]::new(1210,100,230,370) },
    @{ stem='rooftop_run'; name='roof-chimney'; rect=[Drawing.Rectangle]::new(1000,610,290,250) },
    @{ stem='sky_sanctuary'; name='leaves'; rect=[Drawing.Rectangle]::new(740,620,400,340) },
    @{ stem='sky_sanctuary-sky-edge'; name='clouds'; rect=[Drawing.Rectangle]::new(980,0,460,340) },
    @{ stem='aquarium_park'; name='fish'; rect=[Drawing.Rectangle]::new(1090,250,350,510) },
    @{ stem='aquarium_park'; name='lantern'; rect=[Drawing.Rectangle]::new(920,700,300,250) }
)
$cropDirectory = Join-Path $OutputRoot 'details'
New-Item -ItemType Directory -Path $cropDirectory | Out-Null
$font = [Drawing.Font]::new('Segoe UI', 12)
try {
    foreach ($region in $regions) {
        $rect = $region.rect
        $panel = [Drawing.Bitmap]::new($rect.Width * 2, $rect.Height + 40)
        $graphics = [Drawing.Graphics]::FromImage($panel)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(12,20,32))
            $column = 0
            foreach ($side in @('before','after')) {
                $source = [Drawing.Bitmap]::new((Join-Path $OutputRoot ($region.stem + "-$side.png")))
                try { $crop = $source.Clone($rect, $source.PixelFormat) } finally { $source.Dispose() }
                try {
                    $crop.Save((Join-Path $cropDirectory ($region.stem + '-' + $region.name + "-$side.png")), [Drawing.Imaging.ImageFormat]::Png)
                    $graphics.DrawImageUnscaled($crop, $column * $rect.Width, 40)
                    $graphics.DrawString("$side / native pixels", $font, [Drawing.Brushes]::White, $column * $rect.Width + 8, 8)
                } finally { $crop.Dispose() }
                $column++
            }
            $panel.Save((Join-Path $cropDirectory ($region.stem + '-' + $region.name + '-pair.png')), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $panel.Dispose() }
    }
} finally { $font.Dispose() }
$regions | ForEach-Object { [ordered]@{ stem=$_.stem; name=$_.name; x=$_.rect.X; y=$_.rect.Y; width=$_.rect.Width; height=$_.rect.Height; scale=1 } } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $cropDirectory 'coordinates.json') -Encoding UTF8
# An overview for navigation plus a separate eight-theme sheet at 1:1 pixel scale.
Copy-Item -LiteralPath (Join-Path $CaptureRoot 'after/eight-themes.png') -Destination (Join-Path $OutputRoot 'eight-themes-overview.png')
$sheet = [Drawing.Bitmap]::new(2880,4260)
$graphics = [Drawing.Graphics]::FromImage($sheet)
$font = [Drawing.Font]::new('Segoe UI',22)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(12,20,32))
    $graphics.DrawString('FINAL / Prototype disk bakes / 4x MSAA / 100% 3D scale / 1:1 pixels', $font, [Drawing.Brushes]::White, 16, 12)
    $themes = @('green_hill','rooftop_run','sky_sanctuary','aquarium_park','chemical_plant','casino_night','ice_cap','lava_reef')
    for ($i=0; $i -lt $themes.Count; $i++) {
        $x = ($i % 2) * 1440
        $y = 60 + [int][Math]::Floor($i / 2) * 1050
        $graphics.DrawString($themes[$i].Replace('_',' ').ToUpperInvariant(), $font, [Drawing.Brushes]::White, $x+12, $y+8)
        $source = [Drawing.Bitmap]::new((Join-Path $OutputRoot ($themes[$i]+'-after.png')))
        try { $graphics.DrawImageUnscaled($source,$x,$y+50) } finally { $source.Dispose() }
    }
    $sheet.Save((Join-Path $OutputRoot 'eight-themes-native.png'),[Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $sheet.Dispose(); $font.Dispose() }
Write-Output "Exported eight primary pairs and one supplemental pair: $OutputRoot"
