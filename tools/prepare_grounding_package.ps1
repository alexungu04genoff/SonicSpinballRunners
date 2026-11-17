[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$GodotPath = 'C:\Program Files\Godot\Godot.exe'
)
# Build-machine step only. The Thursday launchers never call a baker.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$freshness = Join-Path $project 'grounding-freshness.json'
if (-not (Test-Path -LiteralPath $freshness)) { throw 'Run tests/grounding_bake_check.gd first.' }
$pending = (Get-Content -LiteralPath $freshness -Raw | ConvertFrom-Json).stale
$savedAppData = $env:APPDATA
$env:APPDATA = Join-Path $project 'build-user'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
try {
    foreach ($group in ($pending | Group-Object theme)) {
        $arguments = @('--headless','--path',('"' + $project + '"'),'res://scenes/act_baker.tscn','--',('--theme=' + $group.Name),'--quit-after-bake')
        foreach ($path in ($group.Group.act | Select-Object -Unique)) { $arguments += ('"--act=' + $path + '"') }
        $log = Join-Path $project ('bake-' + $group.Name)
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($log + '.log') -RedirectStandardError ($log + '-errors.log')
        if (-not $process.WaitForExit(600000)) { $process.Kill(); throw ('Bake timed out: ' + $group.Name) }
        if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath ($log + '-errors.log') -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet)) { throw ('Bake failed: ' + $group.Name) }
        Write-Output ('PREPARED | ' + $group.Name)
    }
} finally { $env:APPDATA = $savedAppData }
