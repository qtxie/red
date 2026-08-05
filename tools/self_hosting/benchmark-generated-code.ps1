[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,

    [string]$Source = "tools\self_hosting\fixtures\benchmarks\integer-loop.reds",
    [string]$Target = "Windows-X86-64",
    [ValidateSet("O0", "O1", "O2")]
    [string[]]$Optimizations = @("O0", "O1", "O2"),
    [int]$Warmups = 2,
    [int]$Runs = 15,
    [string[]]$ProgramArguments = @(),
    [string]$OutputRoot = "build\generated-code-benchmarks",
    [int]$CompileTimeoutSeconds = 900,
    [int]$ProgramTimeoutSeconds = 120,
    [int]$ExpectedExitCode = 0,
    [switch]$NoDebug
)

$ErrorActionPreference = "Stop"

function Resolve-RepositoryPath {
    param([string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $Path))
}

function Invoke-CapturedProcess {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [int]$TimeoutSeconds,
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
    $timedOut = $false

    while (-not $process.WaitForExit(100)) {
        $process.Refresh()
        $peakWorkingSet = [Math]::Max($peakWorkingSet, $process.WorkingSet64)
        if ($TimeoutSeconds -gt 0 -and $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            $process.Kill()
            [void]$process.WaitForExit()
            break
        }
    }
    $stopwatch.Stop()

    try {
        $process.Refresh()
        $peakWorkingSet = [Math]::Max($peakWorkingSet, $process.PeakWorkingSet64)
    } catch {
        # A short-lived process may already have released its counters.
    }

    $cpuSeconds = $null
    try { $cpuSeconds = $process.TotalProcessorTime.TotalSeconds } catch {}

    [pscustomobject]@{
        ExitCode       = if ($timedOut) { $null } else { $process.ExitCode }
        TimedOut       = $timedOut
        WallSeconds    = $stopwatch.Elapsed.TotalSeconds
        CpuSeconds     = $cpuSeconds
        PeakWorkingSet = $peakWorkingSet
        Stdout         = $stdoutTask.GetAwaiter().GetResult()
        Stderr         = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-Median {
    param([double[]]$Values)

    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return $sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Assert-ProgramBehavior {
    param(
        [string]$Optimization,
        [string]$Stage,
        $Measurement,
        $Expected
    )

    if ($Measurement.TimedOut) {
        throw "$Optimization $Stage timed out after $ProgramTimeoutSeconds seconds"
    }
    if ($Measurement.ExitCode -ne $ExpectedExitCode) {
        throw "$Optimization $Stage exited with $($Measurement.ExitCode), expected $ExpectedExitCode"
    }
    if ($null -ne $Expected) {
        if ($Measurement.Stdout -cne $Expected.Stdout) {
            throw "$Optimization $Stage produced different stdout from $($Expected.Optimization)"
        }
        if ($Measurement.Stderr -cne $Expected.Stderr) {
            throw "$Optimization $Stage produced different stderr from $($Expected.Optimization)"
        }
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
if ($Warmups -lt 0) { throw "Warmups cannot be negative" }
if ($Runs -lt 1) { throw "Runs must be at least 1" }
if ($Optimizations.Count -eq 0) { throw "At least one optimization level is required" }

$duplicates = @($Optimizations | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) { throw "Optimization levels must be unique" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $outputRootPath $stamp
[void](New-Item -ItemType Directory -Force -Path $runRoot)

$compilerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $compilerPath).Hash
$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
$gitCommit = (& git -C $script:RepositoryRoot rev-parse HEAD).Trim()
$trackedDirty = [bool](& git -C $script:RepositoryRoot status --porcelain --untracked-files=no)
$extension = if ($Target -like "Windows-*") { ".exe" } else { "" }
$sourceName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
$compiled = [ordered]@{}

foreach ($optimization in $Optimizations) {
    $outputPath = Join-Path $runRoot ("{0}-{1}{2}" -f $sourceName, $optimization, $extension)
    $profilePath = Join-Path $runRoot ("compiler-{0}.red" -f $optimization)
    $arguments = [Collections.Generic.List[string]]::new()
    $arguments.Add("-r")
    if (-not $NoDebug) { $arguments.Add("-d") }
    $arguments.Add("-$optimization")
    foreach ($argument in @("-t", $Target, "-o", $outputPath, $sourcePath)) {
        $arguments.Add($argument)
    }

    $measurement = Invoke-CapturedProcess `
        -FileName $compilerPath `
        -Arguments $arguments.ToArray() `
        -TimeoutSeconds $CompileTimeoutSeconds `
        -Environment @{ RED_COMPILER_PROFILE = $profilePath }

    $stdoutPath = Join-Path $runRoot ("compiler-{0}.stdout.log" -f $optimization)
    $stderrPath = Join-Path $runRoot ("compiler-{0}.stderr.log" -f $optimization)
    Set-Content -LiteralPath $stdoutPath -Value $measurement.Stdout -Encoding utf8NoBOM
    Set-Content -LiteralPath $stderrPath -Value $measurement.Stderr -Encoding utf8NoBOM

    if ($measurement.TimedOut) {
        throw "$optimization compilation timed out after $CompileTimeoutSeconds seconds"
    }
    if ($measurement.ExitCode -ne 0) {
        throw "$optimization compilation failed with exit code $($measurement.ExitCode); see $stderrPath"
    }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "$optimization compilation produced no executable: $outputPath"
    }

    $compiled[$optimization] = [pscustomobject]@{
        Optimization        = $optimization
        OutputPath          = $outputPath
        OutputBytes         = (Get-Item -LiteralPath $outputPath).Length
        OutputSha256        = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash
        CompileWallSeconds  = [Math]::Round($measurement.WallSeconds, 6)
        CompileCpuSeconds   = if ($null -eq $measurement.CpuSeconds) { $null } else { [Math]::Round($measurement.CpuSeconds, 6) }
        CompilePeakBytes    = $measurement.PeakWorkingSet
        CompilerStdoutPath  = $stdoutPath
        CompilerStderrPath  = $stderrPath
        CompilerProfilePath = if (Test-Path -LiteralPath $profilePath) { $profilePath } else { $null }
    }
}

$expectedBehavior = $null
$verification = [Collections.Generic.List[object]]::new()
foreach ($optimization in $Optimizations) {
    $program = $compiled[$optimization]
    $measurement = Invoke-CapturedProcess `
        -FileName $program.OutputPath `
        -Arguments $ProgramArguments `
        -TimeoutSeconds $ProgramTimeoutSeconds
    Assert-ProgramBehavior $optimization "verification" $measurement $expectedBehavior
    if ($null -eq $expectedBehavior) {
        $expectedBehavior = [pscustomobject]@{
            Optimization = $optimization
            Stdout = $measurement.Stdout
            Stderr = $measurement.Stderr
        }
    }
    $verification.Add([pscustomobject]@{
        Optimization = $optimization
        ExitCode = $measurement.ExitCode
        Stdout = $measurement.Stdout
        Stderr = $measurement.Stderr
    })
}

for ($warmup = 1; $warmup -le $Warmups; $warmup++) {
    foreach ($optimization in $Optimizations) {
        $measurement = Invoke-CapturedProcess `
            -FileName $compiled[$optimization].OutputPath `
            -Arguments $ProgramArguments `
            -TimeoutSeconds $ProgramTimeoutSeconds
        Assert-ProgramBehavior $optimization "warmup $warmup" $measurement $expectedBehavior
    }
}

$samples = [Collections.Generic.List[object]]::new()
for ($run = 1; $run -le $Runs; $run++) {
    $offset = ($run - 1) % $Optimizations.Count
    for ($position = 0; $position -lt $Optimizations.Count; $position++) {
        $optimization = $Optimizations[($offset + $position) % $Optimizations.Count]
        $measurement = Invoke-CapturedProcess `
            -FileName $compiled[$optimization].OutputPath `
            -Arguments $ProgramArguments `
            -TimeoutSeconds $ProgramTimeoutSeconds
        Assert-ProgramBehavior $optimization "sample $run" $measurement $expectedBehavior
        $samples.Add([pscustomobject]@{
            Run = $run
            Position = $position + 1
            Optimization = $optimization
            WallSeconds = $measurement.WallSeconds
            CpuSeconds = $measurement.CpuSeconds
            PeakWorkingSetBytes = $measurement.PeakWorkingSet
        })
    }
}

$baselineOptimization = if ($Optimizations -contains "O0") { "O0" } else { $Optimizations[0] }
$baselineSamples = @($samples | Where-Object Optimization -eq $baselineOptimization | Sort-Object Run)
$summary = [Collections.Generic.List[object]]::new()

foreach ($optimization in $Optimizations) {
    $optimizationSamples = @($samples | Where-Object Optimization -eq $optimization | Sort-Object Run)
    $wallValues = [double[]]@($optimizationSamples | ForEach-Object WallSeconds)
    $ratios = [Collections.Generic.List[double]]::new()
    for ($index = 0; $index -lt $optimizationSamples.Count; $index++) {
        $baselineSeconds = [double]$baselineSamples[$index].WallSeconds
        $optimizationSeconds = [double]$optimizationSamples[$index].WallSeconds
        if ($optimizationSeconds -gt 0.0) {
            $ratios.Add($baselineSeconds / $optimizationSeconds)
        }
    }
    $summary.Add([pscustomobject]@{
        Optimization = $optimization
        Samples = $optimizationSamples.Count
        MedianWallSeconds = [Math]::Round((Get-Median $wallValues), 9)
        MedianPairedSpeedupVsBaseline = [Math]::Round((Get-Median $ratios.ToArray()), 6)
        OutputBytes = $compiled[$optimization].OutputBytes
        CompileWallSeconds = $compiled[$optimization].CompileWallSeconds
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
    Optimizations = $Optimizations
    Warmups = $Warmups
    Runs = $Runs
    ProgramArguments = $ProgramArguments
    BaselineOptimization = $baselineOptimization
    Compilations = @($compiled.Values)
    Verification = $verification
    Samples = $samples
    Summary = $summary
}

$reportPath = Join-Path $runRoot "report.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
$summary | Format-Table Optimization, Samples, MedianWallSeconds, MedianPairedSpeedupVsBaseline, OutputBytes, CompileWallSeconds
Write-Output "Report: $reportPath"
