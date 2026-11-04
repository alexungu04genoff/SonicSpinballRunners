param([string]$Project = (Split-Path $PSScriptRoot -Parent))
Add-Type -AssemblyName System.Drawing
$source = Join-Path $Project 'test-results/geometry-style'
$output = Join-Path $Project 'docs/geometry-review'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$themes = @('green_hill','chemical_plant','rooftop_run','casino_night','sky_sanctuary','ice_cap','lava_reef','aquarium_park')
$font = [System.Drawing.Font]::new('Segoe UI',18)
foreach ($mode in @('all-themes','gameplay-views','comparison')) {
    $comparison = $mode -eq 'comparison'
    $height = if ($comparison) {1260} else {1650}
    $sheet = [System.Drawing.Bitmap]::new(1320,$height)
    $canvas = [System.Drawing.Graphics]::FromImage($sheet)
    $canvas.Clear([System.Drawing.Color]::FromArgb(17,27,39))
    $canvas.InterpolationMode = 'HighQualityBicubic'
    $title = if ($comparison) {'Old committed art / current canonical art + geometry'} else {'SSR / Canonical art + low-poly geometry / 04 Nov 2026'}
    $canvas.DrawString($title,$font,[System.Drawing.Brushes]::White,20,12)
    $subtitle = if ($comparison) {'Includes material changes; not an isolated density comparison.'} else {'Lockbox / matching camera / source Defaults / HUD hidden / Forward+ Vulkan'}
    $canvas.DrawString($subtitle,$font,[System.Drawing.Brushes]::LightSteelBlue,20,45)
    $items = if ($comparison) {@('green_hill','green_hill','rooftop_run','rooftop_run','sky_sanctuary','sky_sanctuary')} else {$themes}
    for ($i=0; $i -lt $items.Count; $i++) {
        $x=20+($i%2)*650; $y=85+[math]::Floor($i/2)*390
        $label=if($comparison -and $i%2 -eq 0){'before'}else{'modern'}
        $suffix=if($mode -eq 'gameplay-views'){''}else{'-overview'}
        $caption=$items[$i].Replace('_',' ') + ' / ' + $label
        $canvas.DrawString($caption,$font,[System.Drawing.Brushes]::Wheat,$x,$y)
        $image=[System.Drawing.Image]::FromFile((Join-Path $source ($label+'-'+$items[$i]+$suffix+'.png')))
        $rectangle=[System.Drawing.Rectangle]::new($x,($y+34),630,340)
        $canvas.DrawImage($image,$rectangle,0,0,1280,690,[System.Drawing.GraphicsUnit]::Pixel)
        $image.Dispose()
    }
    $sheet.Save((Join-Path $output ($mode+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose(); $sheet.Dispose()
}
$font.Dispose()
