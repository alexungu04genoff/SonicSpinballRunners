[CmdletBinding()]
param([string]$EvidenceRoot = 'test-results/visual-strength-20261109')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$themes = @('green_hill','chemical_plant','casino_night','rooftop_run','sky_sanctuary','ice_cap','lava_reef','aquarium_park')
$batches = @{}
$rows = @()
foreach ($tier in @('spawn','mid')) {
    $source = Join-Path $root "final-$tier"
    $manifest = Get-Content -LiteralPath "$source/manifest.json" -Raw | ConvertFrom-Json
    if (-not $manifest.complete -or $manifest.captures.Count -ne 8) { throw "Incomplete batch: $tier" }
    if ((Get-Content -LiteralPath "$source/regression.log" -Raw) -notmatch 'RESULT \| Prototype appearance regression \| \d+ checks \| 0 failures') { throw "Unverified batch: $tier" }
    foreach ($log in @('capture.log','capture.err','regression.log','regression.err')) {
        if (Select-String -LiteralPath "$source/$log" -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet) { throw "Errors in $tier/$log" }
    }
    $receipts = Join-Path $PSScriptRoot "receipts/$tier"
    $frames = Join-Path $PSScriptRoot "frames/$tier"
    New-Item -ItemType Directory -Force $receipts,$frames | Out-Null
    foreach ($file in @('manifest.json','provenance.json','sources-before.json','sources-after.json','capture.log','capture.err','regression.log','regression.err')) {
        $content = [IO.File]::ReadAllText("$source/$file").Replace("`r`n", "`n")
        [IO.File]::WriteAllText("$receipts/$file", $content, [Text.UTF8Encoding]::new($false))
    }
    foreach ($theme in $themes) {
        $capture = @($manifest.captures | Where-Object theme -eq $theme)
        if ($capture.Count -ne 1 -or $capture[0].fallback_builds -ne 0 -or $capture[0].retro_mode -ne 'production') { throw "Invalid capture: $theme / $tier" }
        Copy-Item -LiteralPath "$source/$theme.png" -Destination "$frames/$theme.png"
        $rows += @{theme=$theme;tier=$tier;image="frames/$tier/$theme.png";sha256=(Get-FileHash -LiteralPath "$frames/$theme.png" -Algorithm SHA256).Hash}
    }
    $batches[$tier] = $manifest
}
foreach ($theme in $themes) {
    $a = $batches.spawn.captures | Where-Object theme -eq $theme
    $b = $batches.mid.captures | Where-Object theme -eq $theme
    foreach ($key in @('source_sha256','pipeline_fingerprint','scenery_fingerprint','act_bake_sha256','theme_bake_sha256','current_texture_matches','atmosphere','graphics','retro_mode','retro_effects','retro_settings_sha256')) {
        if (($a.$key | ConvertTo-Json -Depth 30 -Compress) -cne ($b.$key | ConvertTo-Json -Depth 30 -Compress)) { throw "Changed $key between views: $theme" }
    }
    foreach ($key in $a.state.PSObject.Properties.Name) {
        if ($key -ne 'camera_transform' -and ($a.state.$key | ConvertTo-Json -Depth 10 -Compress) -cne ($b.state.$key | ConvertTo-Json -Depth 10 -Compress)) { throw "Changed gameplay/camera setting: $key / $theme" }
    }
}
$sheet = [Drawing.Bitmap]::new(1440,2212)
$graphics = [Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([Drawing.Color]::FromArgb(12,20,32))
$graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [Drawing.Font]::new('Segoe UI',18)
$small = [Drawing.Font]::new('Segoe UI',11)
$graphics.DrawString('CURRENT PRODUCTION / Eight-theme visual strength / 2026-11-09',$font,[Drawing.Brushes]::White,14,8)
$graphics.DrawString('Prototype / production Retro / Default atmospheres / same ordinary gameplay camera / no visual edits',$small,[Drawing.Brushes]::LightGray,14,42)
$thumb = [Drawing.Bitmap]::new(1440,1000)
$tg = [Drawing.Graphics]::FromImage($thumb)
$tg.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($i=0; $i -lt $themes.Count; $i++) {
    $theme = $themes[$i]
    $x = ($i % 2)*720
    $row = [int][Math]::Floor($i/2)
    $y = 68+$row*536
    $graphics.DrawString(($theme -replace '_',' ').ToUpperInvariant(),$font,[Drawing.Brushes]::White,($x+12),$y)
    foreach ($tier in @('spawn','mid')) {
        $frame = [Drawing.Bitmap]::new((Join-Path $PSScriptRoot "frames/$tier/$theme.png"))
        if ($frame.Width -ne 1440 -or $frame.Height -ne 1000) { throw 'Unexpected frame dimensions.' }
        if ($tier -eq 'spawn') { $graphics.DrawImage($frame,$x,($y+34),720,500) }
        # Hide the existing HUD, including theme names, without changing the gameplay crop.
        $mask = [Drawing.Graphics]::FromImage($frame)
        $mask.FillRectangle([Drawing.Brushes]::Black,0,0,570,255)
        $mask.Dispose()
        $offset = if ($tier -eq 'spawn') { 0 } else { 360 }
        $tg.DrawImage($frame,($x+$offset),($row*250),360,250)
        $frame.Dispose()
    }
}
try {
    $sheet.Save("$PSScriptRoot/eight-themes.png",[Drawing.Imaging.ImageFormat]::Png)
    $thumb.Save("$PSScriptRoot/label-free.png",[Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose(); $sheet.Dispose(); $tg.Dispose(); $thumb.Dispose(); $font.Dispose(); $small.Dispose()
}
@{views=$rows;cross_view_sources_graphics_atmosphere_matched=$true;production_changes=@();thumbnail_hud_mask=@(0,0,570,255);thumbnail_frame_size=@(360,250)} |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$PSScriptRoot/verification.json" -Encoding utf8
Write-Output 'Exported 16 verified frames, eight-theme normal sheet and label-free paired thumbnails.'
