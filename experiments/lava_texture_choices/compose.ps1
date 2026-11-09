Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$current = Join-Path $out '../../assets/textures/lava_reef'
$titleFont = [Drawing.Font]::new('Segoe UI', 21, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 15)
$small = [Drawing.Font]::new('Segoe UI', 11)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#b6acbb'))
$roles = @(
 @(1,'Bottom floor','Mineral shelf','Flow-banded basalt','floor','Sheet: broad gold / cool rock facets','Sheet: dark cave infill / purple mineral'),
 @(2,'Bottom floor border','Pipe coping','Cut mineral coping','floor-border','Sheet: lilac pipes and gold couplers','Sheet: chunky stone edge modules'),
 @(3,'Walls','Honey mineral breccia','Violet basalt columns','wall','Sheet: pale rock faces and cyan seams','Sheet: dark infill / purple mineral fields'),
 @(5,'Second-floor surfaces','Amethyst shelf','Mine service panels','top','Sheet: purple mineral and cyan facets','Sheet: purple machinery / gold framing'),
 @(6,'Second-floor borders','Mineral crown','Pipe crown','top-border','Sheet: exposed gold stone rim','Sheet: long pipes and gold couplers'),
 @(7,'Ramp decks','Basalt causeway','Mining treadplate','ramp','Sheet: stone steps; Marble: laid courses','Sheet: machinery; Red Mountain: bridges'),
 @(8,'Ramp railguards','Purple pipe guard','Gold box girder','','Sheet: purple plumbing and gold joints','Sheet: diagonal gold mining supports'),
 @(9,'Exterior cliffs / retaining faces','Layered mineral cliff','Mine retaining bays','facade','Sheet: gold boulders / purple rock strata','Sheet: dark infill within pipe / gold frames'),
 @(10,'Lava','Broad molten ropes','Floating crust plates','shader','Sheet: narrow yellow-red lava strip','Sheet: broken rock silhouettes above lava'),
 @(11,'Crystals','Amethyst growth','Honey mineral inclusions','shader','Sheet: violet mineral / cyan rock edges','Sheet: honey-gold and cyan mineral faces')
)
$boards = @{}
foreach($role in $roles) {
 $n = [int]$role[0]
 $height = if($n -in 2,6,8){272}elseif($n -in 3,9){355}else{496}
 $bmp = [Drawing.Bitmap]::new(1320,$height)
 $g = [Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#211e2b'))
 $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$n. $($role[1])",$titleFont,$ink,20,9)
 for($col=0;$col -lt 3;$col++) {
  $x=20+$col*434
  $label=if($col -eq 2){'C / Current material'}else{"$(@('A','B')[$col]) / $($role[$col+2])"}
  $g.DrawString($label,$font,$ink,$x,55)
  if($col -eq 2 -and $n -eq 8){
   # Exact existing StandardMaterial3D base colour; a key, not a new texture.
   $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#8277bb'))
   $g.FillRectangle($brush,$x,94,414,103)
   $brush.Dispose()
   $note='Iron #8277bb; metallic .45 / roughness .38'
  }else{
   $path=if($col -eq 2 -and $n -in 10,11){Join-Path $out "$($n)C-material.png"}elseif($col -eq 2){Join-Path $current "$($role[4]).png"}else{Join-Path $out "$n$(@('A','B')[$col]).png"}
   $img=[Drawing.Image]::FromFile($path)
   $scale=[Math]::Min(414.0/$img.Width,($height-155.0)/$img.Height)
   $w=[int]($img.Width*$scale);$h=[int]($img.Height*$scale)
   $g.DrawImage($img,[Drawing.Rectangle]::new([int]($x+(414-$w)/2),94,$w,$h))
   $img.Dispose()
   $note=if($col -eq 2 -and $n -in 10,11){'Existing shader / published Default atmosphere'}elseif($col -eq 2){"Existing $($role[4]).png; source pixels unchanged"}else{$role[5+$col]}
  }
  $g.DrawString($note,$small,$muted,$x,($height-49))
  $context=if($col -eq 2 -and $n -in 10,11){'Material portrait, including current response'}elseif($col -eq 2 -and $n -eq 8){'Unlit colour key; no texture exists'}elseif($col -eq 2){'Current albedo; lighting not baked into this view'}else{'Phase 1 / new albedo study / no depth maps'}
  $g.DrawString($context,$small,$muted,$x,($height-27))
 }
 $g.Dispose()
 $bmp.Save((Join-Path $out "choices-$n.png"))
 $boards[$n]=$bmp
}
$page=0
foreach($group in @(@(1,2,3),@(5,6,7),@(8,9),@(10,11))) {
 $page++
 $height=74
 foreach($n in $group){$height+=$boards[$n].Height+10}
 $bmp=[Drawing.Bitmap]::new(1320,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#121019'))
 $g.DrawString('LAVA REEF / PHASE 1 / TEXTURE DIRECTIONS',$titleFont,$ink,20,12)
 $y=74
 foreach($n in $group){$g.DrawImageUnscaled($boards[$n],0,$y);$y+=$boards[$n].Height+10}
 $bmp.Save((Join-Path $out "board-$page.png"))
 $g.Dispose();$bmp.Dispose()
}
foreach($bmp in $boards.Values){$bmp.Dispose()}
$titleFont.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
Write-Output 'Saved four boards. C reads current production art or photographs unchanged source materials.'
