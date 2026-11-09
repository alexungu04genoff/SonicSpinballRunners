[CmdletBinding()]
param(
    [string]$EvidenceRoot = 'test-results/atmosphere-signatures',
    [string]$OutputDirectory = 'docs/atmosphere-signatures'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$destination = [IO.Path]::GetFullPath($OutputDirectory)
$themes = @('green_hill', 'chemical_plant', 'rooftop_run', 'casino_night')
$changed = @('chemical_plant', 'casino_night')
$rows = [Collections.Generic.List[object]]::new()
$font = [Drawing.Font]::new('Segoe UI', 18)
function Folder([string]$relative) {
    $path = Join-Path $destination $relative
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}
function Batch([string]$stage, [string]$mode, [string]$tier) {
    $relative = if ($stage -eq 'before') {
        if ($mode -eq 'off' -and $tier -in @('spawn', 'mid')) { "baseline/$mode/$tier" }
        else { "before-four/$mode/$tier" }
    } else { "trial1/$mode/$tier" }
    $path = Join-Path $root $relative
    $manifest = Get-Content -LiteralPath "$path/manifest.json" -Raw | ConvertFrom-Json
    if (-not $manifest.complete) { throw "Incomplete batch: $path" }
    $log = Get-Content -LiteralPath "$path/regression.log" -Raw
    if ($log -notmatch 'RESULT \| Prototype appearance regression \| \d+ checks \| 0 failures') { throw "Unverified batch: $path" }
    $receiptFolder = Folder "receipts/$stage/$mode/$tier"
    foreach ($name in @('manifest.json','provenance.json','sources-before.json','sources-after.json','regression.log','regression.err')) {
        $text = [IO.File]::ReadAllText("$path/$name").Replace("`r`n", "`n")
        [IO.File]::WriteAllText("$receiptFolder/$name", $text, [Text.UTF8Encoding]::new($false))
    }
    return @{Path=$path; Manifest=$manifest}
}
function Draw-Frame($graphics, [string]$path, [int]$x, [int]$y) {
    $image = [Drawing.Image]::FromFile($path)
    try {
        if ($image.Width -ne 1440 -or $image.Height -ne 1000) { throw "Unexpected frame size: $path" }
        $graphics.DrawImageUnscaled($image, $x, $y)
    } finally { $image.Dispose() }
}
foreach ($mode in @('production','off')) {
    $sheet = [Drawing.Bitmap]::new(2880,2080)
    $graphics = [Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([Drawing.Color]::FromArgb(12,20,32))
    $thumb = [Drawing.Bitmap]::new(1080,1000)
    $tg = [Drawing.Graphics]::FromImage($thumb)
    foreach ($tier in @('spawn','mid','upper')) {
        $before = Batch 'before' $mode $tier
        $after = Batch 'after' $mode $tier
        foreach ($theme in $themes) {
            $a = $before.Manifest.captures | Where-Object theme -eq $theme
            $isChanged = $theme -in $changed
            $b = if ($isChanged) { $after.Manifest.captures | Where-Object theme -eq $theme } else { $a }
            if (-not $a -or -not $b -or $a.fallback_builds -ne 0 -or $b.fallback_builds -ne 0) { throw "Missing or fallback receipt: $theme" }
            foreach ($key in @('state','graphics','source_sha256','pipeline_fingerprint','scenery_fingerprint','act_bake_sha256','theme_bake_sha256','current_texture_matches','retro_mode','retro_effects','retro_settings_sha256')) {
                if (($a.$key | ConvertTo-Json -Depth 25 -Compress) -cne ($b.$key | ConvertTo-Json -Depth 25 -Compress)) { throw "Mismatched $key : $theme / $mode / $tier" }
            }
            if ($a.retro_mode -ne $mode) { throw "Unexpected Retro mode: $theme / $mode / $tier" }
            foreach ($key in @('renderer','driver','device','engine','api')) {
                if ($a.renderer.$key -ne $b.renderer.$key) { throw "Renderer mismatch: $key" }
            }
            $first = Join-Path $before.Path $a.image
            $last = if ($isChanged) { Join-Path $after.Path $b.image } else { $first }
            $pairPath = $null
            if ($isChanged) {
                $pairPath = "pairs/$mode/$theme-$tier.png"
                $pair = [Drawing.Bitmap]::new(2880,1040)
                $pg = [Drawing.Graphics]::FromImage($pair)
                $pg.Clear([Drawing.Color]::FromArgb(12,20,32))
                $pg.DrawString("$theme / $tier / Retro $mode / BEFORE",$font,[Drawing.Brushes]::White,12,4)
                $pg.DrawString('AFTER / unchanged gameplay and native output scale',$font,[Drawing.Brushes]::White,1452,4)
                Draw-Frame $pg $first 0 40
                Draw-Frame $pg $last 1440 40
                Folder "pairs/$mode" | Out-Null
                $pair.Save((Join-Path $destination $pairPath),[Drawing.Imaging.ImageFormat]::Png)
                $pg.Dispose(); $pair.Dispose()
            }
            $themeIndex = [Array]::IndexOf($themes,$theme)
            if ($tier -eq 'spawn') {
                $x = ($themeIndex % 2) * 1440
                $y = [int][Math]::Floor($themeIndex / 2) * 1040
                $graphics.DrawString("$theme / Retro $mode" + $(if(-not $isChanged){' / unchanged control'}else{''}),$font,[Drawing.Brushes]::White,($x+12),($y+4))
                Draw-Frame $graphics $last $x ($y+40)
            }
            $original = [Drawing.Bitmap]::new($last)
            $mask = [Drawing.Graphics]::FromImage($original)
            $mask.FillRectangle([Drawing.Brushes]::Black,0,0,570,255)
            $mask.Dispose()
            $tg.DrawImage($original,([Array]::IndexOf(@('spawn','mid','upper'),$tier)*360),($themeIndex*250),360,250)
            $original.Dispose()
            $rows.Add(@{theme=$theme;mode=$mode;tier=$tier;changed=$isChanged;pair=$pairPath;control_reuses_baseline=(-not $isChanged);
                before_sha256=(Get-FileHash -LiteralPath $first).Hash;after_sha256=(Get-FileHash -LiteralPath $last).Hash;matched=$true})
        }
    }
    $sheet.Save("$destination/four-themes-$mode.png",[Drawing.Imaging.ImageFormat]::Png)
    $thumb.Save("$destination/label-free-$mode.png",[Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $sheet.Dispose(); $tg.Dispose(); $thumb.Dispose()
}
$font.Dispose()
$rows | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$destination/pair-verification.json" -Encoding utf8NoBOM
Write-Output "Verified and exported $($rows.Count) matched records. Controls explicitly reuse unchanged baseline images."
