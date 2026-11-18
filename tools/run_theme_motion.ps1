[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe',
    [string]$OutputDirectory = '',
    [string[]]$Themes = @('green_hill','chemical_plant','rooftop_run','casino_night','sky_sanctuary','ice_cap','aquarium_park'),
    [switch]$Capture,
    [switch]$Bake,
    [switch]$BenchmarkOnly,
    [switch]$Diagnostics,
    [switch]$SideLight,
    [ValidateSet('normal','wide','close')][string]$Camera = 'normal',
    [ValidateSet('spawn','mid','right','left')][string]$Focus = 'spawn',
    [ValidateSet('production','n64','off')][string]$Retro = 'production',
    [string]$Variant = 'default',
    [ValidateSet('C','A','B')][string[]]$States = @('C','A','B'),
    [ValidateSet('FULL','SIGNATURE','STATIC','NATIVE')][string]$Tier = 'FULL'
)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$allowed = @('green_hill','chemical_plant','rooftop_run','casino_night','sky_sanctuary','ice_cap','aquarium_park')
if (-not $Themes.Count -or @($Themes | Where-Object { $_ -notin $allowed }).Count) { throw 'Select only the seven included Motion Lab themes.' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $project ('test-results\theme-motion\' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh output directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
Add-Type -AssemblyName System.Windows.Forms
$secondary = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary }) | Select-Object -First 1
if (-not $secondary) { throw 'Monitor 2 is unavailable. Connect it before launching this review.' }
$position = '{0},{1}' -f ($secondary.Bounds.X + 20), ($secondary.Bounds.Y + 30)
function Invoke-ReviewGodot([string]$Label, [string[]]$Arguments) {
    $log = Join-Path $output ($Label + '.log')
    $errors = Join-Path $output ($Label + '.err')
    $process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -WorkingDirectory $project -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
    $handle = $process.Handle
    while (-not $process.WaitForExit(500)) {
        if (Select-String -LiteralPath $errors -Pattern 'SCRIPT ERROR:' -Quiet) { $process.Kill(); $process.WaitForExit(); throw "Script error: $errors" }
    }
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $errors -Pattern '^ERROR:' -Quiet)) { throw "Godot failed: $Label. See $log and $errors" }
}
$common = @('--path',('"' + $project + '"'))
if ($Bake) {
    foreach ($theme in $Themes) {
        Invoke-ReviewGodot ('bake-' + $theme) ($common + @('--headless','res://scenes/act_baker.tscn','--','"--act=res://data/acts/Authored/First Try Smooth Decor.tres"',('--theme=' + $theme)))
    }
}
$arguments = $common + @('--position',$position,'--rendering-method','forward_plus','--rendering-driver','vulkan','res://scenes/environmental_motion_lab.tscn','--','--retro=production',('--theme=' + $Themes[0]),('--themes=' + ($Themes -join ',')),('--states=' + ($States -join ',')),('--motion-camera=' + $Camera),('--motion-focus=' + $Focus),('--motion-retro=' + $Retro),('--motion-tier=' + $Tier),('--motion-variant=' + $Variant),('"--output=' + $output + '"'))
if ($Capture -or $BenchmarkOnly) { $arguments += '--motion-capture' }
if ($BenchmarkOnly) { $arguments += '--benchmark-only' }
if ($Diagnostics) { $arguments += '--motion-diagnostics' }
if ($SideLight) { $arguments += '--motion-side-light' }
Invoke-ReviewGodot 'lab' $arguments
if ($Capture -and -not $BenchmarkOnly) {
    & python (Join-Path $PSScriptRoot 'theme_motion_media.py') $output
    if ($LASTEXITCODE -ne 0) { throw 'Media encoding failed; raw frames and receipts remain available.' }
}
Write-Output ('THEME_MOTION_REVIEW | ' + $output)
