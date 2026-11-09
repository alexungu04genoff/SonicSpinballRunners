Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$current = Join-Path $out '../../../assets/textures/aquarium_park'
$titleFont = [Drawing.Font]::new('Segoe UI', 22, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 16)
$small = [Drawing.Font]::new('Segoe UI', 12)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#e7e5d9'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a6bbc1'))
$roles = @(
 @(4,'Wall transition / vertical fascia','Lacquer beam fascia','Ceramic tile-end frieze',''),
 @(5,'Playable rooftop surfaces','Blue-gray round tiles','Jade staggered shingles','top'),
 @(6,'Horizontal rooftop borders','Matching round-tile edge','Matching shingle edge','top-border')
)
$boards = @{}
foreach($role in $roles) {
 $n = $role[0]
 $height = if($n -in 4,6){245}elseif($n -in 3,9){320}else{455}
 $bmp = [Drawing.Bitmap]::new(1200,$height)
 $g = [Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#202a35'))
 $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$n. $($role[1])",$titleFont,$ink,20,9)
 for($col=0;$col -lt 3;$col++) {
  $x=20+$col*394
  $label=if($col -eq 2){'C / Current albedo'}else{"$(@('A','B')[$col]) / $($role[$col+2])"}
  $g.DrawString($label,$font,$ink,$x,56)
  if($col -eq 2 -and $n -eq 4){
   $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#aa8352'))
   $g.DrawString("Current: direct wall-to-top junction",$small,$muted,$x,130)
   $brush.Dispose()
   $note='N/A: no separate transition material'
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
foreach($group in (,@(4,5,6))) {
 $page++
 $height=68
 foreach($n in $group){$height+=$boards[$n].Height+8}
 $bmp=[Drawing.Bitmap]::new(1200,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#101923'))
 $g.DrawString('AQUARIUM PARK / PHASE 1 / ROOFS + TRANSITIONS',$titleFont,$ink,20,12)
 $y=68
 foreach($n in $group){$g.DrawImageUnscaled($boards[$n],0,$y);$y+=$boards[$n].Height+8}
 $bmp.Save((Join-Path $out "board-$page.png"));$g.Dispose();$bmp.Dispose()
}
foreach($bmp in $boards.Values){$bmp.Dispose()}
$titleFont.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
Write-Output 'Saved reopened role choices; current source textures are read only.'

