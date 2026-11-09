Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$title = [Drawing.Font]::new('Segoe UI',21,[Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI',15)
$small = [Drawing.Font]::new('Segoe UI',12)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#b9b2bd'))
$pair = [Drawing.Bitmap]::new(1600,585)
$g = [Drawing.Graphics]::FromImage($pair)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#17171b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('BEFORE / Bright timber, dark ground',$title,$ink,24,16)
$g.DrawString('REVISED / Shared brightness and rocks',$title,$ink,824,16)
for ($column=0; $column -lt 2; $column++) {
 $path = if ($column -eq 0) {Join-Path $out '../timber_revision/timber-study.png'} else {Join-Path $out 'balanced-study.png'}
 $image = [Drawing.Image]::FromFile($path)
 $g.DrawImage($image,[Drawing.Rectangle]::new($column*800,70,800,440),110,180,780,430,[Drawing.GraphicsUnit]::Pixel)
 $image.Dispose()
}
$g.DrawString('1C ground lighter; 5B timber darker. Both use warm ochre rocks, broad copper facets and muted plum joints.',$small,$muted,24,524)
$g.DrawString('Unlit material study on generic geometry. Same camera and mapping. Approved 3B and 9B unchanged; Phase 2 only.',$small,$muted,24,551)
$pair.Save((Join-Path $out 'balanced-comparison.png'))
$g.Dispose(); $pair.Dispose()

$board = [Drawing.Bitmap]::new(1120,1240)
$g = [Drawing.Graphics]::FromImage($board)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('ONE MINERAL FAMILY / TWO FLOOR MATERIALS',$title,$ink,20,12)
for ($row=0; $row -lt 2; $row++) {
 $id = if ($row -eq 0) {'1C'} else {'5B'}
 $description = if ($row -eq 0) {'1C / Brighter ochre boulder ground'} else {'5B / Darker timber with matching rock insets'}
 $y = 58+$row*580
 $g.DrawString($description,$font,$ink,20,$y)
 $g.DrawString('2 x 2 repeats / reduced',$font,$ink,580,$y)
 for ($column=0; $column -lt 2; $column++) {
  $name = if ($column -eq 0) {$id+'.png'} else {$id+'-repeat.png'}
  $image = [Drawing.Image]::FromFile((Join-Path $out $name))
  $g.DrawImage($image,[Drawing.Rectangle]::new(20+$column*560,$y+36,520,520))
  $image.Dispose()
 }
}
$g.DrawString('Source albedos at left. Shared rock palette and broad bevel treatment; the inset clusters remain visibly periodic.',$small,$muted,20,1210)
$board.Save((Join-Path $out 'floor-review.png'))
$g.Dispose(); $board.Dispose()
$title.Dispose(); $font.Dispose(); $small.Dispose(); $ink.Dispose(); $muted.Dispose()
Write-Output 'Saved the balanced comparison and source/repeat review.'
