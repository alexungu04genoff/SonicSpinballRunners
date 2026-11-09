[CmdletBinding()]
param(
 [string]$CaptureRoot='test-results/theme-coverage',
 [string]$OutputDirectory='docs/theme-identity/coverage-20261109'
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$project=Split-Path $PSScriptRoot -Parent
$source=Join-Path $project $CaptureRoot
$output=Join-Path $project $OutputDirectory
$roster=Get-Content (Join-Path $source 'roster.json') -Raw | ConvertFrom-Json
$changed=@('chemical_plant','ice_cap')
$tiers=@('spawn','mid','upper')
New-Item -ItemType Directory -Force $output | Out-Null
$font=[Drawing.Font]::new('Segoe UI',11)
$receipts=@()
$views=@()
function Folder($act,$tier,$state){
 $slug=[IO.Path]::GetFileNameWithoutExtension($act.path).Replace(' ','-').ToLowerInvariant()
 if($state -eq 'before' -and $slug -eq 'first-try-smooth-decor' -and $tier -eq 'upper'){
  return Join-Path $source 'before-first-upper-corrected'
 }
 return Join-Path $source ($state+'/'+$slug+'/'+$tier)
}
foreach($act in $roster.acts){
 $slug=[IO.Path]::GetFileNameWithoutExtension($act.path).Replace(' ','-').ToLowerInvariant()
 foreach($tier in $tiers){
  foreach($state in @('before','after')){
   $folder=Folder $act $tier $state
   $manifest=Get-Content (Join-Path $folder 'manifest.json') -Raw | ConvertFrom-Json
   if(-not $manifest.complete){throw "Incomplete manifest: $folder"}
   foreach($capture in $manifest.captures){
    if($capture.fallback_builds -ne 0 -or $capture.source_sha256 -ne $act.source_sha256){throw 'Invalid capture authority or changed Act.'}
    $relative='receipts/'+$slug+'/'+$tier+'/'+$state
    $destination=Join-Path $output $relative
    New-Item -ItemType Directory -Force $destination | Out-Null
    if($relative -notin $receipts){
     foreach($name in @('manifest.json','provenance.json','regression.log','regression.err')){
      # Match repository LF policy so receipt hashes survive a fresh checkout.
      $text=[IO.File]::ReadAllText((Join-Path $folder $name)).Replace("`r",'')
      [IO.File]::WriteAllText((Join-Path $destination $name),$text,[Text.UTF8Encoding]::new($false))
     }
     $receipts+=$relative
    }
    $native=$null
    if($capture.theme -in $changed){
     $native='native/'+$slug+'/'+$tier+'/'+$capture.theme+'-'+$state+'.png'
     New-Item -ItemType Directory -Force (Split-Path (Join-Path $output $native)) | Out-Null
     Copy-Item -LiteralPath (Join-Path $folder $capture.image) -Destination (Join-Path $output $native)
    }
    $views+=@{act=$act.title;act_path=$act.path;theme=$capture.theme;tier=$tier;state=$state;native=$native;receipt=$relative+'/manifest.json';raw=(Join-Path $folder $capture.image);sha256=(Get-FileHash (Join-Path $folder $capture.image)).Hash}
   }
  }
 }
}
$expected=$roster.acts.Count * ($roster.themes.Count + $changed.Count) * $tiers.Count
if($views.Count -ne $expected){throw "Expected $expected captures; got $($views.Count)."}
$views | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'index.json') -Encoding UTF8
Copy-Item (Join-Path $source 'roster.json') (Join-Path $output 'roster.json')
function ImagePath($act,$theme,$tier,$state){
 if($state -eq 'after' -and $theme -notin $changed){$state='before'}
 return Join-Path (Folder $act $tier $state) ($theme+'.png')
}
function Draw($g,$path,$x,$y,$w,$h,$mask=$false){
 $im=[Drawing.Bitmap]::new($path)
 try{
  if($mask){
   $edit=[Drawing.Graphics]::FromImage($im)
   try{$edit.FillRectangle([Drawing.Brushes]::Black,0,0,470,240)}finally{$edit.Dispose()}
  }
  $g.DrawImage($im,[int]$x,[int]$y,[int]$w,[int]$h)
 }finally{$im.Dispose()}
}
foreach($tier in $tiers){
 foreach($state in @('before','after')){
  $sheet=[Drawing.Bitmap]::new(($roster.acts.Count*384),($roster.themes.Count*291))
  $g=[Drawing.Graphics]::FromImage($sheet)
  try{
   $g.Clear([Drawing.Color]::FromArgb(12,20,32))
   for($r=0;$r -lt $roster.themes.Count;$r++){
    for($c=0;$c -lt $roster.acts.Count;$c++){
     $act=$roster.acts[$c];$theme=$roster.themes[$r]
     $g.DrawString(($theme+' / '+$act.title),$font,[Drawing.Brushes]::White,($c*384),($r*291))
     Draw $g (ImagePath $act $theme $tier $state) ($c*384) ($r*291+24) 384 267
    }
   }
   $sheet.Save((Join-Path $output ($tier+'-'+$state+'.png')))
  }finally{$g.Dispose();$sheet.Dispose()}
 }
 # Changed themes: before/after pairs, five Acts each, at 50% resolution.
 $sheet=[Drawing.Bitmap]::new(1440,($changed.Count*$roster.acts.Count*524))
 $g=[Drawing.Graphics]::FromImage($sheet)
 try{
  $g.Clear([Drawing.Color]::FromArgb(12,20,32));$r=0
  foreach($theme in $changed){foreach($act in $roster.acts){
   $c=0
   foreach($state in @('before','after')){
    $g.DrawString(($theme+' / '+$act.title+' / '+$state),$font,[Drawing.Brushes]::White,($c*720),($r*524))
    Draw $g (ImagePath $act $theme $tier $state) ($c*720) ($r*524+24) 720 500
    $c++
   }
   $r++
  }}
  $sheet.Save((Join-Path $output ($tier+'-comparison.png')))
 }finally{$g.Dispose();$sheet.Dispose()}
}
# No labels: theme rows; within each Act, spawn/mid/upper columns. HUD masked
# only in diagnostic copies, never in the native evidence.
foreach($state in @('before','after')){
 $sheet=[Drawing.Bitmap]::new(($roster.acts.Count*$tiers.Count*192),($roster.themes.Count*133))
 $g=[Drawing.Graphics]::FromImage($sheet)
 try{
  for($r=0;$r -lt $roster.themes.Count;$r++){
   $c=0
   foreach($act in $roster.acts){foreach($tier in $tiers){
    Draw $g (ImagePath $act $roster.themes[$r] $tier $state) ($c*192) ($r*133) 192 133 $true
    $c++
   }}
  }
  $sheet.Save((Join-Path $output ('label-free-'+$state+'.png')))
 }finally{$g.Dispose();$sheet.Dispose()}
}
# Native-pixel detail strips expose far motifs in the weakest reference Act.
foreach($theme in $changed){
 $reference=$roster.acts | Where-Object {$_.title -eq 'RampMania'} | Select-Object -First 1
 if(-not $reference){throw 'Select a current weak reference Act for detail crops.'}
 $sheet=[Drawing.Bitmap]::new(940,460)
 $g=[Drawing.Graphics]::FromImage($sheet)
 try{
  $r=0
  foreach($state in @('before','after')){
   $im=[Drawing.Image]::FromFile((ImagePath $reference $theme 'upper' $state))
   try{$g.DrawImage($im,[Drawing.Rectangle]::new(0,$r*230,940,230),[Drawing.Rectangle]::new(480,0,940,230),[Drawing.GraphicsUnit]::Pixel)}finally{$im.Dispose()}
   $r++
  }
  $sheet.Save((Join-Path $output ($theme+'-detail.png')))
 }finally{$g.Dispose();$sheet.Dispose()}
}
$font.Dispose()
Write-Output "Exported $($views.Count) capture records, native changed-theme frames, comparison sheets and diagnostic thumbnails."
