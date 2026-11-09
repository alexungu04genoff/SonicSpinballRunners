Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$current = Join-Path $out '../../assets/textures/aquarium_park'
$titleFont = [Drawing.Font]::new('Segoe UI', 22, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 16)
$small = [Drawing.Font]::new('Segoe UI', 12)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#e7e5d9'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a6bbc1'))
$roles = @(
 @(1,'Bottom floor','Lagoon flagstone','Wave-inlaid paving','floor'),
 @(2,'Bottom floor border','Gold scroll lacquer','Stone coping','floor-border'),
 @(3,'Walls','Celadon framed panels','Gold-corner timber','wall'),
 @(5,'Second-floor surfaces','Serpentine blue panels','Broad timber planks','top'),
 @(6,'Second-floor borders','Gold scroll crown','Blue wave ceramic','top-border'),
 @(7,'Ramp decks','Aquatic causeway','Stone bridge deck','ramp'),
 @(8,'Ramp railguards','Lacquer and gold clasps','Carved timber scrolls',''),
 @(9,'Exterior facades','Ivory lattice modules','Floral lacquer coffers','facade')
)
$boards = @{}
foreach($role in $roles) {
 $n = $role[0]
 $height = if($n -in 2,6,8){245}elseif($n -in 3,9){320}else{455}
 $bmp = [Drawing.Bitmap]::new(1200,$height)
 $g = [Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#202a35'))
 $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$n. $($role[1])",$titleFont,$ink,20,9)
 for($col=0;$col -lt 3;$col++) {
  $x=20+$col*394
  $label=if($col -eq 2){'C / Current albedo'}else{"$(@('A','B')[$col]) / $($role[$col+2])"}
  $g.DrawString($label,$font,$ink,$x,56)
  if($col -eq 2 -and $n -eq 8){
   $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#aa8352'))
   $g.FillRectangle($brush,$x,94,374,93)
   $brush.Dispose()
   $note='Material #aa8352; no texture'
  }else{
   $path=if($col -eq 2){Join-Path $current "$($role[4]).png"}else{Join-Path $out "$n$(@('A','B')[$col]).png"}
   $img=[Drawing.Image]::FromFile($path)
   $scale=[Math]::Min(374.0/$img.Width,($height-135.0)/$img.Height)
   $w=[int]($img.Width*$scale);$h=[int]($img.Height*$scale)
   $g.DrawImage($img,[Drawing.Rectangle]::new([int]($x+(374-$w)/2),94,$w,$h))
   $img.Dispose()
   $note=if($col -eq 2){"Existing $($role[4]).png"}else{'Phase 1 / albedo study'}
  }
  $g.DrawString($note,$small,$muted,$x,($height-29))
 }
 $g.Dispose()
 $bmp.Save((Join-Path $out "choices-$n.png"))
 $boards[$n]=$bmp
}
$page=0
foreach($group in @(@(1,2,3),@(5,6,7),@(8,9))) {
 $page++
 $height=68
 foreach($n in $group){$height+=$boards[$n].Height+8}
 $bmp=[Drawing.Bitmap]::new(1200,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#101923'))
 $g.DrawString('AQUARIUM PARK / PHASE 1 / TEXTURE DIRECTIONS',$titleFont,$ink,20,12)
 $y=68
 foreach($n in $group){$g.DrawImageUnscaled($boards[$n],0,$y);$y+=$boards[$n].Height+8}
 $bmp.Save((Join-Path $out "board-$page.png"));$g.Dispose();$bmp.Dispose()
}
foreach($bmp in $boards.Values){$bmp.Dispose()}
$titleFont.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
Write-Output 'Saved three boards. C uses existing PNGs or the exact material base color.'
