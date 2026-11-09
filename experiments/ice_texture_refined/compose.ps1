Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot
$titleFont = [Drawing.Font]::new('Segoe UI', 23, [Drawing.FontStyle]::Bold)
$font = [Drawing.Font]::new('Segoe UI', 14)
$small = [Drawing.Font]::new('Segoe UI', 11)
$ink = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#edf5fc'))
$muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a7bfd4'))
$roles = @(
 @('1A','Bottom floor / snow shelves','xy'),
 @('2B','Bottom floor border / diamond ribbon','x'),
 @('3A','Walls / crystal clusters','x'),
 @('5A','Second-floor surfaces / packed snow','xy'),
 @('6A','Second-floor borders / snow coping','x'),
 @('7B','Ramp decks / cut-ice slide','y'),
 @('8A','Ramp railguards / crystal snow guard','x'),
 @('9A','Exterior cliffs / crystal curtain','x'),
 @('11A','Evergreen foliage / snowy boughs','xy'),
 @('12B','Frozen lake / sparse snow floes','xy')
)
$previews=@{}
$seams=@()
foreach($role in $roles){
 $id=$role[0];$axis=$role[2]
 $img=[Drawing.Bitmap]::new((Join-Path $out "$id.png"))
 $nx=if($axis -eq 'y'){1}else{3}
 $ny=if($axis -eq 'x'){1}else{3}
 $repeat=[Drawing.Bitmap]::new(($img.Width*$nx),($img.Height*$ny))
 $rg=[Drawing.Graphics]::FromImage($repeat)
 for($y=0;$y -lt $ny;$y++){for($x=0;$x -lt $nx;$x++){$rg.DrawImageUnscaled($img,($x*$img.Width),($y*$img.Height))}}
 $rg.Dispose();$repeat.Save((Join-Path $out "$id-repeat.png"))
 $height=if($img.Height -eq 128){290}elseif($img.Height -eq 256){400}else{620}
 $bmp=[Drawing.Bitmap]::new(1420,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#1a283a'))
 $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString("$id  $($role[1])",$titleFont,$ink,24,10)
 $g.DrawString("Refined albedo / $($img.Width) x $($img.Height)",$font,$muted,24,58)
 $repeatLabel=if($axis -eq 'xy'){'3 x 3 repeat / no randomization'}elseif($axis -eq 'x'){'3 repeats along length'}else{'3 repeats along ramp / width stays complete'}
 $g.DrawString($repeatLabel,$font,$muted,620,58)
 $areaHeight=$height-132
 $scale=[Math]::Min(550.0/$img.Width,$areaHeight/[double]$img.Height)
 $w=[int]($img.Width*$scale);$h=[int]($img.Height*$scale)
 $g.DrawImage($img,[Drawing.Rectangle]::new(24,94,$w,$h))
 $scale=[Math]::Min(772.0/$repeat.Width,$areaHeight/[double]$repeat.Height)
 $w=[int]($repeat.Width*$scale);$h=[int]($repeat.Height*$scale)
 $g.DrawImage($repeat,[Drawing.Rectangle]::new(620,94,$w,$h))
 $g.DrawString('PHASE 2 / AWAITING APPROVAL / NOT IN GAME',$small,$muted,24,($height-26))
 $bmp.Save((Join-Path $out "preview-$id.png"));$g.Dispose()
 $previews[$id]=$bmp
 # A seam jump is compared to the adjacent interior step, not expected to be zero.
 foreach($direction in @('x','y')){
  if(($direction -eq 'x' -and $axis -eq 'y') -or ($direction -eq 'y' -and $axis -eq 'x')){continue}
  $count=if($direction -eq 'x'){$img.Height}else{$img.Width}
  $sum=0.0;$inside=0.0;$maxJump=0
  for($i=0;$i -lt $count;$i++){
   if($direction -eq 'x'){$a=$img.GetPixel(0,$i);$b=$img.GetPixel(($img.Width-1),$i);$c=$img.GetPixel(1,$i);$d=$img.GetPixel(($img.Width-2),$i)}
   else{$a=$img.GetPixel($i,0);$b=$img.GetPixel($i,($img.Height-1));$c=$img.GetPixel($i,1);$d=$img.GetPixel($i,($img.Height-2))}
   foreach($channel in @('R','G','B')){
    $jump=[Math]::Abs([int]$a.$channel-[int]$b.$channel)
    $sum+=$jump;$inside+=([Math]::Abs([int]$a.$channel-[int]$c.$channel)+[Math]::Abs([int]$b.$channel-[int]$d.$channel))/2.0
    $maxJump=[Math]::Max($maxJump,$jump)
   }
  }
  $seams+=[pscustomobject]@{id=$id;axis=$direction;mean_wrap_step=[Math]::Round($sum/($count*3),3);mean_adjacent_step=[Math]::Round($inside/($count*3),3);max_wrap_step=$maxJump}
 }
 $repeat.Dispose();$img.Dispose()
}
$seams | ConvertTo-Json | Set-Content (Join-Path $out 'seam-review.json')
$page=0
foreach($group in @(@('1A','5A','12B'),@('2B','3A','6A'),@('7B','8A','9A'),@('11A'))){
 $page++;$height=80
 foreach($id in $group){$height+=$previews[$id].Height+10}
 $bmp=[Drawing.Bitmap]::new(1420,$height)
 $g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.ColorTranslator]::FromHtml('#111c2b'))
 $g.DrawString('ICE CAP / PHASE 2 / SELECTED TEXTURES',$titleFont,$ink,24,14)
 $y=80
 foreach($id in $group){$g.DrawImageUnscaled($previews[$id],0,$y);$y+=$previews[$id].Height+10}
 $bmp.Save((Join-Path $out "board-$page.png"));$g.Dispose();$bmp.Dispose()
}
foreach($bmp in $previews.Values){$bmp.Dispose()}
$titleFont.Dispose();$font.Dispose();$small.Dispose();$ink.Dispose();$muted.Dispose()
$seams | Format-Table -AutoSize
Write-Output 'Saved selected textures, unrandomized repeats, individual previews and four review boards.'
