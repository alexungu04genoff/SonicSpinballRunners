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
$g.DrawString('PREVIOUS / Orange mineral slabs',$title,$ink,24,16)
$g.DrawString('5B REVISION / Orange wood + rock insets',$title,$ink,824,16)
for ($column=0; $column -lt 2; $column++) {
 $path = if ($column -eq 0) {Join-Path $out '../warm_revision/proposed-study.png'} else {Join-Path $out 'timber-study.png'}
 $image = [Drawing.Image]::FromFile($path)
 $g.DrawImage($image,[Drawing.Rectangle]::new($column*800,70,800,440),110,180,780,430,[Drawing.GraphicsUnit]::Pixel)
 $image.Dispose()
}
$g.DrawString('Unlit material study on generic geometry; not a gameplay screenshot. Only the top-floor texture changes.',$small,$muted,24,524)
$g.DrawString('Approved warm charcoal 3B and dark iron-and-brass 9B remain unchanged. Production is untouched.',$small,$muted,24,551)
$pair.Save((Join-Path $out 'timber-comparison.png'))
$g.Dispose(); $pair.Dispose()

$board = [Drawing.Bitmap]::new(1120,660)
$g = [Drawing.Graphics]::FromImage($board)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('5B / ORANGE TIMBER WITH MINERAL INSETS',$title,$ink,20,12)
$g.DrawString('Refined albedo / one repeat',$font,$ink,20,56)
$g.DrawString('2 x 2 repeats / reduced',$font,$ink,580,56)
for ($column=0; $column -lt 2; $column++) {
 $path = Join-Path $out $(if ($column -eq 0) {'5B.png'} else {'5B-repeat.png'})
 $image = [Drawing.Image]::FromFile($path)
 $g.DrawImage($image,[Drawing.Rectangle]::new(20+$column*560,94,520,520))
 $image.Dispose()
}
$g.DrawString('Broad plank grain and embedded pale-gold rocks. Albedo only; physical relief and in-game mapping await later phases.',$small,$muted,20,628)
$board.Save((Join-Path $out '5B-review.png'))
$g.Dispose(); $board.Dispose()
$title.Dispose(); $font.Dispose(); $small.Dispose(); $ink.Dispose(); $muted.Dispose()
Write-Output 'Saved the timber comparison and source/repeat review.'
