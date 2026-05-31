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
function Resolve-GodotBin {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return $ExplicitPath
    }
    if ($env:GODOT_BIN) {
        return $env:GODOT_BIN
    }

    foreach ($name in @("godot", "godot4", "Godot_v4.6.2-stable_win64_console.exe")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    foreach ($path in @(
        "D:\Library\Software\Installers\DevTools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe",
        "D:\Workspaces\Code\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe",
        "D:\COde\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
    )) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    throw "Godot executable not found. Set GODOT_BIN, pass -GodotBin, or add Godot to PATH."
}

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = Resolve-GodotBin -ExplicitPath $GodotBin
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

function Test-IsWindowsHost {
    if (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) {
        return [bool]$IsWindows
    }
    return $env:OS -eq "Windows_NT"
}

function Set-ChildProcessErrorMode {
    if (-not (Test-IsWindowsHost)) {
        return
    }
    if (-not ("GodotReleaseNativeMethods" -as [type])) {
        Add-Type @"
using System.Runtime.InteropServices;

public static class GodotReleaseNativeMethods {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint uMode);
}
"@
    }
    $semFailCriticalErrors = 0x0001
    $semNoGpFaultErrorBox = 0x0002
    $semNoOpenFileErrorBox = 0x8000
    [void][GodotReleaseNativeMethods]::SetErrorMode($semFailCriticalErrors -bor $semNoGpFaultErrorBox -bor $semNoOpenFileErrorBox)
}

Set-ChildProcessErrorMode

function Initialize-IsolatedGodotAppData {
    param(
        [string]$IsolatedAppData,
        [string]$OriginalAppData
    )

    if (-not (Test-IsWindowsHost)) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($OriginalAppData)) {
        return
    }

    $sourceTemplates = Join-Path $OriginalAppData "Godot\export_templates"
    if (-not (Test-Path -LiteralPath $sourceTemplates)) {
        return
    }

    $isolatedGodotDir = Join-Path $IsolatedAppData "Godot"
    $destTemplates = Join-Path $isolatedGodotDir "export_templates"
    New-Item -ItemType Directory -Force -Path $isolatedGodotDir | Out-Null
    if (Test-Path -LiteralPath $destTemplates) {
        return
    }

    try {
        New-Item -ItemType Junction -Path $destTemplates -Target $sourceTemplates -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item -LiteralPath $sourceTemplates -Destination $destTemplates -Recurse -Force
    }
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
        & $Command 2>&1 | ForEach-Object {
            $line = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception.Message
            } else {
                [string]$_
            }
            if (-not [string]::IsNullOrEmpty($line)) {
                Write-Host $line
            }
        }
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
$originalAppData = $env:APPDATA
$godotAppData = Join-Path ([System.IO.Path]::GetTempPath()) ("go_dot_game_release_appdata_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $godotAppData | Out-Null
Initialize-IsolatedGodotAppData -IsolatedAppData $godotAppData -OriginalAppData $originalAppData

$artifactBase = "$ProductName-$timestamp-$commitShort"
$outputPath = Join-Path $packageDir "$artifactBase.exe"
$manifestPath = Join-Path $packageDir "$artifactBase.manifest.json"

$results = @()
if (-not $SkipPrecheck) {
    $results += Invoke-RepoCommand `
        -Name "gut" `
        -CommandText ".\tools\run_tests_silent.ps1" `
        -Command {
            $previousGodotBin = $env:GODOT_BIN
            try {
                $env:GODOT_BIN = $GodotBin
                & (Join-Path $repoRoot "tools\run_tests_silent.ps1")
            } finally {
                $env:GODOT_BIN = $previousGodotBin
            }
        }

    $results += Invoke-RepoCommand `
        -Name "python_tool_tests" `
        -CommandText "$PythonBin -m unittest discover -s test/tools -p test_*.py" `
        -Command { & $PythonBin -m unittest discover -s (Join-Path $repoRoot "test/tools") -p "test_*.py" }

    $results += Invoke-RepoCommand `
        -Name "strict_scene_smoke" `
        -CommandText "$PythonBin -B scripts\run_scene_smoke_tests.py --godot-bin $GodotBin --fail-on-engine-error --fail-on-engine-warning" `
        -Command { & $PythonBin -B (Join-Path $repoRoot "scripts\run_scene_smoke_tests.py") --godot-bin $GodotBin --fail-on-engine-error --fail-on-engine-warning }
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
    $exportArgs = @("--headless", "--rendering-driver", "opengl3", "--path", $repoRoot, "--export-release", $Preset, $outputPath)
    $results += Invoke-RepoCommand `
        -Name "godot_export" `
        -CommandText "$GodotBin $($exportArgs -join ' ')" `
        -Command {
            $previousAppData = $env:APPDATA
            try {
                $env:APPDATA = $godotAppData
                & $GodotBin @exportArgs
            } finally {
                $env:APPDATA = $previousAppData
            }
        }
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
