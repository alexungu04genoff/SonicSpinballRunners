[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BeforeDirectory,
    [Parameter(Mandatory=$true)][string]$AfterDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$beforeRoot = (Resolve-Path -LiteralPath $BeforeDirectory).Path
$afterRoot = (Resolve-Path -LiteralPath $AfterDirectory).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$before = Get-Content -LiteralPath (Join-Path $beforeRoot 'manifest.json') -Raw | ConvertFrom-Json
$after = Get-Content -LiteralPath (Join-Path $afterRoot 'manifest.json') -Raw | ConvertFrom-Json
if (-not $before.complete -or -not $after.complete) { throw 'Both capture sets must be complete.' }
if ($before.captures.Count -ne $after.captures.Count) { throw 'Capture counts differ.' }
Add-Type -AssemblyName System.Drawing
$font = [Drawing.Font]::new('Segoe UI', 24)
$codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$quality = [Drawing.Imaging.EncoderParameters]::new(1)
$quality.Param[0] = [Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality, [long]94)
try {
    foreach ($old in $before.captures) {
        $new = @($after.captures | Where-Object theme -eq $old.theme)
        if ($new.Count -ne 1) { throw "Missing or duplicate theme: $($old.theme)" }
        $new = $new[0]
        foreach ($key in @('authority','act','source_sha256','scenery_fingerprint','state','graphics','atmosphere','retro_mode','retro_effects','retro_settings_sha256')) {
            if (($old.$key | ConvertTo-Json -Depth 50 -Compress) -cne ($new.$key | ConvertTo-Json -Depth 50 -Compress)) {
                throw "Unmatched $key in $($old.theme)"
            }
        }
        if ($old.fallback_builds -ne 0 -or $new.fallback_builds -ne 0) { throw 'Source fallback is not production evidence.' }
        $left = [Drawing.Image]::FromFile((Join-Path $beforeRoot $old.image))
        $right = [Drawing.Image]::FromFile((Join-Path $afterRoot $new.image))
        if ($left.Size -ne $right.Size) { throw 'Frame dimensions differ.' }
        $pair = [Drawing.Bitmap]::new($left.Width * 2, $left.Height + 64)
        $graphics = [Drawing.Graphics]::FromImage($pair)
        try {
            $graphics.Clear([Drawing.Color]::FromArgb(15,23,36))
            $title = ($old.theme -replace '_',' ').ToUpperInvariant()
            $graphics.DrawString("$title / BEFORE", $font, [Drawing.Brushes]::White, 22, 12)
            $graphics.DrawString("$title / AFTER", $font, [Drawing.Brushes]::White, $left.Width + 22, 12)
            $graphics.DrawImageUnscaled($left, 0, 64)
            $graphics.DrawImageUnscaled($right, $left.Width, 64)
            # The lossless pair retains exact original gameplay pixels. JPEG is
            # a lighter review copy; neither receives color or contrast changes.
            $pair.Save((Join-Path $afterRoot ($old.theme + '-comparison.png')), [Drawing.Imaging.ImageFormat]::Png)
            $pair.Save((Join-Path $output ($old.theme + '.jpg')), $codec, $quality)
        } finally {
            $graphics.Dispose(); $pair.Dispose(); $left.Dispose(); $right.Dispose()
        }
    }
    Copy-Item -LiteralPath (Join-Path $beforeRoot 'manifest.json') -Destination (Join-Path $output 'before-manifest.json')
    Copy-Item -LiteralPath (Join-Path $afterRoot 'manifest.json') -Destination (Join-Path $output 'after-manifest.json')
} finally {
    $quality.Dispose(); $font.Dispose()
}
Write-Output "Exported $($before.captures.Count) matched comparisons to $output"
