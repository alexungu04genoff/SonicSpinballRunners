Add-Type -AssemblyName System.Drawing
$ErrorActionPreference='Stop'
$out=$PSScriptRoot
$title=[Drawing.Font]::new('Segoe UI',21,[Drawing.FontStyle]::Bold)
$small=[Drawing.Font]::new('Segoe UI',12)
$ink=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$muted=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#b9b2bd'))
$bitmap=[Drawing.Bitmap]::new(1600,665)
$g=[Drawing.Graphics]::FromImage($bitmap)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#17171b'))
$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawString('DETAIL OFF',$title,$ink,24,14)
$g.DrawString('CURRENT / APPROVED STRONG NORMALS',$title,$ink,824,14)
for($i=0;$i -lt 2;$i++){
 $name=if($i -eq 0){'depth-off.png'}else{'depth-on.png'}
 $image=[Drawing.Image]::FromFile((Join-Path $out $name))
 $g.DrawImage($image,[Drawing.Rectangle]::new($i*800,60,800,556))
 $image.Dispose()
}
$g.DrawString('Actual Prototype, same frame and camera. Existing atmosphere and Retro retained. Approved albedo pixels unchanged.',$small,$muted,24,635)
$bitmap.Save((Join-Path $out 'comparison.png'))
$g.Dispose();$bitmap.Dispose()
$title.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
Write-Output 'Saved the matched in-game material comparison.'
