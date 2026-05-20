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

    throw "Godot executable not found. Set GODOT_BIN or add Godot to PATH."
}

$godotPath = Resolve-GodotBin
$gutScript = "addons/gut/gut_cmdln.gd"
$timeoutSeconds = 60

# Run Godot and capture BOTH output and errors to temporary files
$tempRoot = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
$tempLog = Join-Path $tempRoot "go_dot_game_gut_stdout.tmp"
$tempErr = Join-Path $tempRoot "go_dot_game_gut_stderr.tmp"

# Clean up old logs
if (Test-Path $tempLog) { Remove-Item $tempLog }
if (Test-Path $tempErr) { Remove-Item $tempErr }

$process = Start-Process -FilePath $godotPath -ArgumentList "--path", $repoRoot, "-s", $gutScript, "--headless", "-gexit", "-glog=0" -NoNewWindow -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

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
$fatalErrors = $allOutput | Select-String -Pattern "SCRIPT ERROR|Parse Error|Resource still in use|resources still in use|ObjectDB instances leaked" | Select-Object -First 5 -Unique

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
        Write-Host "SUMMARY: No summary found (Process exit code: $exitCode)"
    }
    exit 1
} else {
    Write-Host "TEST_RESULTS: PASS"
    exit 0
}
