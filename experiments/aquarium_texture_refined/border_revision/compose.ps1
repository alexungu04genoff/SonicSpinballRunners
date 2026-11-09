Add-Type -AssemblyName System.Drawing
$out=$PSScriptRoot
$board=[Drawing.Bitmap]::new(1100,560)
$g=[Drawing.Graphics]::FromImage($board)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#182832'))
$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$title=[Drawing.Font]::new('Segoe UI',21,[Drawing.FontStyle]::Bold)
$font=[Drawing.Font]::new('Segoe UI',16)
$small=[Drawing.Font]::new('Segoe UI',12)
$ink=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#eee7d7'))
$muted=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a7bdc3'))
$g.DrawString('2 / FLOOR BORDER REVISION',$title,$ink,20,12)
$choices=@(
 @('A / Red with sparse gold studs','2A-red-gold-studs.png'),
 @('B / Plain red','2B-plain-red.png'),
 @('C / Current gold-scroll trim','../../../assets/textures/aquarium_park/selected/2A.png')
)
$y=62
foreach($choice in $choices){
 $g.DrawString($choice[0],$font,$ink,20,$y)
 $image=[Drawing.Image]::FromFile((Join-Path $out $choice[1]))
 $g.DrawImage($image,[Drawing.Rectangle]::new(20,($y+36),384,96))
 for($i=0;$i -lt 2;$i++){$g.DrawImage($image,[Drawing.Rectangle]::new((430+$i*320),($y+36),320,80))}
 $image.Dispose();$y+=155
}
$g.DrawString('New A/B are proposals. The in-game views still show current C.',$small,$muted,20,530)
$board.Save((Join-Path $out 'border-choices.png'))
$g.Dispose();$board.Dispose();$title.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
