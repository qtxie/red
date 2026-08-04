[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,

    [string]$Source = "tests\hello.red",
    [string]$Target = "Windows-X86-64",
    [int]$Runs = 1,
    [string]$OutputRoot = "build\compiler-benchmarks",
    [ValidateSet("default", "O0", "O1", "O2")]
    [string]$Optimization = "default",
    [switch]$Stage0,
    [switch]$NoDebug,
    [switch]$SkipRunVerification
)

$ErrorActionPreference = "Stop"

function Resolve-RepositoryPath {
    param([string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $Path))
}

function Convert-CompilerTime {
    param([string]$Text, [string]$Label)

    $escaped = [Regex]::Escape($Label)
    $match = [Regex]::Match($Text, "(?m)\.\.\.$escaped\s*:\s*(\d+:\d+:\d+(?:\.\d+)?)")
    if (-not $match.Success) { return $null }
    $value = $match.Groups[1].Value.Trim()
    try { return [TimeSpan]::Parse($value).TotalSeconds } catch { return $null }
}

function Invoke-CapturedProcess {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [hashtable]$Environment = @{}
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $script:RepositoryRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    foreach ($name in $Environment.Keys) {
        $startInfo.Environment[$name] = [string]$Environment[$name]
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $peakWorkingSet = 0L
    while (-not $process.WaitForExit(100)) {
        $process.Refresh()
        $peakWorkingSet = [Math]::Max($peakWorkingSet, $process.WorkingSet64)
    }
    try {
        $process.Refresh()
        $peakWorkingSet = [Math]::Max($peakWorkingSet, $process.PeakWorkingSet64)
    } catch {
        # A very short-lived process may already have released its performance counters.
    }
    $stopwatch.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    [pscustomobject]@{
        ExitCode       = $process.ExitCode
        WallSeconds    = $stopwatch.Elapsed.TotalSeconds
        CpuSeconds     = $process.TotalProcessorTime.TotalSeconds
        PeakWorkingSet = $peakWorkingSet
        Stdout         = $stdout
        Stderr         = $stderr
    }
}

$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$compilerPath = Resolve-RepositoryPath $Compiler
$sourcePath = Resolve-RepositoryPath $Source
$outputRootPath = Resolve-RepositoryPath $OutputRoot

if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw "Compiler not found: $compilerPath"
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source not found: $sourcePath"
}
if ($Runs -lt 1) { throw "Runs must be at least 1" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $outputRootPath $stamp
[void](New-Item -ItemType Directory -Force -Path $runRoot)

$compilerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $compilerPath).Hash
$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
$gitCommit = (& git -C $script:RepositoryRoot rev-parse HEAD).Trim()
$trackedDirty = [bool](& git -C $script:RepositoryRoot status --porcelain --untracked-files=no)
$results = [Collections.Generic.List[object]]::new()

for ($run = 1; $run -le $Runs; $run++) {
    $outputPath = Join-Path $runRoot ("hello-run-{0}.exe" -f $run)
    $profilePath = Join-Path $runRoot ("profile-run-{0}.red" -f $run)
    $arguments = [Collections.Generic.List[string]]::new()
    if ($Stage0) {
        foreach ($argument in @("-cqs", "./red.r")) { $arguments.Add($argument) }
    }
    $arguments.Add("-r")
    if (-not $NoDebug) { $arguments.Add("-d") }
    if ($Optimization -ne "default") { $arguments.Add("-$Optimization") }
    foreach ($argument in @("-t", $Target, "-o", $outputPath, $sourcePath)) {
        $arguments.Add($argument)
    }

    $environment = @{}
    if (-not $Stage0) { $environment.RED_COMPILER_PROFILE = $profilePath }
    $measurement = Invoke-CapturedProcess -FileName $compilerPath -Arguments $arguments.ToArray() -Environment $environment

    $stdoutPath = Join-Path $runRoot ("stdout-run-{0}.log" -f $run)
    $stderrPath = Join-Path $runRoot ("stderr-run-{0}.log" -f $run)
    Set-Content -LiteralPath $stdoutPath -Value $measurement.Stdout -Encoding utf8NoBOM
    Set-Content -LiteralPath $stderrPath -Value $measurement.Stderr -Encoding utf8NoBOM

    $outputExists = Test-Path -LiteralPath $outputPath -PathType Leaf
    $verifyExit = $null
    $verifyOutput = $null
    if ($measurement.ExitCode -eq 0 -and $outputExists -and -not $SkipRunVerification) {
        $verification = Invoke-CapturedProcess -FileName $outputPath -Arguments @()
        $verifyExit = $verification.ExitCode
        $verifyOutput = $verification.Stdout.TrimEnd()
    }

    $combined = $measurement.Stdout + "`n" + $measurement.Stderr
    $gcMatch = [Regex]::Match($combined, "(?m)^\.\.\.profile gc\s*:\s*cycles:\s*(\d+)\s+nodes:\s*(\d+)(?:\s+mark-seconds:\s*([0-9.]+)\s+sweep-seconds:\s*([0-9.]+))?\s+memory:\s*([^\r\n]+)")
    $phaseMatches = [Regex]::Matches($combined, "(?m)^\.\.\.profile phase\s*:\s*([^\s]+)\s+count:\s*(\d+)\s+time:\s*([^\s]+)")
    $phases = [ordered]@{}
    foreach ($phaseMatch in $phaseMatches) {
        $phases[$phaseMatch.Groups[1].Value] = [pscustomobject]@{
            Count = [int]$phaseMatch.Groups[2].Value
            Seconds = [TimeSpan]::Parse($phaseMatch.Groups[3].Value).TotalSeconds
        }
    }
    $results.Add([pscustomobject]@{
        Run                  = $run
        ExitCode             = $measurement.ExitCode
        WallSeconds          = [Math]::Round($measurement.WallSeconds, 6)
        CpuSeconds           = [Math]::Round($measurement.CpuSeconds, 6)
        PeakWorkingSetBytes  = $measurement.PeakWorkingSet
        FrontendSeconds      = Convert-CompilerTime $combined "frontend time"
        NativeSeconds        = Convert-CompilerTime $combined "native time"
        LinkSeconds          = Convert-CompilerTime $combined "link time"
        GcCycles             = if ($gcMatch.Success) { [int]$gcMatch.Groups[1].Value } else { $null }
        GcNodeCycles         = if ($gcMatch.Success) { [int]$gcMatch.Groups[2].Value } else { $null }
        GcMarkSeconds        = if ($gcMatch.Success -and $gcMatch.Groups[3].Success) { [double]$gcMatch.Groups[3].Value } else { $null }
        GcSweepSeconds       = if ($gcMatch.Success -and $gcMatch.Groups[4].Success) { [double]$gcMatch.Groups[4].Value } else { $null }
        Phases               = $phases
        OutputExists         = $outputExists
        OutputBytes          = if ($outputExists) { (Get-Item -LiteralPath $outputPath).Length } else { $null }
        OutputSha256         = if ($outputExists) { (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash } else { $null }
        VerificationExitCode = $verifyExit
        VerificationOutput   = $verifyOutput
        ProfilePath          = if (Test-Path -LiteralPath $profilePath) { $profilePath } else { $null }
        StdoutPath           = $stdoutPath
        StderrPath           = $stderrPath
    })
}

$report = [pscustomobject]@{
    SchemaVersion = 1
    CreatedUtc = [DateTime]::UtcNow.ToString("o")
    RepositoryRoot = $script:RepositoryRoot
    GitCommit = $gitCommit
    TrackedWorktreeDirty = $trackedDirty
    Compiler = $compilerPath
    CompilerSha256 = $compilerHash
    Source = $sourcePath
    SourceSha256 = $sourceHash
    Target = $Target
    Release = $true
    Debug = -not $NoDebug
    Optimization = $Optimization
    Stage0 = [bool]$Stage0
    Runs = $results
}

$reportPath = Join-Path $runRoot "report.json"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
$results | Format-Table Run, ExitCode, WallSeconds, CpuSeconds, PeakWorkingSetBytes, FrontendSeconds, NativeSeconds, LinkSeconds, GcCycles, OutputBytes, VerificationExitCode
Write-Output "Report: $reportPath"

if (@($results | Where-Object {
    $_.ExitCode -ne 0 -or
    -not $_.OutputExists -or
    ((-not $SkipRunVerification) -and $_.VerificationExitCode -ne 0)
}).Count -gt 0) {
    exit 1
}
