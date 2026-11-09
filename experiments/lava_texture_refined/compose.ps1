Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$titleFont = [Drawing.Font]::new('Segoe UI', 21, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 15)
$small = [Drawing.Font]::new('Segoe UI', 11)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#b6acbb'))
$roles = @(
 @('1C','Bottom floor','Same current rock layout; stone-face variation reduced by 12%.','xy'),
 @('2A','Bottom floor border','Single purple conduit with gold collar pairs.','x'),
 @('3B','Walls','Violet basalt columns, staggered fractures and restrained ore accents.','xy'),
 @('5B','Second-floor surfaces','Complete purple access panels with gold transverse fittings.','xy'),
 @('6B','Second-floor borders - REWORKED','Paired conduits, recessed center channel and broad gold saddles.','x'),
 @('7A','Ramp decks','Selected basalt causeway; fitted slabs with quiet mineral variation.','xy'),
 @('8B','Ramp railguards','Gold structural bays with continuous braces and joint plates.','x'),
 @('9B','Exterior retaining faces','Complete purple-and-gold frames around the selected basalt.','xy')
)

function Draw-FitImage($graphics, [string]$path, [int]$left, [int]$top, [int]$width, [int]$height) {
 $image = [Drawing.Image]::FromFile($path)
 try {
  $scale = [Math]::Min($width / [double]$image.Width, $height / [double]$image.Height)
  $w = [int]($image.Width * $scale)
  $h = [int]($image.Height * $scale)
  $graphics.DrawImage($image, [Drawing.Rectangle]::new([int]($left + ($width-$w)/2),[int]($top + ($height-$h)/2),$w,$h))
 } finally { $image.Dispose() }
}

$boards = @{}
foreach ($role in $roles) {
 $id = $role[0]
 $imageHeight = if ($role[3] -eq 'x') {160} elseif ($id -in '3B','9B') {280} else {440}
 $height = $imageHeight + 150
 $bitmap = [Drawing.Bitmap]::new(1320,$height)
 $g = [Drawing.Graphics]::FromImage($bitmap)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
 $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$id / $($role[1])",$titleFont,$ink,20,10)
 $g.DrawString('Refined albedo / one source repeat',$font,$ink,22,55)
 $repeatText = if ($role[3] -eq 'x') {'Three repeats along length / reduced'} else {'2 x 2 repeats / reduced'}
 $g.DrawString($repeatText,$font,$ink,680,55)
 Draw-FitImage $g (Join-Path $out "$id.png") 20 91 620 $imageHeight
 Draw-FitImage $g (Join-Path $out "$id-repeat.png") 680 91 620 $imageHeight
 $g.DrawString($role[2],$small,$muted,22,($height-49))
 $g.DrawString('Repeat review: no obvious hard seam. Final physical scale and mapping await in-game review.',$small,$muted,22,($height-27))
 $g.Dispose()
 $bitmap.Save((Join-Path $out "$id-review.png"))
 $boards[$id] = $bitmap
}

$page = 0
foreach ($group in @(@('1C','2A','3B'),@('5B','6B','7A'),@('8B','9B'))) {
 $page++
 $height = 94
 foreach ($id in $group) { $height += $boards[$id].Height + 10 }
 $bitmap = [Drawing.Bitmap]::new(1320,$height)
 $g = [Drawing.Graphics]::FromImage($bitmap)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#121019'))
 $g.DrawString('LAVA REEF / PHASE 2 / SELECTED ALBEDOS',$titleFont,$ink,20,10)
 $g.DrawString('Review assets only. Production unchanged. No new material-response maps.',$small,$muted,22,52)
 $y = 94
 foreach ($id in $group) { $g.DrawImageUnscaled($boards[$id],0,$y); $y += $boards[$id].Height + 10 }
 $bitmap.Save((Join-Path $out "selected-$page.png"))
 $g.Dispose(); $bitmap.Dispose()
}

# Preserve a direct comparison for the explicitly requested, subtle 1C change.
$comparison = [Drawing.Bitmap]::new(1080,615)
$g = [Drawing.Graphics]::FromImage($comparison)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('1C / Current production',$font,$ink,20,12)
$g.DrawString('1C / Slightly calmer draft',$font,$ink,560,12)
Draw-FitImage $g (Join-Path $out '../../assets/textures/lava_reef/floor.png') 20 58 500 500
Draw-FitImage $g (Join-Path $out '1C.png') 560 58 500 500
$g.DrawString('Same layout and rock count; lower facet contrast. No blur applied.',$small,$muted,20,580)
$comparison.Save((Join-Path $out '1C-current-vs-refined.png'))
$g.Dispose(); $comparison.Dispose()
foreach ($bitmap in $boards.Values) { $bitmap.Dispose() }
$titleFont.Dispose(); $font.Dispose(); $small.Dispose(); $ink.Dispose(); $muted.Dispose()
Write-Output 'Saved three selected-material sheets, eight review pairs, and the 1C comparison.'
