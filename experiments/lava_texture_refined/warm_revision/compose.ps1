Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$title = [Drawing.Font]::new('Segoe UI',22,[Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI',16)
$small = [Drawing.Font]::new('Segoe UI',12)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#b9b2bd'))

$pair = [Drawing.Bitmap]::new(1600,585)
$g = [Drawing.Graphics]::FromImage($pair)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#17171b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('PREVIOUS / Purple draft',$title,$ink,24,16)
$g.DrawString('PROPOSED / Orange + charcoal',$title,$ink,824,16)
for ($column=0; $column -lt 2; $column++) {
 $file = if ($column -eq 0) {'previous-study.png'} else {'proposed-study.png'}
 $image = [Drawing.Image]::FromFile((Join-Path $out $file))
 # Same framing crop on both unlit study renders; no pixel recolouring.
 $g.DrawImage($image,[Drawing.Rectangle]::new($column*800,70,800,440),110,180,780,430,[Drawing.GraphicsUnit]::Pixel)
 $image.Dispose()
}
$g.DrawString('Unlit material study on a generic two-level block. This is not an in-game screenshot.',$small,$muted,24,524)
$g.DrawString('Same geometry, camera and retained textures. Only 3B, 5B and 9B differ. Production is unchanged.',$small,$muted,24,551)
$pair.Save((Join-Path $out 'balance-comparison.png'))
$g.Dispose(); $pair.Dispose()

$rows = @(
 @('5B','Second floor / orange mineral slabs',420),
 @('3B','Walls / warm charcoal basalt',280),
 @('9B','Exterior / dark iron and brass',280)
)
$board = [Drawing.Bitmap]::new(1320,1124)
$g = [Drawing.Graphics]::FromImage($board)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('LAVA REEF / WARM DIRECTION / PHASE 2 REVIEW',$title,$ink,20,12)
$g.DrawString('Earlier draft',$font,$ink,20,56)
$g.DrawString('Proposed albedo',$font,$ink,455,56)
$g.DrawString('2 x 2 repeat / reduced',$font,$ink,890,56)
$y = 94
foreach ($row in $rows) {
 $id = $row[0]; $height = [int]$row[2]
 $g.DrawString("$id / $($row[1])",$font,$ink,20,$y)
 for ($column=0; $column -lt 3; $column++) {
  $path = if ($column -eq 0) {Join-Path $out "../$id.png"} elseif ($column -eq 1) {Join-Path $out "$id.png"} else {Join-Path $out "$id-repeat.png"}
  $image = [Drawing.Image]::FromFile($path)
  $scale = [Math]::Min(410.0/$image.Width,($height-62.0)/$image.Height)
  $w = [int]($image.Width*$scale); $h = [int]($image.Height*$scale)
  $g.DrawImage($image,[Drawing.Rectangle]::new([int](20+$column*435+(410-$w)/2),($y+42),$w,$h))
  $image.Dispose()
 }
 $y += $height
}
$g.DrawString('No glowing cracks. Purple pipe borders and all other selections remain as previously reviewed.',$small,$muted,20,1085)
$board.Save((Join-Path $out 'revised-textures.png'))
$g.Dispose(); $board.Dispose()
$title.Dispose(); $font.Dispose(); $small.Dispose(); $ink.Dispose(); $muted.Dispose()
Write-Output 'Saved the material-balance comparison and three revised texture pairs.'
