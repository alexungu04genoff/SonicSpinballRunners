[CmdletBinding()]
param(
    [string]$GodotPath,
    [string]$ActPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:ProgramFiles 'Godot\Godot.exe'
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        $command = Get-Command godot4.exe, godot.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $GodotPath = $command.Source }
    }
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot 4 was not found. Pass -GodotPath with the full executable path.'
}

# Specialist geometry/lifecycle diagnostic only; use Prototype for appearance and play.
# Forward+/Vulkan matches the project's Windows rendering backend.
$arguments = @('--path', ('"{0}"' -f $projectRoot), '--rendering-method', 'forward_plus',
    '--rendering-driver', 'vulkan', 'res://scenes/authored_act_playtest.tscn')
if ($ActPath) {
    $resolvedActPath = if ($ActPath.StartsWith('res://')) {
        [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ActPath.Substring(6)))
    } else {
        [System.IO.Path]::GetFullPath($ActPath)
    }
    if (-not (Test-Path -LiteralPath $resolvedActPath -PathType Leaf) -or
        [System.IO.Path]::GetExtension($resolvedActPath) -ne '.tres') {
        throw 'ActPath must identify an existing Act .tres file.'
    }
    $arguments += @('--', '--act', ('"{0}"' -f $resolvedActPath))
}

# The visible window is the interactive playtest explicitly requested by this launcher.
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Authored Act Playtest exited with code $($process.ExitCode)."
}
