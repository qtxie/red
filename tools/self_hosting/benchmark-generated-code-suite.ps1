[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,

    [string[]]$Sources = @(
        "tools\self_hosting\fixtures\benchmarks\integer-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\memory-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\call-heavy.reds",
        "tools\self_hosting\fixtures\benchmarks\float-call-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\small-dense-switch-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\pointer-arithmetic-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\resolver-intrinsic-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\copy-cell-machine-ir-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\register-pressure-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\global-memory-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\integer-division-loop.reds",
        "tools\self_hosting\fixtures\benchmarks\date-arithmetic-loop.reds"
    ),
    [string]$Target = "Windows-X86-64",
    [ValidateSet("O0", "O1", "O2")]
    [string[]]$Optimizations = @("O0", "O2"),
    [ValidateSet("O0", "O1", "O2")]
    [string]$BaselineOptimization = "O0",
    [ValidateSet("O0", "O1", "O2")]
    [string]$CandidateOptimization = "O2",
    [int]$Warmups = 2,
    [int]$Runs = 15,
    [int]$BootstrapIterations = 2000,
    [double]$MaximumRegressionPercent = 2.0,
    [double]$MinimumGeomeanImprovementPercent = 3.0,
    [string[]]$ProgramArguments = @(),
    [string]$OutputRoot = "build\generated-code-benchmark-suites",
    [int]$CompileTimeoutSeconds = 900,
    [int]$ProgramTimeoutSeconds = 120,
    [int]$ExpectedExitCode = 0,
    [ValidateSet("Native", "WSL")]
    [string]$ProgramRuntime = "Native",
    [string]$WslDistribution = "",
    [switch]$NoDebug,
    [switch]$AllowGateFailure
)

$ErrorActionPreference = "Stop"

function Resolve-RepositoryPath {
    param([string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $Path))
}

function Get-Median {
    param([double[]]$Values)

    if ($Values.Count -eq 0) { throw "Cannot take the median of an empty sample" }
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return [double]$sorted[$middle] }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percentile
    )

    if ($Values.Count -eq 0) { throw "Cannot take a percentile of an empty sample" }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) { return [double]$sorted[0] }
    $position = ($sorted.Count - 1) * $Percentile
    $lower = [int][Math]::Floor($position)
    $upper = [int][Math]::Ceiling($position)
    if ($lower -eq $upper) { return [double]$sorted[$lower] }
    $fraction = $position - $lower
    return ([double]$sorted[$lower] * (1.0 - $fraction)) +
        ([double]$sorted[$upper] * $fraction)
}

function Get-PairedRuntimeRatios {
    param(
        $Report,
        [string]$Baseline,
        [string]$Candidate
    )

    $baselineByRun = @{}
    foreach ($sample in @($Report.Samples | Where-Object Optimization -eq $Baseline)) {
        $baselineByRun[[int]$sample.Run] = [double]$sample.WallSeconds
    }
    $candidateByRun = @{}
    foreach ($sample in @($Report.Samples | Where-Object Optimization -eq $Candidate)) {
        $candidateByRun[[int]$sample.Run] = [double]$sample.WallSeconds
    }
    if ($baselineByRun.Count -ne $candidateByRun.Count) {
        throw "Baseline and candidate sample counts differ"
    }

    $ratios = [Collections.Generic.List[double]]::new()
    foreach ($run in @($baselineByRun.Keys | Sort-Object)) {
        if (-not $candidateByRun.ContainsKey($run)) {
            throw "Candidate sample is missing run $run"
        }
        $baselineSeconds = [double]$baselineByRun[$run]
        $candidateSeconds = [double]$candidateByRun[$run]
        if ($baselineSeconds -le 0.0 -or $candidateSeconds -le 0.0) {
            throw "Runtime samples must be positive"
        }
        $ratios.Add($candidateSeconds / $baselineSeconds)
    }
    return $ratios.ToArray()
}

function Get-BootstrapMedianInterval {
    param(
        [double[]]$Values,
        [int]$Iterations,
        [int]$Seed
    )

    $random = [Random]::new($Seed)
    $medians = [double[]]::new($Iterations)
    $sample = [double[]]::new($Values.Count)
    for ($iteration = 0; $iteration -lt $Iterations; $iteration++) {
        for ($index = 0; $index -lt $Values.Count; $index++) {
            $sample[$index] = $Values[$random.Next($Values.Count)]
        }
        $medians[$iteration] = Get-Median $sample
    }
    return [pscustomobject]@{
        Lower = Get-Percentile $medians 0.025
        Upper = Get-Percentile $medians 0.975
    }
}

function Get-BootstrapGeomeanInterval {
    param(
        [object[]]$BenchmarkResults,
        [int]$Iterations,
        [int]$Seed
    )

    $random = [Random]::new($Seed)
    $geomeans = [double[]]::new($Iterations)
    for ($iteration = 0; $iteration -lt $Iterations; $iteration++) {
        $logSum = 0.0
        foreach ($benchmark in $BenchmarkResults) {
            $values = [double[]]$benchmark.PairedCandidateToBaselineRatios
            $sample = [double[]]::new($values.Count)
            for ($index = 0; $index -lt $values.Count; $index++) {
                $sample[$index] = $values[$random.Next($values.Count)]
            }
            $logSum += [Math]::Log((Get-Median $sample))
        }
        $geomeans[$iteration] = [Math]::Exp($logSum / $BenchmarkResults.Count)
    }
    return [pscustomobject]@{
        Lower = Get-Percentile $geomeans 0.025
        Upper = Get-Percentile $geomeans 0.975
    }
}

$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$compilerPath = Resolve-RepositoryPath $Compiler
$outputRootPath = Resolve-RepositoryPath $OutputRoot
$benchmarkRunner = Join-Path $PSScriptRoot "benchmark-generated-code.ps1"

if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw "Compiler not found: $compilerPath"
}
if (-not (Test-Path -LiteralPath $benchmarkRunner -PathType Leaf)) {
    throw "Benchmark runner not found: $benchmarkRunner"
}
if ($Sources.Count -eq 0) { throw "At least one benchmark source is required" }
if ($Runs -lt 1) { throw "Runs must be at least 1" }
if ($BootstrapIterations -lt 1) { throw "BootstrapIterations must be at least 1" }
if ($BaselineOptimization -eq $CandidateOptimization) {
    throw "Baseline and candidate optimization levels must differ"
}
if ($Optimizations -notcontains $BaselineOptimization) {
    throw "Optimizations does not contain baseline $BaselineOptimization"
}
if ($Optimizations -notcontains $CandidateOptimization) {
    throw "Optimizations does not contain candidate $CandidateOptimization"
}
if ($MaximumRegressionPercent -lt 0.0) {
    throw "MaximumRegressionPercent cannot be negative"
}
if ($MinimumGeomeanImprovementPercent -lt 0.0 -or $MinimumGeomeanImprovementPercent -ge 100.0) {
    throw "MinimumGeomeanImprovementPercent must be between 0 and 100"
}

$sourcePaths = [Collections.Generic.List[string]]::new()
$sourceNames = @{}
foreach ($source in $Sources) {
    $sourcePath = Resolve-RepositoryPath $source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Benchmark source not found: $sourcePath"
    }
    $sourceName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
    if ($sourceNames.ContainsKey($sourceName)) {
        throw "Benchmark source names must be unique: $sourceName"
    }
    $sourceNames[$sourceName] = $true
    $sourcePaths.Add($sourcePath)
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$targetName = $Target -replace '[^A-Za-z0-9_.-]', '-'
$runRoot = Join-Path $outputRootPath ("{0}-{1}" -f $stamp, $targetName)
[void](New-Item -ItemType Directory -Force -Path $runRoot)

$benchmarkResults = [Collections.Generic.List[object]]::new()
$benchmarkIndex = 0
$runtimeMetadata = $null
foreach ($sourcePath in $sourcePaths) {
    $benchmarkIndex++
    $sourceName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
    Write-Output ("[{0}/{1}] {2}" -f $benchmarkIndex, $sourcePaths.Count, $sourceName)
    $benchmarkRoot = Join-Path $runRoot $sourceName
    $runnerArguments = @{
        Compiler = $compilerPath
        Source = $sourcePath
        Target = $Target
        Optimizations = $Optimizations
        Warmups = $Warmups
        Runs = $Runs
        ProgramArguments = $ProgramArguments
        OutputRoot = $benchmarkRoot
        CompileTimeoutSeconds = $CompileTimeoutSeconds
        ProgramTimeoutSeconds = $ProgramTimeoutSeconds
        ExpectedExitCode = $ExpectedExitCode
        ProgramRuntime = $ProgramRuntime
        WslDistribution = $WslDistribution
        NoDebug = $NoDebug
    }
    $runnerLog = Join-Path $runRoot ("{0}.runner.log" -f $sourceName)
    & $benchmarkRunner @runnerArguments 2>&1 | Tee-Object -FilePath $runnerLog | Out-Host

    $reportPath = Get-ChildItem -LiteralPath $benchmarkRoot -Filter report.json -File -Recurse |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $reportPath) { throw "No report was produced for $sourceName" }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($null -eq $runtimeMetadata) { $runtimeMetadata = $report.ProgramRuntime }
    $ratios = [double[]](Get-PairedRuntimeRatios `
        -Report $report `
        -Baseline $BaselineOptimization `
        -Candidate $CandidateOptimization)
    $medianRatio = Get-Median $ratios
    $interval = Get-BootstrapMedianInterval `
        -Values $ratios `
        -Iterations $BootstrapIterations `
        -Seed (17011 + $benchmarkIndex)
    $baselineSummary = @($report.Summary | Where-Object Optimization -eq $BaselineOptimization)[0]
    $candidateSummary = @($report.Summary | Where-Object Optimization -eq $CandidateOptimization)[0]
    $benchmarkResults.Add([pscustomobject]@{
        Name = $sourceName
        Source = $sourcePath
        SourceSha256 = [string]$report.SourceSha256
        Report = $reportPath
        Samples = $ratios.Count
        BaselineMedianWallSeconds = [double]$baselineSummary.MedianWallSeconds
        CandidateMedianWallSeconds = [double]$candidateSummary.MedianWallSeconds
        MedianCandidateToBaselineRatio = $medianRatio
        RuntimeChangePercent = ($medianRatio - 1.0) * 100.0
        Ratio95PercentLower = [double]$interval.Lower
        Ratio95PercentUpper = [double]$interval.Upper
        BaselineOutputBytes = [long]$baselineSummary.OutputBytes
        CandidateOutputBytes = [long]$candidateSummary.OutputBytes
        PairedCandidateToBaselineRatios = $ratios
    })
}

$logSum = 0.0
foreach ($benchmark in $benchmarkResults) {
    $logSum += [Math]::Log([double]$benchmark.MedianCandidateToBaselineRatio)
}
$geomeanRatio = [Math]::Exp($logSum / $benchmarkResults.Count)
$geomeanInterval = Get-BootstrapGeomeanInterval `
    -BenchmarkResults $benchmarkResults.ToArray() `
    -Iterations $BootstrapIterations `
    -Seed 8675309
$maximumRuntimeRatio = 1.0 + ($MaximumRegressionPercent / 100.0)
$requiredGeomeanRatio = 1.0 - ($MinimumGeomeanImprovementPercent / 100.0)
$credibleRegressions = @(
    $benchmarkResults |
        Where-Object { [double]$_.Ratio95PercentLower -gt $maximumRuntimeRatio } |
        ForEach-Object Name
)
$pointRegressions = @(
    $benchmarkResults |
        Where-Object { [double]$_.MedianCandidateToBaselineRatio -gt $maximumRuntimeRatio } |
        ForEach-Object Name
)
$regressionGatePassed = $credibleRegressions.Count -eq 0
$geomeanGatePassed = $geomeanRatio -le $requiredGeomeanRatio
$gatePassed = $regressionGatePassed -and $geomeanGatePassed

$gitCommit = (& git -C $script:RepositoryRoot rev-parse HEAD).Trim()
$trackedDirty = [bool](& git -C $script:RepositoryRoot status --porcelain --untracked-files=no)
$hostProcessor = $env:PROCESSOR_IDENTIFIER
try {
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($processor.Name) { $hostProcessor = $processor.Name.Trim() }
} catch {
    # PROCESSOR_IDENTIFIER remains useful when CIM is unavailable.
}
$report = [pscustomobject]@{
    SchemaVersion = 2
    CreatedUtc = [DateTime]::UtcNow.ToString("o")
    RepositoryRoot = $script:RepositoryRoot
    GitCommit = $gitCommit
    TrackedWorktreeDirty = $trackedDirty
    Compiler = $compilerPath
    CompilerSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $compilerPath).Hash
    BenchmarkRunner = $benchmarkRunner
    BenchmarkRunnerSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $benchmarkRunner).Hash
    SuiteRunnerSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash
    HostProcessor = $hostProcessor
    Target = $Target
    ProgramRuntime = $runtimeMetadata
    WslDistribution = $WslDistribution
    Release = $true
    Debug = -not $NoDebug
    Optimizations = $Optimizations
    BaselineOptimization = $BaselineOptimization
    CandidateOptimization = $CandidateOptimization
    Warmups = $Warmups
    Runs = $Runs
    BootstrapIterations = $BootstrapIterations
    Benchmarks = $benchmarkResults
    Aggregate = [pscustomobject]@{
        GeomeanCandidateToBaselineRatio = $geomeanRatio
        GeomeanRuntimeImprovementPercent = (1.0 - $geomeanRatio) * 100.0
        GeomeanRatio95PercentLower = [double]$geomeanInterval.Lower
        GeomeanRatio95PercentUpper = [double]$geomeanInterval.Upper
    }
    Gate = [pscustomobject]@{
        MaximumRegressionPercent = $MaximumRegressionPercent
        MaximumRuntimeRatio = $maximumRuntimeRatio
        MinimumGeomeanImprovementPercent = $MinimumGeomeanImprovementPercent
        RequiredGeomeanRuntimeRatio = $requiredGeomeanRatio
        CredibleRegressions = $credibleRegressions
        PointEstimateRegressions = $pointRegressions
        RegressionGatePassed = $regressionGatePassed
        GeomeanGatePassed = $geomeanGatePassed
        Passed = $gatePassed
    }
}

$reportPath = Join-Path $runRoot "suite-report.json"
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
$benchmarkResults |
    Select-Object Name, Samples,
        @{Name = "RuntimeRatio"; Expression = { [Math]::Round($_.MedianCandidateToBaselineRatio, 6) }},
        @{Name = "ChangePercent"; Expression = { [Math]::Round($_.RuntimeChangePercent, 3) }},
        @{Name = "Ratio95Low"; Expression = { [Math]::Round($_.Ratio95PercentLower, 6) }},
        @{Name = "Ratio95High"; Expression = { [Math]::Round($_.Ratio95PercentUpper, 6) }} |
    Format-Table
Write-Output ("Geomean candidate/baseline runtime ratio: {0:N6} ({1:N3}% improvement)" -f `
    $geomeanRatio, ((1.0 - $geomeanRatio) * 100.0))
Write-Output ("Regression gate: {0}; geomean gate: {1}; overall: {2}" -f `
    $regressionGatePassed, $geomeanGatePassed, $gatePassed)
Write-Output "Report: $reportPath"

if (-not $gatePassed -and -not $AllowGateFailure) {
    throw "Generated-code performance gate failed; see $reportPath"
}
