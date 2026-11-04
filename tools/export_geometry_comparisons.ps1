[CmdletBinding()]
param(
    [string]$CaptureRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'test-results\geometry-density'),
    [string]$OutputRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\geometry-density\full-resolution')
)
# Post-process existing canonical captures only. Never launch Godot or alter source pixels.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$CaptureRoot = (Resolve-Path -LiteralPath $CaptureRoot).Path
New-Item -ItemType Directory -Force -Path $OutputRoot, (Join-Path $OutputRoot 'details'), (Join-Path $OutputRoot 'supplemental') | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$records = [Collections.Generic.List[object]]::new()
$font = [Drawing.Font]::new('Segoe UI', 16)
$smallFont = [Drawing.Font]::new('Segoe UI', 11)
$white = [Drawing.Brushes]::White
$background = [Drawing.Color]::FromArgb(12, 20, 31)
$headerHeight = 80

function Read-Capture([string]$Directory, [string]$Theme) {
    $manifestPath = Join-Path $CaptureRoot "$Directory\manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $receipt = @($manifest.captures | Where-Object theme -eq $Theme)
    if ($receipt.Count -ne 1) { throw "Expected one $Theme receipt in $Directory" }
    return $receipt[0]
}

function Assert-Matched($Before, $After) {
    foreach ($field in @('state', 'atmosphere', 'act_fingerprint', 'scenery_fingerprint', 'seed', 'theme')) {
        $a = $Before.$field | ConvertTo-Json -Depth 30 -Compress
        $b = $After.$field | ConvertTo-Json -Depth 30 -Compress
        if ($a -cne $b) { throw "Capture mismatch: $field / $($Before.theme)" }
    }
    foreach ($field in @('api', 'device', 'driver', 'engine', 'renderer')) {
        if ($Before.renderer.$field -cne $After.renderer.$field) { throw "Renderer mismatch: $field" }
    }
}

function Copy-Original([string]$Directory, [string]$Theme, [string]$Destination) {
    $source = Join-Path $CaptureRoot "$Directory\$Theme.png"
    $target = Join-Path $OutputRoot $Destination
    Copy-Item -LiteralPath $source -Destination $target -Force
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw "Copy mismatch: $Destination" }
    return @{ path = $Destination.Replace('\', '/'); sha256 = $hash; capture = "$Directory/$Theme.png" }
}

function Write-Comparison([string]$Name, [string]$Title, [string[]]$Sources, [string[]]$Labels, [int[]]$Crop, [int]$Scale = 1) {
    $width = $Crop[2] * $Scale
    $height = $Crop[3] * $Scale
    $canvas = [Drawing.Bitmap]::new($width * $Sources.Count, $height + $headerHeight)
    $graphics = [Drawing.Graphics]::FromImage($canvas)
    try {
        $graphics.Clear($background)
        $graphics.DrawString($Title, $font, $white, 12, 4)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        for ($i = 0; $i -lt $Sources.Count; $i++) {
            $image = [Drawing.Bitmap]::new((Join-Path $CaptureRoot $Sources[$i]))
            try {
                if ($image.Width -ne 1440 -or $image.Height -ne 1000) { throw "Unexpected capture size: $($Sources[$i])" }
                if ($Crop[0] -lt 0 -or $Crop[1] -lt 0 -or $Crop[0] + $Crop[2] -gt $image.Width -or $Crop[1] + $Crop[3] -gt $image.Height) { throw "Crop outside source: $Name" }
                $rect = [Drawing.Rectangle]::new($Crop[0], $Crop[1], $Crop[2], $Crop[3])
                $part = $image.Clone($rect, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
                try {
                    $graphics.DrawString("$($Labels[$i]) | ${Scale}x source pixels", $smallFont, $white, $i * $width + 12, 42)
                    if ($Scale -eq 1) { $graphics.DrawImageUnscaled($part, $i * $width, $headerHeight) }
                    else {
                        $destination = [Drawing.Rectangle]::new($i * $width, $headerHeight, $width, $height)
                        $graphics.DrawImage($part, $destination, 0, 0, $part.Width, $part.Height, [Drawing.GraphicsUnit]::Pixel)
                    }
                } finally { $part.Dispose() }
            } finally { $image.Dispose() }
        }
        $canvas.Save((Join-Path $OutputRoot $Name), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $canvas.Dispose() }
    $records.Add(@{ output = $Name.Replace('\', '/'); sources = $Sources; crop_xywh = $Crop; integer_scale = $Scale; header_height = $headerHeight; labels = $Labels })
}

try {
    $themes = @('green_hill', 'chemical_plant', 'rooftop_run', 'casino_night', 'sky_sanctuary', 'ice_cap', 'lava_reef', 'aquarium_park')
    $originals = [Collections.Generic.List[object]]::new()
    foreach ($theme in $themes) {
        Assert-Matched (Read-Capture 'before' $theme) (Read-Capture 'after' $theme)
        $originals.Add((Copy-Original 'before' $theme "$theme-before.png"))
        $originals.Add((Copy-Original 'after' $theme "$theme-after.png"))
        Write-Comparison "$theme-pair.png" ($theme.Replace('_', ' ').ToUpper() + ' | canonical Prototype') @("before/$theme.png", "after/$theme.png") @('BEFORE', 'AFTER') @(0, 0, 1440, 1000)
    }
    $details = @(
        @{ name='green-hill-flower'; title='Green Hill sunflower'; theme='green_hill'; crop=@(880,745,160,125); scale=4 },
        @{ name='ring'; title='Ordinary Rings and ground shadows'; theme='green_hill'; crop=@(260,430,140,115); scale=4 },
        @{ name='bumper'; title='Round bumper'; theme='green_hill'; crop=@(640,345,175,140); scale=3 },
        @{ name='sky-foliage'; title='Sky Sanctuary foliage'; theme='sky_sanctuary'; crop=@(700,645,455,275); scale=2 },
        @{ name='aquarium-architecture'; title='Aquarium roof, posts and lanterns'; theme='aquarium_park'; crop=@(1020,0,420,870); scale=1 },
        @{ name='aquarium-lantern'; title='Aquarium repeated lantern'; theme='aquarium_park'; crop=@(865,715,190,180); scale=3 }
    )
    foreach ($detail in $details) {
        Write-Comparison "details/$($detail.name).png" $detail.title @("before/$($detail.theme).png", "after/$($detail.theme).png") @('BEFORE', 'AFTER') $detail.crop $detail.scale
    }
    Assert-Matched (Read-Capture 'loop-focused-64' 'green_hill') (Read-Capture 'loop-fixed-16' 'green_hill')
    $originals.Add((Copy-Original 'loop-focused-64' 'green_hill' 'supplemental/loop-64.png'))
    $originals.Add((Copy-Original 'loop-fixed-16' 'green_hill' 'supplemental/loop-16.png'))
    Write-Comparison 'details/green-hill-loop.png' 'Green Hill loop | matched supplemental camera (570, 500)' @('loop-focused-64/green_hill.png', 'loop-fixed-16/green_hill.png') @('64 STEPS', '16 STEPS + FACE FIX') @(130,15,510,760)
    $originals.Add((Copy-Original 'edge-review' 'sky_sanctuary' 'supplemental/sky-edge-after.png'))
    Write-Comparison 'details/sky-clouds-after-only.png' 'Sky clouds | AFTER ONLY' @('edge-review/sky_sanctuary.png') @('No matched before cloud view in saved captures') @(1060,35,330,365) 2
    @{ source_capture_size = @(1440,1000); pair_size = @(2880,1080); method = 'Lossless PNG; no rerender, sharpening or color changes. Crops use identical source rectangles and integer nearest-neighbor magnification.'; originals = $originals.ToArray(); comparisons = $records.ToArray(); limitation = 'Cloud-bank detail is after-only: the saved before camera does not expose it. Supplemental loop captures isolate the loop calibration, not a complete historical before/after scene.' } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutputRoot 'index.json') -Encoding utf8
    Write-Output "Exported $($themes.Count) full-resolution pairs, $($details.Count + 1) detail pairs, one after-only cloud crop and $($originals.Count) unchanged originals to $OutputRoot"
} finally { $font.Dispose(); $smallFont.Dispose() }
