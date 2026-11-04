[CmdletBinding()]
param(
    [ValidateSet('opaque', 'legacy', 'off')][string]$Effect = 'opaque',
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Pass -GodotPath with the Godot 4 executable.' }
Write-Host "Buzz death diagnostic: $Effect. Two automatic physical kills; JSON path appears below."
$logDirectory = Join-Path $projectRoot 'test-results'
[IO.Directory]::CreateDirectory($logDirectory) | Out-Null
$outputLog = Join-Path $logDirectory "buzz-diagnostic-$Effect.log"
$errorLog = Join-Path $logDirectory "buzz-diagnostic-$Effect-errors.log"
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--script', 'res://tests/buzz_death_profile.gd', '--', "--buzz-death-effect=$Effect", '--buzz-profile')
# Explicitly invoked diagnostic: show the game so the laptop test is observable.
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru -RedirectStandardOutput $outputLog -RedirectStandardError $errorLog
Select-String -LiteralPath $outputLog -Pattern 'BUZZ_DEATH_' | ForEach-Object { Write-Host $_.Line }
if ($process.ExitCode -ne 0) {
    Get-Content -LiteralPath $errorLog -Tail 30
    throw "Buzz diagnostic failed ($($process.ExitCode)); see $outputLog and $errorLog."
}
