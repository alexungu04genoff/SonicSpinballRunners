[CmdletBinding()]
param([switch]$Crt, [switch]$Fullscreen)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$engine = Join-Path $env:ProgramFiles 'Godot\Godot.exe'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    $engine = (Get-Command godot -CommandType Application -ErrorAction Stop).Source
}

Add-Type -AssemblyName System.Windows.Forms
$screens = [System.Windows.Forms.Screen]::AllScreens
$display = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $display) { $display = [System.Windows.Forms.Screen]::PrimaryScreen }
$desktop = [System.Windows.Forms.SystemInformation]::VirtualScreen
$position = '{0},{1}' -f ($display.WorkingArea.Left - $desktop.Left + 16), ($display.WorkingArea.Top - $desktop.Top + 36)
$screenIndex = [array]::IndexOf($screens, $display)
$arguments = @('--path', '.', '--screen', $screenIndex)
if ($Fullscreen) { $arguments += '--fullscreen' } else { $arguments += @('--position', $position) }
$arguments += @('--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan',
    '--log-file', ".godot/sage-lab-$PID.log", 'res://experiments/visual_lab/sage/lab.tscn')
if ($Crt) { $arguments += @('--', '--sage-crt') }
Start-Process -FilePath $engine -WorkingDirectory $project -ArgumentList $arguments
