[CmdletBinding()]
param(
    [switch]$Lab,
    [string]$ProjectRoot = '',
    [string]$GodotPath = '',
    [string]$ResultsRoot = '',
    [int]$MaximumMinutes = 20
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path $PSScriptRoot -Parent }
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not $GodotPath) { $GodotPath = Join-Path $project 'Sonic Spinball Runners.exe' }
if (-not $ResultsRoot) { $ResultsRoot = Join-Path $project 'Results' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$label = if ($Lab) { 'Visual-Lab-' } else { 'Work-Laptop-' }
$output = Join-Path $ResultsRoot ($label + $stamp)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$machine = @{captured_at=(Get-Date).ToString('o');computer=$env:COMPUTERNAME;logical_processors=[Environment]::ProcessorCount}
try {
    $machine.gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM,VideoModeDescription)
    $machine.cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors)
    $machine.windows = @(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,TotalVisibleMemorySize)
} catch { $machine.hardware_query_error = $_.Exception.Message }
[IO.File]::WriteAllText((Join-Path $output 'machine.json'), ($machine | ConvertTo-Json -Depth 5))
$probe = Join-Path $PSScriptRoot 'run_grounding_probe.ps1'
if ($Lab) {
    & $probe -ProjectRoot $project -GodotPath $GodotPath -OutputDirectory (Join-Path $output 'rooftop_run') -Task interactive -Interactive
    Write-Output "Return this folder with the matrix results: $output"
    exit
}
$jobs = @(
    @{name='01-prototype-production';runtime='prototype';quality='production';renderer='forward_plus';detailed=$false},
    @{name='02-endless-production';runtime='endless';quality='production';renderer='forward_plus';detailed=$true},
    @{name='03-endless-shadow-light';runtime='endless';quality='shadow-light';renderer='forward_plus';detailed=$false},
    @{name='04-endless-balanced';runtime='endless';quality='balanced';renderer='forward_plus';detailed=$false},
    @{name='05-endless-balanced-no-retro';runtime='endless';quality='balanced-no-retro';renderer='forward_plus';detailed=$false},
    @{name='06-endless-reduced-retro';runtime='endless';quality='reduced-retro';renderer='forward_plus';detailed=$false},
    @{name='07-endless-mobile-vulkan';runtime='endless';quality='production';renderer='mobile';detailed=$false},
    @{name='08-endless-compatibility-angle';runtime='endless';quality='production';renderer='gl_compatibility';detailed=$false}
)
$results = [Collections.Generic.List[object]]::new()
$clock = [Diagnostics.Stopwatch]::StartNew()
foreach ($job in $jobs) {
    $remaining = [int]($MaximumMinutes * 60 - $clock.Elapsed.TotalSeconds)
    if ($remaining -lt 20) { $results.Add(@{name=$job.name;status='skipped_total_time_limit'}); continue }
    Write-Output ("Running {0} ({1}/{2})" -f $job.name,($results.Count + 1),$jobs.Count)
    try {
        $jobBudget = if ($job.renderer -eq 'gl_compatibility') { 420 } else { 240 }
        & $probe -ProjectRoot $project -GodotPath $GodotPath -OutputDirectory (Join-Path $output $job.name) -Task matrix -Runtime $job.runtime -Quality $job.quality -Renderer $job.renderer -Seconds 2.5 -TimeoutSeconds ([Math]::Min($jobBudget,$remaining)) -Detailed:$job.detailed
        $results.Add(@{name=$job.name;status='complete'})
    } catch {
        $results.Add(@{name=$job.name;status='failed';error=$_.Exception.Message})
        Write-Warning $_.Exception.Message
    }
    [IO.File]::WriteAllText((Join-Path $output 'matrix-status.json'), ($results | ConvertTo-Json -Depth 4))
}
# Include jobs skipped by the total budget, including a fully skipped run.
[IO.File]::WriteAllText((Join-Path $output 'matrix-status.json'), ($results | ConvertTo-Json -Depth 4))
$note = "Finished. Return this entire folder, including failed/partial runs.`r`n" + $output + "`r`n" +
    "The rendering method and GPU actually used are recorded in each report.json and console.log.`r`n" +
    "No player settings, Acts, or bakes were changed. Maximum run budget: $MaximumMinutes minutes.`r`n"
[IO.File]::WriteAllText((Join-Path $output 'RETURN THIS FOLDER.txt'), $note)
Write-Output $note
