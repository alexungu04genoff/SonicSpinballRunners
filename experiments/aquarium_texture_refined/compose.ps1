Add-Type -AssemblyName System.Drawing
$ErrorActionPreference='Stop'
$out=$PSScriptRoot
$roles=@(
 @('1-from-5A','1 / Original 5A - blue serpentine panels','Two-way repeat; complete framed panels.',4,2),
 @('2A','2A / Gold scroll lacquer','Length repeat; scrolls remain inside the strip.',3,1),
 @('3B','3B / Gold-corner timber','Length repeat; complete panels and continuous vertical boards.',2,1),
 @('4B','4B / Slate ceramic fascia','Length repeat; slate endcaps retained beneath red roofs.',3,1),
 @('5A-red','5A / Red rounded roof tiles','Two-way repeat; six columns and four courses per tile.',4,2),
 @('6A-red','6A / Matching red roof edge','Length repeat; column spacing matches 5A at equal physical width.',3,1),
 @('7B','7B / Stone ramp deck','Length repeat; side strips fit deck width rather than tiling across it.',1,2),
 @('8A','8A / Lacquer and gold clasps','Length repeat; four complete fittings per strip.',3,1),
 @('9A','9A / Ivory lattice facade','Length repeat; two complete facade modules per texture.',2,1)
)
$font=[Drawing.Font]::new('Segoe UI',18,[Drawing.FontStyle]::Bold)
$small=[Drawing.Font]::new('Segoe UI',12)
$white=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#eee9dc'))
$muted=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#a7bdc3'))
$boards=@{}
foreach($role in $roles){
 $id=$role[0];$img=[Drawing.Image]::FromFile((Join-Path $out "$id.png"))
 $repeat=[Drawing.Bitmap]::new([int]($img.Width*$role[3]),[int]($img.Height*$role[4]))
 $rg=[Drawing.Graphics]::FromImage($repeat)
 for($y=0;$y -lt $role[4];$y++){for($x=0;$x -lt $role[3];$x++){$rg.DrawImageUnscaled($img,[int]($x*$img.Width),[int]($y*$img.Height))}}
 $repeat.Save((Join-Path $out "repeat-$id.png"));$rg.Dispose()
 $h=if($img.Width -eq $img.Height){445}elseif($img.Width -eq $img.Height*2){290}else{230}
 $bmp=[Drawing.Bitmap]::new(1200,$h);$g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#1c2a33'))
 $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 $g.DrawString($role[1],$font,$white,20,12)
 $g.DrawString('Single texture',$small,$muted,20,49)
 $g.DrawString("Repeated $($role[3]) x $($role[4])",$small,$muted,400,49)
 $sw=320;$sh=[int](320*$img.Height/$img.Width)
 $g.DrawImage($img,[Drawing.Rectangle]::new(20,78,$sw,$sh))
 $scale=[Math]::Min(760.0/$repeat.Width,($h-125.0)/$repeat.Height)
 $g.DrawImage($repeat,[Drawing.Rectangle]::new(400,78,[int]($repeat.Width*$scale),[int]($repeat.Height*$scale)))
 $g.DrawString($role[2],$small,$muted,20,($h-30))
 $bmp.Save((Join-Path $out "preview-$id.png"));$boards[$id]=$bmp
 $g.Dispose();$img.Dispose();$repeat.Dispose()
}
$page=0
foreach($group in @(@('1-from-5A','2A','3B'),@('4B','5A-red','6A-red'),@('7B','8A','9A'))){
 $page++;$height=65
 foreach($id in $group){$height+=$boards[$id].Height+8}
 $bmp=[Drawing.Bitmap]::new(1200,$height);$g=[Drawing.Graphics]::FromImage($bmp)
 $g.Clear([Drawing.ColorTranslator]::FromHtml('#101b23'))
 $g.DrawString('AQUARIUM PARK / PHASE 2 / SELECTED ALBEDO',$font,$white,20,18)
 $y=65;foreach($id in $group){$g.DrawImageUnscaled($boards[$id],0,$y);$y+=$boards[$id].Height+8}
 $bmp.Save((Join-Path $out "board-$page.png"));$g.Dispose();$bmp.Dispose()
}
$bmp=[Drawing.Bitmap]::new(1200,560);$g=[Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#182832'))
$g.DrawString('13B / Cyan and violet reef clusters',$font,$white,20,15)
$g.DrawString('Existing production coral geometry / isolated albedo material study, not a game capture',$small,$muted,20,53)
$img=[Drawing.Image]::FromFile((Join-Path $out '13B-material-study.png'))
$g.DrawImageUnscaled($img,20,90);$img.Dispose()
$img=[Drawing.Image]::FromFile((Join-Path $out 'repeat-13B.png'))
$g.DrawImage($img,[Drawing.Rectangle]::new(20,350,1152,192));$img.Dispose()
$bmp.Save((Join-Path $out 'board-4.png'));$g.Dispose();$bmp.Dispose()
foreach($bmp in $boards.Values){$bmp.Dispose()}
$font.Dispose();$small.Dispose();$white.Dispose();$muted.Dispose()
Write-Output 'Nine single-texture/repeat pairs and four review boards saved.'
