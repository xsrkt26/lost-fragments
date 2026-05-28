# Silent GUT Test Runner for AI Agents
# Usage: .\tools\run_tests_silent.ps1

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
function Resolve-GodotBin {
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

    throw "Godot executable not found. Set GODOT_BIN or add Godot to PATH."
}

$godotPath = Resolve-GodotBin
$gutScript = "addons/gut/gut_cmdln.gd"
$timeoutSeconds = 60

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
    if (-not ("GodotTestNativeMethods" -as [type])) {
        Add-Type @"
using System.Runtime.InteropServices;

public static class GodotTestNativeMethods {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint uMode);
}
"@
    }
    $semFailCriticalErrors = 0x0001
    $semNoGpFaultErrorBox = 0x0002
    $semNoOpenFileErrorBox = 0x8000
    [void][GodotTestNativeMethods]::SetErrorMode($semFailCriticalErrors -bor $semNoGpFaultErrorBox -bor $semNoOpenFileErrorBox)
}

Set-ChildProcessErrorMode

# Run Godot and capture BOTH output and errors to temporary files
$tempRoot = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
$tempImportLog = Join-Path $tempRoot "go_dot_game_gut_import_stdout.tmp"
$tempImportErr = Join-Path $tempRoot "go_dot_game_gut_import_stderr.tmp"
$tempLog = Join-Path $tempRoot "go_dot_game_gut_stdout.tmp"
$tempErr = Join-Path $tempRoot "go_dot_game_gut_stderr.tmp"
$godotAppData = Join-Path $tempRoot ("go_dot_game_gut_appdata_" + [System.Guid]::NewGuid().ToString("N"))
$originalAppData = $env:APPDATA
New-Item -ItemType Directory -Force -Path $godotAppData | Out-Null

# Clean up old logs
if (Test-Path $tempImportLog) { Remove-Item $tempImportLog }
if (Test-Path $tempImportErr) { Remove-Item $tempImportErr }
if (Test-Path $tempLog) { Remove-Item $tempLog }
if (Test-Path $tempErr) { Remove-Item $tempErr }

try {
    $env:APPDATA = $godotAppData
    $importArgs = @{
        FilePath = $godotPath
        ArgumentList = @("--headless", "--rendering-driver", "opengl3", "--editor", "--quit", "--path", $repoRoot)
        PassThru = $true
        RedirectStandardOutput = $tempImportLog
        RedirectStandardError = $tempImportErr
    }
    if (Test-IsWindowsHost) {
        $importArgs["WindowStyle"] = "Hidden"
    }
    $importProcess = Start-Process @importArgs
    if (-not $importProcess.WaitForExit($timeoutSeconds * 1000)) {
        Stop-Process -Id $importProcess.Id -Force
        $env:APPDATA = $originalAppData
        Write-Host "TEST_RESULTS: FAIL"
        Write-Host "GODOT_IMPORT_TIMEOUT: reached after $timeoutSeconds seconds"
        exit 1
    }
    $importProcess.Refresh()
    if ($null -ne $importProcess.ExitCode -and $importProcess.ExitCode -ne 0) {
        $env:APPDATA = $originalAppData
        Write-Host "TEST_RESULTS: FAIL"
        Write-Host "GODOT_IMPORT_FAILED: Process exit code $($importProcess.ExitCode)"
        $importOutput = @()
        if (Test-Path $tempImportLog) { $importOutput += Get-Content $tempImportLog }
        if (Test-Path $tempImportErr) { $importOutput += Get-Content $tempImportErr }
        $sample = $importOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 12
        if ($sample.Count -gt 0) {
            Write-Host "IMPORT_OUTPUT_SAMPLE:"
            foreach ($line in $sample) {
                Write-Host "  $line"
            }
        }
        exit 1
    }
    if (Test-Path $tempImportLog) { Remove-Item $tempImportLog }
    if (Test-Path $tempImportErr) { Remove-Item $tempImportErr }

    $startArgs = @{
        FilePath = $godotPath
        ArgumentList = @("--headless", "--rendering-driver", "opengl3", "--path", $repoRoot, "-s", $gutScript, "-gexit", "-glog=0")
        PassThru = $true
        RedirectStandardOutput = $tempLog
        RedirectStandardError = $tempErr
    }
    if (Test-IsWindowsHost) {
        $startArgs["WindowStyle"] = "Hidden"
    }
    $process = Start-Process @startArgs
}
catch {
    $env:APPDATA = $originalAppData
    Write-Host "TEST_RESULTS: FAIL"
    Write-Host "GODOT_START_FAILED: $($_.Exception.Message)"
    exit 1
}

# Wait for process with timeout
$timeoutReached = $false
$timer = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $process.HasExited) {
    if ($timer.Elapsed.TotalSeconds -gt $timeoutSeconds) {
        $timeoutReached = $true
        Stop-Process -Id $process.Id -Force
        break
    }
    Start-Sleep -Milliseconds 500
}
$timer.Stop()
$process.Refresh()
$exitCode = $process.ExitCode
$env:APPDATA = $originalAppData

if ($timeoutReached) {
    Write-Host "TEST_RESULTS: FAIL (TIMEOUT reached after $timeoutSeconds seconds)"
    exit 1
}

$output = @()
$errors = @()
if (Test-Path $tempLog) { $output = Get-Content $tempLog; Remove-Item $tempLog }
if (Test-Path $tempErr) { $errors = Get-Content $tempErr; Remove-Item $tempErr }

$failedTests = @()
$totals = @()
$fatalErrors = @()
$sawAllTestsPassed = $false
$sawSummary = $false
$isFailed = $false
$inSummary = $false
$currentFile = "Unknown File"

# Parse Standard Output for GUT failures and summary
foreach ($line in $output) {
    $line = $line.Trim()
    
    # Detect summary section
    if ($line -match "Run Summary") {
        $inSummary = $true
        $sawSummary = $true
        continue
    }

    if ($line -match "All tests passed") {
        $sawAllTestsPassed = $true
    }
    
    if ($inSummary) {
        if ($line -match "^res://") {
            $currentFile = $line
        }
        elseif ($line -match "^-\s*(test_\S+)") {
            $failedTests += "$($currentFile): $($matches[1])"
        }
        elseif ($line -match "^(Tests|Passing Tests|Failing Tests|Asserts|Orphans|Time)") {
            $totals += $line
            if ($line -match "Failing Tests" -and $line -match "[1-9]") {
                $isFailed = $true
            }
        }
    }
}

$allOutput = @($output) + @($errors)
$fatalErrors = $allOutput | Select-String -Pattern "SCRIPT ERROR|Parse Error|Resource still in use|resources still in use|CrashHandlerException|Program crashed|ERROR:" | Select-Object -First 8 -Unique
$nonFatalWarnings = $allOutput | Select-String -Pattern "ObjectDB instances leaked at exit" | Select-Object -First 4 -Unique

if ($failedTests.Count -gt 0 -or $fatalErrors.Count -gt 0) {
    $isFailed = $true
}
elseif ($sawSummary -and $sawAllTestsPassed) {
    $isFailed = $false
}
else {
    $isFailed = $true
}

if ($isFailed) {
    Write-Host "TEST_RESULTS: FAIL"
    
    if ($failedTests.Count -gt 0) {
        Write-Host "FAILED_SAMPLES:"
        $uniqueFailedTests = $failedTests | Select-Object -Unique
        for ($i = 0; $i -lt $uniqueFailedTests.Count; $i++) {
            Write-Host "[$($i + 1)] $($uniqueFailedTests[$i])"
        }
    }

    if ($fatalErrors) {
        Write-Host "FATAL_OUTPUT_DETECTED: YES"
        foreach ($err in $fatalErrors) {
            Write-Host "  $($err.ToString().Trim())"
        }
    }

    if ($totals.Count -gt 0) {
        Write-Host "SUMMARY:"
        foreach ($total in $totals) {
            Write-Host "  $total"
        }
    } else {
        $exitCodeText = if ($null -eq $exitCode) { "unknown" } else { $exitCode }
        Write-Host "SUMMARY: No summary found (Process exit code: $exitCodeText)"
        $outputSample = $allOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 12
        if ($outputSample.Count -gt 0) {
            Write-Host "OUTPUT_SAMPLE:"
            foreach ($line in $outputSample) {
                Write-Host "  $line"
            }
        } else {
            Write-Host "OUTPUT_SAMPLE: <empty>"
        }
    }
    exit 1
} else {
    Write-Host "TEST_RESULTS: PASS"
    if ($nonFatalWarnings) {
        Write-Host "NON_FATAL_WARNINGS:"
        foreach ($warning in $nonFatalWarnings) {
            Write-Host "  $($warning.ToString().Trim())"
        }
    }
    exit 0
}
