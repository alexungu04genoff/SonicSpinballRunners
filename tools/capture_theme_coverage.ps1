[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [string]$RosterPath='test-results/theme-coverage/roster.json',
 [string[]]$Themes=@()
)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$roster=Get-Content -LiteralPath (Join-Path $project $RosterPath) -Raw | ConvertFrom-Json
if(-not $Themes.Count){$Themes=@($roster.themes)}
if(($Themes | Select-Object -Unique).Count -ne $Themes.Count -or @($Themes | Where-Object {$_ -notin $roster.themes}).Count){throw 'Select unique registered themes.'}
$output=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $output){throw 'Use a new output root to preserve prior evidence.'}
New-Item -ItemType Directory -Path $output | Out-Null
Copy-Item -LiteralPath (Join-Path $project $RosterPath) -Destination (Join-Path $output 'roster.json')
$index=@()
foreach($act in $roster.acts){
 $slug=[IO.Path]::GetFileNameWithoutExtension($act.path).Replace(' ','-').ToLowerInvariant()
 foreach($tier in @('spawn','mid','upper')){
  $destination=Join-Path $output ($slug+'/'+$tier)
  $env:APPDATA=Join-Path $output ('profiles/'+$slug+'-'+$tier)
  $env:LOCALAPPDATA=Join-Path $output ('local-profiles/'+$slug+'-'+$tier)
  New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
  $arguments=@{ActPath=$act.path;SkipBake=$true;OutputDirectory=$destination;Themes=$Themes}
  if($tier -ne 'spawn'){$arguments.CameraTarget=($act.targets.$tier | ForEach-Object {$_.ToString([Globalization.CultureInfo]::InvariantCulture)}) -join ','}
  & (Join-Path $PSScriptRoot 'capture_prototype_appearance.ps1') @arguments
  $manifest=Get-Content -LiteralPath (Join-Path $destination 'manifest.json') -Raw | ConvertFrom-Json
  foreach($capture in $manifest.captures){
   if($capture.source_sha256 -ne $act.source_sha256){throw 'Act changed since roster discovery.'}
   $index+=@{act=$act.title;act_path=$act.path;theme=$capture.theme;tier=$tier;directory=($slug+'/'+$tier);image=$capture.image;fallback_builds=$capture.fallback_builds}
  }
  $index | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'index.json') -Encoding UTF8
 }
}
if($index.Count -ne $roster.acts.Count * $Themes.Count * 3){throw 'Incomplete roster coverage.'}
Write-Output "Complete validated coverage: $($index.Count) views."
