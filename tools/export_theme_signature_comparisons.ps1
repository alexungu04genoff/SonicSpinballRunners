[CmdletBinding()]
param(
    [string]$CaptureRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'test-results\theme-signature'),
    [string]$OutputRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\theme-identity\signature-20261108')
)
# Compose canonical framebuffer evidence. Diagnostics never change production art.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$CaptureRoot = (Resolve-Path -LiteralPath $CaptureRoot).Path
if (Test-Path -LiteralPath $OutputRoot) { throw 'Choose a new output directory; do not mix reviews.' }
$themes = @('green_hill','chemical_plant','rooftop_run','casino_night','sky_sanctuary','ice_cap','lava_reef','aquarium_park')
$views = @(
    @{ name='spawn'; before='before-validated'; after='after'; themes=$themes },
    @{ name='edge'; before='before-edge'; after='after-edge'; themes=$themes },
    @{ name='hero'; before='before-hero'; after='after-hero'; themes=@('chemical_plant','ice_cap','lava_reef') }
)
$pairs = @()
foreach ($view in $views) {
    $manifests = @{}
    foreach ($side in @('before','after')) {
        $manifest = Get-Content -LiteralPath (Join-Path $CaptureRoot ($view[$side] + '/manifest.json')) -Raw | ConvertFrom-Json
        if (-not $manifest.complete -or $manifest.authority -ne 'Prototype') { throw 'Incomplete or noncanonical capture.' }
        if ((($manifest.captures.theme | Sort-Object) -join ',') -cne (($view.themes | Sort-Object) -join ',')) { throw 'Unexpected theme set.' }
        foreach ($capture in $manifest.captures) {
            if ($capture.fallback_builds -ne 0 -or $capture.disk_acts -ne 1 -or $capture.disk_themes -ne 1) { throw 'Evidence must come from production disk bakes.' }
            $g = $capture.graphics
            if ($null -eq $g -or $g.msaa_3d -ne 2 -or $g.scale_3d -ne 1 -or $g.fxaa -ne 0 -or $g.smooth_shadows -or $g.shadow_atlas -ne 8192 -or $g.shadow_cascades -ne 4) { throw 'Unexpected production graphics settings.' }
        }
        $manifests[$side] = $manifest
    }
    foreach ($theme in $view.themes) {
        $a = @($manifests.before.captures | Where-Object theme -eq $theme)[0]
        $b = @($manifests.after.captures | Where-Object theme -eq $theme)[0]
        foreach ($field in @('state','graphics','atmosphere','act_fingerprint','source_sha256','scenery_fingerprint','seed','theme','surface_detail')) {
            if (($a.$field | ConvertTo-Json -Depth 40 -Compress) -cne ($b.$field | ConvertTo-Json -Depth 40 -Compress)) { throw "Unmatched $field in $theme / $($view.name)" }
        }
        # Resource-bank paths and traversal order are storage details; the selected
        # source image and decoded runtime pixels must still match exactly.
        $aTextures=@($a.current_texture_matches | Select-Object source,source_sha256,rgba8_sha256 | Sort-Object source)
        $bTextures=@($b.current_texture_matches | Select-Object source,source_sha256,rgba8_sha256 | Sort-Object source)
        if (($aTextures | ConvertTo-Json -Compress) -cne ($bTextures | ConvertTo-Json -Compress)) { throw "Unmatched selected pixels in $theme / $($view.name)" }
        foreach ($field in @('api','device','driver','engine','renderer')) {
            if ($a.renderer.$field -cne $b.renderer.$field) { throw "Unmatched renderer: $field" }
        }
        $pairs += @{ stem=($theme + '-' + $view.name); theme=$theme; view=$view.name; before=($view.before + '/' + $a.image); after=($view.after + '/' + $b.image) }
    }
}
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$background = [Drawing.Color]::FromArgb(12,20,32)
$font = [Drawing.Font]::new('Segoe UI',18)
$index = @()
try {
    foreach ($pair in $pairs) {
        $panel = [Drawing.Bitmap]::new(2880,1060)
        $g = [Drawing.Graphics]::FromImage($panel)
        try {
            $g.Clear($background)
            $originals = @()
            $column = 0
            foreach ($side in @('before','after')) {
                $source = Join-Path $CaptureRoot $pair[$side]
                $name = $pair.stem + '-' + $side + '.png'
                Copy-Item -LiteralPath $source -Destination (Join-Path $OutputRoot $name)
                $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
                if ((Get-FileHash -LiteralPath (Join-Path $OutputRoot $name) -Algorithm SHA256).Hash -ne $hash) { throw 'Original copy mismatch.' }
                $im = [Drawing.Bitmap]::new($source)
                try {
                    if ($im.Width -ne 1440 -or $im.Height -ne 1000) { throw 'Expected native 1440 x 1000 frames.' }
                    $g.DrawImageUnscaled($im,$column * 1440,60)
                    $g.DrawString(($pair.stem.Replace('_',' ') + ' / ' + $side.ToUpper() + ' / native pixels'),$font,[Drawing.Brushes]::White,$column * 1440 + 12,12)
                } finally { $im.Dispose() }
                $originals += @{ path=$name; source=$pair[$side]; sha256=$hash }
                $column++
            }
            $panel.Save((Join-Path $OutputRoot ($pair.stem + '-pair.png')),[Drawing.Imaging.ImageFormat]::Png)
            $index += @{ pair=($pair.stem + '-pair.png'); originals=$originals; header_height=60; pixel_scale=1 }
        } finally { $g.Dispose(); $panel.Dispose() }
    }
    foreach ($view in $views) {
        foreach ($side in @('before','after')) {
            foreach ($receipt in @('manifest','provenance')) {
                Copy-Item -LiteralPath (Join-Path $CaptureRoot ($view[$side] + '/' + $receipt + '.json')) -Destination (Join-Path $OutputRoot ($view.name + '-' + $side + '-' + $receipt + '.json'))
            }
        }
        if ($view.name -eq 'hero') { continue }
        Copy-Item -LiteralPath (Join-Path $CaptureRoot ($view.after + '/eight-themes.png')) -Destination (Join-Path $OutputRoot ('eight-themes-' + $view.name + '-overview.png'))
        $native = [Drawing.Bitmap]::new(2880,4260)
        $g = [Drawing.Graphics]::FromImage($native)
        try {
            $g.Clear($background)
            $g.DrawString(('FINAL / ' + $view.name + ' / Prototype disk bakes / 4x MSAA / 100% / native pixels'),$font,[Drawing.Brushes]::White,12,12)
            for ($i=0; $i -lt $themes.Count; $i++) {
                $x = ($i % 2) * 1440
                $y = 60 + [int][Math]::Floor($i / 2) * 1050
                $g.DrawString($themes[$i].Replace('_',' ').ToUpperInvariant(),$font,[Drawing.Brushes]::White,$x+12,$y+8)
                $im = [Drawing.Bitmap]::new((Join-Path $OutputRoot ($themes[$i] + '-' + $view.name + '-after.png')))
                try { $g.DrawImageUnscaled($im,$x,$y+50) } finally { $im.Dispose() }
            }
            $native.Save((Join-Path $OutputRoot ('eight-themes-' + $view.name + '-native.png')),[Drawing.Imaging.ImageFormat]::Png)
        } finally { $g.Dispose(); $native.Dispose() }
        # Mask the HUD corner consistently, so theme names cannot
        # answer the diagnostic. Keep the full camera field, including skyline.
        # Full untouched screenshots remain above; no hidden pixels are invented.
        foreach ($gray in @($false,$true)) {
            $sheet = [Drawing.Bitmap]::new(1152,400)
            $g = [Drawing.Graphics]::FromImage($sheet)
            $attributes = [Drawing.Imaging.ImageAttributes]::new()
            try {
                $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                if ($gray) {
                    $matrix = [Drawing.Imaging.ColorMatrix]::new()
                    $matrix.Matrix00=0.2126; $matrix.Matrix01=0.2126; $matrix.Matrix02=0.2126
                    $matrix.Matrix10=0.7152; $matrix.Matrix11=0.7152; $matrix.Matrix12=0.7152
                    $matrix.Matrix20=0.0722; $matrix.Matrix21=0.0722; $matrix.Matrix22=0.0722
                    $attributes.SetColorMatrix($matrix)
                }
                for ($i=0; $i -lt $themes.Count; $i++) {
                    $im = [Drawing.Bitmap]::new((Join-Path $OutputRoot ($themes[$i] + '-' + $view.name + '-after.png')))
                    try {
                        $x=($i % 4)*288
                        $y=[int][Math]::Floor($i/4)*200
                        $destination = [Drawing.Rectangle]::new($x,$y,288,200)
                        $g.DrawImage($im,$destination,0,0,1440,1000,[Drawing.GraphicsUnit]::Pixel,$attributes)
                        $g.FillRectangle([Drawing.Brushes]::Black,$x,$y,114,52)
                    } finally { $im.Dispose() }
                }
                $suffix = if ($gray) { 'grayscale' } else { 'color' }
                $sheet.Save((Join-Path $OutputRoot ('label-free-' + $view.name + '-' + $suffix + '.png')),[Drawing.Imaging.ImageFormat]::Png)
            } finally { $attributes.Dispose(); $g.Dispose(); $sheet.Dispose() }
        }
    }
    # Before/after thumbnails retain the entire native view and label the pair.
    $smallFont = [Drawing.Font]::new('Segoe UI',11)
    try {
        foreach ($theme in @('chemical_plant','ice_cap','lava_reef')) {
            $panel = [Drawing.Bitmap]::new(576,230 * $views.Count)
            $g = [Drawing.Graphics]::FromImage($panel)
            try {
                $g.Clear($background)
                $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                for ($row=0; $row -lt $views.Count; $row++) {
                    $column=0
                    foreach ($side in @('before','after')) {
                        $g.DrawString(($views[$row].name + ' / ' + $side),$smallFont,[Drawing.Brushes]::White,$column*288+8,$row*230+5)
                        $im = [Drawing.Bitmap]::new((Join-Path $OutputRoot ($theme + '-' + $views[$row].name + '-' + $side + '.png')))
                        try { $g.DrawImage($im,$column*288,$row*230+30,288,200) } finally { $im.Dispose() }
                        $column++
                    }
                }
                $panel.Save((Join-Path $OutputRoot ($theme + '-thumbnails.png')),[Drawing.Imaging.ImageFormat]::Png)
            } finally { $g.Dispose(); $panel.Dispose() }
        }
    } finally { $smallFont.Dispose() }
    $regions=@(
        @{stem='chemical_plant-edge';name='vessel';rect=[Drawing.Rectangle]::new(780,260,660,740)},
        @{stem='ice_cap-hero';name='crown';rect=[Drawing.Rectangle]::new(580,0,700,900)},
        @{stem='lava_reef-hero';name='caldera';rect=[Drawing.Rectangle]::new(580,0,700,900)}
    )
    $details=Join-Path $OutputRoot 'details'
    New-Item -ItemType Directory -Path $details | Out-Null
    foreach ($region in $regions) {
        $rect=$region.rect
        $panel=[Drawing.Bitmap]::new($rect.Width*2,$rect.Height+50)
        $g=[Drawing.Graphics]::FromImage($panel)
        try {
            $g.Clear($background)
            $column=0
            foreach ($side in @('before','after')) {
                $im=[Drawing.Bitmap]::new((Join-Path $OutputRoot ($region.stem + '-' + $side + '.png')))
                try { $crop=$im.Clone($rect,$im.PixelFormat) } finally { $im.Dispose() }
                try {
                    $crop.Save((Join-Path $details ($region.name + '-' + $side + '.png')),[Drawing.Imaging.ImageFormat]::Png)
                    $g.DrawImageUnscaled($crop,$column*$rect.Width,50)
                    $g.DrawString(($side + ' / native pixels'),$font,[Drawing.Brushes]::White,$column*$rect.Width+12,10)
                } finally { $crop.Dispose() }
                $column++
            }
            $panel.Save((Join-Path $details ($region.name + '-pair.png')),[Drawing.Imaging.ImageFormat]::Png)
        } finally { $g.Dispose(); $panel.Dispose() }
    }
    $regions | ForEach-Object { @{source=$_.stem;name=$_.name;x=$_.rect.X;y=$_.rect.Y;width=$_.rect.Width;height=$_.rect.Height;scale=1} } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $details 'coordinates.json') -Encoding UTF8
} finally { $font.Dispose() }
$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $OutputRoot 'index.json') -Encoding UTF8
@{ order=$themes; columns=4; rows=2; source_crop=@{x=0;y=0;width=1440;height=1000}; hud_mask=@{x=0;y=0;width=570;height=260}; tile_size=@{width=288;height=200}; grayscale='Weighted grayscale (0.2126 R + 0.7152 G + 0.0722 B), diagnostic copies only'; purpose='Human composition review, not automated recognition or art-quality certification' } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputRoot 'thumbnail-key.json') -Encoding UTF8
Write-Output "Exported native pairs, final sheets and label-free diagnostics: $OutputRoot"
