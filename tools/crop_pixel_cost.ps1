[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$directory = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$destination = Join-Path $directory 'native-crops'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
# Integer pixel extraction only: no resizing, sharpening, color changes or interpolation.
# All coordinates refer to untouched 1280 x 900 full frames.
foreach ($workload in @('small', 'dense', 'busy')) {
$regions = switch ($workload) {
 'small' { @{
    'diagonal-flipper' = [Drawing.Rectangle]::new(410, 320, 330, 180)
    'character-rings' = [Drawing.Rectangle]::new(590, 440, 240, 180)
    'flipper-terrain' = [Drawing.Rectangle]::new(530, 700, 330, 180)
    'thin-scenery' = [Drawing.Rectangle]::new(80, 420, 330, 240)
    'contrast-silhouettes' = [Drawing.Rectangle]::new(800, 160, 350, 220)
    'hud' = [Drawing.Rectangle]::new(20, 25, 365, 190)
 } }
 'dense' { @{ 'elevated-rails' = [Drawing.Rectangle]::new(400, 290, 470, 270) } }
 'busy' { @{ 'diagonal-rail-scenery' = [Drawing.Rectangle]::new(790, 0, 450, 200); 'contrast-edge' = [Drawing.Rectangle]::new(180, 570, 350, 200) } }
}
foreach ($frame in Get-ChildItem -LiteralPath $directory -Filter "$workload-*.png") {
    $source = [Drawing.Bitmap]::new($frame.FullName)
    try {
        if ($source.Width -ne 1280 -or $source.Height -ne 900) { throw 'Expected native 1280 x 900 evidence' }
        foreach ($name in $regions.Keys) {
            $crop = $source.Clone($regions[$name], $source.PixelFormat)
            try { $crop.Save((Join-Path $destination ($frame.BaseName + "-$name.png")), [Drawing.Imaging.ImageFormat]::Png) }
            finally { $crop.Dispose() }
        }
    } finally { $source.Dispose() }
}
# Comparison panels place the untouched crops at 1:1 beside each other.
$sets = @{
    'normal-msaa' = @('r1-msaa0-scale100', 'r1-msaa2-scale100', 'r1-msaa4-scale100')
    'clean-msaa' = @('clean-msaa0-scale100-fxaa0', 'clean-msaa2-scale100-fxaa0', 'clean-msaa4-scale100-fxaa0')
    'clean-fxaa' = @('clean-msaa2-scale100-fxaa0', 'clean-msaa2-scale100-fxaa1', 'clean-msaa4-scale100-fxaa0')
    'normal-scale' = @('r1-msaa4-scale100', 'r1-msaa4-scale85', 'r1-msaa4-scale75')
}
foreach ($set in $sets.Keys) {
    foreach ($name in $regions.Keys) {
        $width = $regions[$name].Width
        $height = $regions[$name].Height
        $panel = [Drawing.Bitmap]::new($width * 3, $height + 32)
        $graphics = [Drawing.Graphics]::FromImage($panel)
        $font = [Drawing.Font]::new('Consolas', 10)
        try {
            $graphics.Clear([Drawing.Color]::White)
            for ($index = 0; $index -lt 3; $index++) {
                $label = $sets[$set][$index]
                $crop = [Drawing.Bitmap]::new((Join-Path $destination "$workload-$label-$name.png"))
                try { $graphics.DrawImageUnscaled($crop, $width * $index, 32) }
                finally { $crop.Dispose() }
                $graphics.DrawString($label, $font, [Drawing.Brushes]::Black, $width * $index, 8)
            }
            $panel.Save((Join-Path $destination "$workload-$set-$name.png"), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $font.Dispose(); $panel.Dispose() }
    }
}
$regions.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } | Set-Content (Join-Path $destination "$workload-crop-coordinates.txt")
}
Write-Output "Native crops and 1:1 panels: $destination"
