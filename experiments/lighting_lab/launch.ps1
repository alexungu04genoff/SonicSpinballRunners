[CmdletBinding()]
param(
    [string]$GodotPath,
    [ValidateSet('Forward', 'Mobile', 'Angle')]
    [string]$Renderer = 'Forward',
    [ValidateSet('green_hill', 'chemical_plant', 'rooftop_run', 'casino_night', 'sky_sanctuary', 'ice_cap', 'lava_reef', 'aquarium_park')]
    [string]$Theme = 'green_hill',
    [string]$Act = 'res://data/acts/Authored/First Try Smooth Decor.tres'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'),
        (Join-Path $env:ProgramFiles 'Godot\Godot.exe'),
        (Join-Path $repoRoot 'test-results\performance-pass2\engine\Godot_console.exe')
    )
    foreach ($name in @('godot4.exe', 'godot.exe', 'godot')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $candidates += $command.Source }
    }
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot was not found. Use -GodotPath with the full path to your Godot 4 executable.'
}
$method = @{ Forward = 'forward_plus'; Mobile = 'mobile'; Angle = 'gl_compatibility' }[$Renderer]
$driver = if ($Renderer -eq 'Angle') { 'opengl3_angle' } else { 'vulkan' }
$logDirectory = Join-Path $repoRoot '.godot'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$arguments = @('--path', $repoRoot, '--rendering-method', $method, '--rendering-driver', $driver,
    '--log-file', (Join-Path $logDirectory "lighting-lab-$Renderer.log"),
    'res://experiments/lighting_lab/lighting_lab.tscn', '--', "--theme=$Theme", '--act', $Act)
Write-Host "Lighting Lab: $Renderer / $Theme. Wheel zoom; middle-drag pan; F6 controls."
# Interactive window requested by the user; wait for GUI and console executables alike.
$quoted = $arguments | ForEach-Object { '"{0}"' -f $_ }
$process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Lighting Lab exited with code $($process.ExitCode). See .godot\lighting-lab-$Renderer.log." }
