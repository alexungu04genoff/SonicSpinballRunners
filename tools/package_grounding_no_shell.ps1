[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$FrozenZip,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [string]$Compiler = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
)
# Build-machine tooling only. Neither delivered launcher invokes these scripts.
$ErrorActionPreference = 'Stop'
$archivePath = (Resolve-Path -LiteralPath $FrozenZip).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) {throw 'Choose a new output directory.'}
if (Test-Path -LiteralPath ($output+'.zip')) {throw 'Choose a new archive path.'}
$originalHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($originalHash -ne '84C18A4D1BC193374AD3084E2804457D1727228C3D6FB7721A39D9A8C22FE707') {throw 'This launcher is qualified only for the original final Thursday ZIP.'}
New-Item -ItemType Directory -Path (Join-Path $output 'Frozen Payload') | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$files = [Collections.Generic.List[object]]::new()
$omitted = [Collections.Generic.List[string]]::new()
try {
 foreach ($entry in $archive.Entries) {
  if (-not $entry.Name) {continue}
  $relative = $entry.FullName.Substring($entry.FullName.IndexOf('/')+1)
  # Preserve the complete frozen engine/project payload. Shell launchers and
  # build-time tools are unnecessary in the direct-EXE delivery.
  if ($relative -match '(?i)\.(cmd|bat|ps1)$|^tools/') {$omitted.Add($relative); continue}
  $destination = [IO.Path]::GetFullPath((Join-Path (Join-Path $output 'Frozen Payload') $relative))
  if (-not $destination.StartsWith((Join-Path $output 'Frozen Payload')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Unsafe archive path.'}
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$false)
  $files.Add(@{path=$relative;bytes=$entry.Length;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash})
 }
} finally {$archive.Dispose()}
$manifest = @{original_zip=(Split-Path $archivePath -Leaf);original_zip_sha256=$originalHash;files=$files;omitted_shell_and_build_tools=$omitted;policy='Frozen payload bytes are unchanged. Only launcher orchestration is replaced. Runtime copies, profiles, caches and results stay under Results.'}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'payload-manifest.json') -Encoding utf8
$source = Join-Path $PSScriptRoot 'no_shell_grounding\Launcher.cs'
$appManifest = Join-Path $PSScriptRoot 'no_shell_grounding\app.manifest'
foreach ($mode in @('Matrix','Lab')) {
 $name = if ($mode -eq 'Lab') {'Visual Grounding Lab.exe'} else {'Run Work Laptop Matrix.exe'}
 $arguments = @('/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+(Join-Path $output $name)),('/win32manifest:'+$appManifest),'/reference:System.dll','/reference:System.Core.dll','/reference:System.Drawing.dll','/reference:System.Windows.Forms.dll','/reference:System.Web.Extensions.dll','/reference:System.Management.dll')
 if ($mode -eq 'Lab') {$arguments += '/define:LAB'}
 & $Compiler @arguments $source
 if ($LASTEXITCODE -ne 0) {throw "Compilation failed: $mode"}
}
@'
# Thursday diagnostics: direct EXE edition

Extract the entire ZIP to a writable local folder. Double-click **Run Work Laptop
Matrix.exe**, then **Visual Grounding Lab.exe**. Keep **Frozen Payload** beside
both launchers. No CMD, PowerShell, installation, administrator access, registry
changes or policy bypass is used. The small launchers use Windows .NET Framework
4.x; they do not download or install any runtime.

Close other Godot/editor/game diagnostics first. The matrix retains all eight
frozen cases, their exact settings and sample durations, the 240/420-second case
limits, and the 20-minute overall budget. Renderer failures remain failures and
their partial logs are retained. Do not run both launchers at the same time.

All generated files, including a verified working copy, profiles and caches, stay
in **Results** beside these EXEs. Return the **Work-Laptop-...** and **Visual-Lab-...**
folders. **Results/Runtime** is a disposable copy of the frozen payload;
**Results/diagnostic-user** holds the shared diagnostic cache. Neither is personal
game data. The original frozen ZIP is not rebuilt or modified.

The Lab keeps its original F1–F10 controls. F9 captures measurements. Close the
Lab normally to write its final report. The launchers use the second monitor
when one is connected, and the primary display on a single-screen laptop.

Payload hashes come directly from the original final Thursday ZIP. Each launch
verifies every delivered payload file and prepares matching runtime copies.
The test code, Godot binary, assets, source, bakes and build manifests are unchanged.
'@ | Set-Content -LiteralPath (Join-Path $output 'Read me.md') -Encoding utf8
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $originalHash) {throw 'Original archive changed during packaging.'}
[IO.Compression.ZipFile]::CreateFromDirectory($output,$output+'.zip',[IO.Compression.CompressionLevel]::Optimal,$false)
@{zip=$output+'.zip';bytes=(Get-Item -LiteralPath ($output+'.zip')).Length;sha256=(Get-FileHash -LiteralPath ($output+'.zip') -Algorithm SHA256).Hash;original_sha256=$originalHash;payload_files=$files.Count;omitted=$omitted.Count} | ConvertTo-Json
