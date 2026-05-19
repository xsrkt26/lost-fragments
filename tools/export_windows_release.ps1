param(
    [string]$GodotBin = "",
    [string]$Preset = "Windows Desktop",
    [string]$OutputDir = "package",
    [string]$ProductName = "LostFragments",
    [string]$Version = "",
    [string]$PythonBin = "",
    [switch]$SkipPrecheck,
    [switch]$PrecheckOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$defaultGodotPath = "D:\COde\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { $defaultGodotPath }
}

if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot executable not found: $GodotBin"
}
if ([string]::IsNullOrWhiteSpace($PythonBin)) {
    $PythonBin = if ($env:PYTHON_BIN) { $env:PYTHON_BIN } else { "python" }
}

$exportPresetsPath = Join-Path $repoRoot "export_presets.cfg"
$presetPattern = 'name="' + [regex]::Escape($Preset) + '"'
if (-not (Test-Path -LiteralPath $exportPresetsPath)) {
    throw "export_presets.cfg not found."
}
if ((Get-Content -LiteralPath $exportPresetsPath -Raw) -notmatch $presetPattern) {
    throw "Export preset not found: $Preset"
}

function Invoke-RepoCommand {
    param(
        [string]$Name,
        [string]$CommandText,
        [scriptblock]$Command
    )

    Write-Host "RELEASE_STEP: $Name"
    $started = Get-Date
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command 2>&1 | ForEach-Object { Write-Host $_ }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    $finished = Get-Date
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }
    return [ordered]@{
        name = $Name
        command = $CommandText
        status = "passed"
        started_at_utc = $started.ToUniversalTime().ToString("o")
        finished_at_utc = $finished.ToUniversalTime().ToString("o")
    }
}

function Get-GitValue {
    param([string[]]$GitArgs, [string]$Fallback)
    try {
        $value = & git -C $repoRoot @GitArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
            return ($value | Select-Object -First 1).Trim()
        }
    } catch {
    }
    return $Fallback
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-GitValue -GitArgs @("describe", "--tags", "--dirty", "--always") -Fallback "0.0.0-local"
}

$commit = Get-GitValue -GitArgs @("rev-parse", "HEAD") -Fallback "unknown"
$commitShort = Get-GitValue -GitArgs @("rev-parse", "--short", "HEAD") -Fallback "unknown"
$branch = Get-GitValue -GitArgs @("branch", "--show-current") -Fallback "unknown"
$buildTimeUtc = (Get-Date).ToUniversalTime()
$timestamp = $buildTimeUtc.ToString("yyyyMMdd-HHmmss")
$packageDir = Join-Path $repoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

$artifactBase = "$ProductName-$timestamp-$commitShort"
$outputPath = Join-Path $packageDir "$artifactBase.exe"
$manifestPath = Join-Path $packageDir "$artifactBase.manifest.json"

$results = @()
if (-not $SkipPrecheck) {
    $results += Invoke-RepoCommand `
        -Name "gut" `
        -CommandText ".\tools\run_tests_silent.ps1" `
        -Command { & (Join-Path $repoRoot "tools\run_tests_silent.ps1") }

    $results += Invoke-RepoCommand `
        -Name "strict_scene_smoke" `
        -CommandText "$PythonBin -B scripts\run_scene_smoke_tests.py --fail-on-engine-error" `
        -Command { & $PythonBin -B (Join-Path $repoRoot "scripts\run_scene_smoke_tests.py") --fail-on-engine-error }
} else {
    $results += [ordered]@{
        name = "external_precheck"
        command = "GitHub Actions release workflow"
        status = "skipped_in_script"
        started_at_utc = $buildTimeUtc.ToString("o")
        finished_at_utc = $buildTimeUtc.ToString("o")
    }
}

$exportStatus = "skipped"
if (-not $PrecheckOnly) {
    $exportArgs = @("--headless", "--path", $repoRoot, "--export-release", $Preset, $outputPath)
    $results += Invoke-RepoCommand `
        -Name "godot_export" `
        -CommandText "$GodotBin $($exportArgs -join ' ')" `
        -Command { & $GodotBin @exportArgs }
    $exportStatus = "passed"
}

$manifest = [ordered]@{
    product = "Lost Fragments"
    version = $Version
    preset = $Preset
    branch = $branch
    commit = $commit
    commit_short = $commitShort
    build_time_utc = $buildTimeUtc.ToString("o")
    precheck_only = [bool]$PrecheckOnly
    export_status = $exportStatus
    output_path = $outputPath
    manifest_path = $manifestPath
    test_results = $results
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "RELEASE_MANIFEST: $manifestPath"
if ($PrecheckOnly) {
    Write-Host "RELEASE_RESULTS: PASS (precheck only)"
} else {
    Write-Host "RELEASE_RESULTS: PASS"
    Write-Host "RELEASE_ARTIFACT: $outputPath"
}
