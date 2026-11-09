Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$current = Join-Path $out '../../assets/textures/ice_cap'
$titleFont = [Drawing.Font]::new('Segoe UI', 21, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 15)
$small = [Drawing.Font]::new('Segoe UI', 11)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#edf5fc'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a7bfd4'))
$roles = @(
 @(1,'Bottom floor','Snow shelves','Blue ice plates','floor'),
 @(2,'Bottom floor border','Snowbank lip','Crystal diamond ribbon','floor-border'),
 @(3,'Walls','Crystal clusters','Glacier columns','wall'),
 @(5,'Second-floor surfaces','Packed snow crown','Cut ice blocks','top'),
 @(6,'Second-floor borders','Snow-over-ice coping','Diamond crown','top-border'),
 @(7,'Ramp decks','Snow chute','Cut-ice slide','ramp'),
 @(8,'Ramp railguards','Crystal snow guard','Collared ice guard','snow'),
 @(9,'Exterior cliff faces','Crystal curtain','Frozen colonnade','facade'),
 @(10,'Crystal props','Long prism faces','Banded glacial ice','shader'),
 @(11,'Evergreen foliage','Snow-laden boughs','Frost-edged boughs','pine'),
 @(12,'Frozen lake','Joined blue ice','Sparse snow floes','lake')
)
$boards = @{}
foreach($role in $roles) {
 $n = $role[0]
 $height = if($n -in 2,6,8){245}elseif($n -in 3,9,10){330}else{465}
 $bmp = [Drawing.Bitmap]::new(1320,$height)
 $g = [Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#202c3c'))
 $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$n. $($role[1])",$titleFont,$ink,20,8)
 for($col=0;$col -lt 3;$col++) {
  $x=20+$col*434
  $label=if($col -eq 2){'C / Current'}else{"$(@('A','B')[$col]) / $($role[$col+2])"}
  $g.DrawString($label,$font,$ink,$x,56)
  $note='Phase 1 / color study'
  if($col -eq 2 -and $n -in 8,11){
   $color=if($n -eq 8){'#cfdfeb'}else{'#254f57'}
   $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
   $g.FillRectangle($brush,$x,94,414,($height-135))
   $brush.Dispose()
   $note="Live material base $color / no PNG"
  }elseif($col -eq 2 -and $n -in 10,12){
   $lines=if($n -eq 10){@('Existing crystal shader','Opaque blue ice','Cyan view-dependent rim','Glossy; geometry owns facets','','No static albedo texture.','C is not regenerated.')}else{@('Existing frozen-lake shader','Blue base with animated','reflection bands','Published atmosphere colors','','No static albedo texture.','C is not regenerated.')}
   $yy=105
   foreach($line in $lines){$g.DrawString($line,$font,$muted,$x+12,$yy);$yy+=27}
   $note=if($n -eq 10){'ice_crystal.gdshader / active'}else{'ice_lake.gdshader / active'}
  }else{
   $path=if($col -eq 2){Join-Path $current "$($role[4]).png"}else{Join-Path $out "$n$(@('A','B')[$col]).png"}
   $img=[Drawing.Image]::FromFile($path)
   $scale=[Math]::Min(414.0/$img.Width,($height-135.0)/$img.Height)
   $w=[int]($img.Width*$scale);$h=[int]($img.Height*$scale)
   $g.DrawImage($img,[Drawing.Rectangle]::new([int]($x+(414-$w)/2),94,$w,$h))
   $img.Dispose()
   if($col -eq 2){$note="Production $($role[4]).png / unchanged"}
  }
  $g.DrawString($note,$small,$muted,$x,($height-29))
 }
 $g.Dispose()
 $bmp.Save((Join-Path $out "choices-$n.png"))
 $boards[$n]=$bmp
}
$page=0
foreach($group in @(@(1,2,3),@(5,6,7),@(8,9),@(10,11,12))) {
 $page++
 $height=90
 foreach($n in $group){$height+=$boards[$n].Height+8}
 $bmp=[Drawing.Bitmap]::new(1320,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#111c2b'))
 $g.DrawString('ICE CAP / PHASE 1 / TEXTURE DIRECTIONS',$titleFont,$ink,20,8)
 $g.DrawString('A + B: new color studies    C: production asset or documented live material    No integration',$small,$muted,20,49)
 $y=90
 foreach($n in $group){$g.DrawImageUnscaled($boards[$n],0,$y);$y+=$boards[$n].Height+8}
 $bmp.Save((Join-Path $out "board-$page.png"));$g.Dispose();$bmp.Dispose()
}
foreach($bmp in $boards.Values){$bmp.Dispose()}
$titleFont.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
Write-Output 'Saved four boards. C reads existing artwork; shader-only materials are documented, never reconstructed.'
