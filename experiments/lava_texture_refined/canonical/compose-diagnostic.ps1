Add-Type -AssemblyName System.Drawing
$ErrorActionPreference='Stop'
$bitmap=[Drawing.Bitmap]::new(2880,1060)
$g=[Drawing.Graphics]::FromImage($bitmap)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#17171b'))
$font=[Drawing.Font]::new('Segoe UI',22,[Drawing.FontStyle]::Bold)
$ink=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1e5ce'))
$g.DrawString('NORMAL ONLY: 0.85',$font,$ink,24,12)
$g.DrawString('DIAGNOSTIC: 6.0 / GEOMETRY OFF',$font,$ink,1464,12)
for($i=0;$i -lt 2;$i++){
 $name=if($i -eq 0){'normal-only.png'}else{'normal-extreme.png'}
 $source=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot $name))
 $g.DrawImageUnscaled($source,$i*1440,60)
 $source.Dispose()
}
$bitmap.Save((Join-Path $PSScriptRoot 'normal-diagnostic-comparison.png'))
$g.Dispose();$bitmap.Dispose();$font.Dispose();$ink.Dispose()
