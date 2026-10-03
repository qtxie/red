[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,

    [string]$Source = "tools\self_hosting\fixtures\benchmarks\integer-loop.reds",
    [string]$Target = "MSDOS-X86-64",
    [string[]]$Arms = @("default"),
    [hashtable]$ArmFlags = @{},
    [int]$Warmups = 2,
    [int]$Runs = 15,
    [string[]]$ProgramArguments = @(),
    [string]$OutputRoot = "build\generated-code-benchmarks",
    [int]$CompileTimeoutSeconds = 900,
    [int]$ProgramTimeoutSeconds = 120,
    [int]$ExpectedExitCode = 0,
    [ValidateSet("Native", "WSL")]
    [string]$ProgramRuntime = "Native",
    [string]$WslDistribution = "",
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

function ConvertTo-WslPath {
    param([string]$Path)

    $arguments = [Collections.Generic.List[string]]::new()
    if ($WslDistribution) {
        foreach ($argument in @("-d", $WslDistribution)) { $arguments.Add($argument) }
    }
    foreach ($argument in @("-e", "wslpath", "-a", "-u", $Path)) {
        $arguments.Add($argument)
    }
    $measurement = Invoke-CapturedProcess `
        -FileName "wsl.exe" `
        -Arguments $arguments.ToArray() `
        -TimeoutSeconds 30
    if ($measurement.TimedOut) { throw "wslpath timed out for $Path" }
    if ($measurement.ExitCode -ne 0) {
        throw "wslpath failed for ${Path}: $($measurement.Stderr.Trim())"
    }
    return $measurement.Stdout.Trim()
}

function Assert-ProgramBehavior {
    param(
        [string]$Arm,
        [string]$Stage,
        $Measurement,
        $Expected
    )

    if ($Measurement.TimedOut) {
        throw "$Arm $Stage timed out after $ProgramTimeoutSeconds seconds"
    }
    if ($Measurement.ExitCode -ne $ExpectedExitCode) {
        throw "$Arm $Stage exited with $($Measurement.ExitCode), expected $ExpectedExitCode"
    }
    if ($null -ne $Expected) {
        if ($Measurement.Stdout -cne $Expected.Stdout) {
            throw "$Arm $Stage produced different stdout from $($Expected.Arm)"
        }
        if ($Measurement.Stderr -cne $Expected.Stderr) {
            throw "$Arm $Stage produced different stderr from $($Expected.Arm)"
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
if ($Arms.Count -eq 0) { throw "At least one arm is required" }
if ($ProgramRuntime -eq "WSL" -and $Target -like "Windows-*") {
    throw "WSL program runtime requires a non-Windows target"
}

$duplicates = @($Arms | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) { throw "Arm names must be unique" }

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

foreach ($arm in $Arms) {
    $outputPath = Join-Path $runRoot ("{0}-{1}{2}" -f $sourceName, $arm, $extension)
    $profilePath = Join-Path $runRoot ("compiler-{0}.red" -f $arm)
    $arguments = [Collections.Generic.List[string]]::new()
    $arguments.Add("-r")
    if (-not $NoDebug) { $arguments.Add("-d") }
    foreach ($argument in @($ArmFlags[$arm])) { if ($argument) { $arguments.Add($argument) } }
    foreach ($argument in @("-t", $Target, "-o", $outputPath, $sourcePath)) {
        $arguments.Add($argument)
    }

    $measurement = Invoke-CapturedProcess `
        -FileName $compilerPath `
        -Arguments $arguments.ToArray() `
        -TimeoutSeconds $CompileTimeoutSeconds `
        -Environment @{ RED_COMPILER_PROFILE = $profilePath }

    $stdoutPath = Join-Path $runRoot ("compiler-{0}.stdout.log" -f $arm)
    $stderrPath = Join-Path $runRoot ("compiler-{0}.stderr.log" -f $arm)
    Set-Content -LiteralPath $stdoutPath -Value $measurement.Stdout -Encoding utf8NoBOM
    Set-Content -LiteralPath $stderrPath -Value $measurement.Stderr -Encoding utf8NoBOM

    if ($measurement.TimedOut) {
        throw "$arm compilation timed out after $CompileTimeoutSeconds seconds"
    }
    if ($measurement.ExitCode -ne 0) {
        throw "$arm compilation failed with exit code $($measurement.ExitCode); see $stderrPath"
    }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "$arm compilation produced no executable: $outputPath"
    }

    $compiled[$arm] = [pscustomobject]@{
        Arm        = $arm
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

$verification = [Collections.Generic.List[object]]::new()
$samples = [Collections.Generic.List[object]]::new()
$runtimeMetadata = [pscustomobject]@{
    Kind = "Native"
    Platform = [Environment]::OSVersion.VersionString
}

if ($ProgramRuntime -eq "WSL") {
    $programs = [Collections.Generic.List[object]]::new()
    foreach ($arm in $Arms) {
        $programs.Add([pscustomobject]@{
            Arm = $arm
            Path = ConvertTo-WslPath $compiled[$arm].OutputPath
        })
    }
    $request = [pscustomobject]@{
        Programs = $programs
        ProgramArguments = $ProgramArguments
        ProgramTimeoutSeconds = $ProgramTimeoutSeconds
        ExpectedExitCode = $ExpectedExitCode
        Warmups = $Warmups
        Runs = $Runs
    }
    $requestPath = Join-Path $runRoot "wsl-runtime-request.json"
    $request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestPath -Encoding utf8NoBOM
    $driverPath = Resolve-RepositoryPath "tools\self_hosting\benchmark-generated-code-wsl.py"
    $driverArguments = [Collections.Generic.List[string]]::new()
    if ($WslDistribution) {
        foreach ($argument in @("-d", $WslDistribution)) { $driverArguments.Add($argument) }
    }
    foreach ($argument in @(
        "-e",
        "python3",
        (ConvertTo-WslPath $driverPath),
        "--request",
        (ConvertTo-WslPath $requestPath)
    )) {
        $driverArguments.Add($argument)
    }
    $invocationCount = $Arms.Count * (1 + $Warmups + $Runs)
    $driverTimeout = if ($ProgramTimeoutSeconds -eq 0) {
        0
    } else {
        [Math]::Max(60, ($invocationCount * $ProgramTimeoutSeconds) + 30)
    }
    $measurement = Invoke-CapturedProcess `
        -FileName "wsl.exe" `
        -Arguments $driverArguments.ToArray() `
        -TimeoutSeconds $driverTimeout
    $driverStdoutPath = Join-Path $runRoot "wsl-runtime.stdout.log"
    $driverStderrPath = Join-Path $runRoot "wsl-runtime.stderr.log"
    Set-Content -LiteralPath $driverStdoutPath -Value $measurement.Stdout -Encoding utf8NoBOM
    Set-Content -LiteralPath $driverStderrPath -Value $measurement.Stderr -Encoding utf8NoBOM
    if ($measurement.TimedOut) {
        throw "WSL runtime driver timed out after $driverTimeout seconds"
    }
    if ($measurement.ExitCode -ne 0) {
        throw "WSL runtime driver failed with exit code $($measurement.ExitCode); see $driverStderrPath"
    }
    $runtimeResult = $measurement.Stdout | ConvertFrom-Json
    $runtimeMetadata = $runtimeResult.Runtime
    $runtimeMetadata | Add-Member -NotePropertyName Distribution -NotePropertyValue $WslDistribution
    foreach ($item in $runtimeResult.Verification) { $verification.Add($item) }
    foreach ($item in $runtimeResult.Samples) { $samples.Add($item) }
} else {
    $expectedBehavior = $null
    foreach ($arm in $Arms) {
        $program = $compiled[$arm]
        $measurement = Invoke-CapturedProcess `
            -FileName $program.OutputPath `
            -Arguments $ProgramArguments `
            -TimeoutSeconds $ProgramTimeoutSeconds
        Assert-ProgramBehavior $arm "verification" $measurement $expectedBehavior
        if ($null -eq $expectedBehavior) {
            $expectedBehavior = [pscustomobject]@{
                Arm = $arm
                Stdout = $measurement.Stdout
                Stderr = $measurement.Stderr
            }
        }
        $verification.Add([pscustomobject]@{
            Arm = $arm
            ExitCode = $measurement.ExitCode
            Stdout = $measurement.Stdout
            Stderr = $measurement.Stderr
        })
    }

    for ($warmup = 1; $warmup -le $Warmups; $warmup++) {
        foreach ($arm in $Arms) {
            $measurement = Invoke-CapturedProcess `
                -FileName $compiled[$arm].OutputPath `
                -Arguments $ProgramArguments `
                -TimeoutSeconds $ProgramTimeoutSeconds
            Assert-ProgramBehavior $arm "warmup $warmup" $measurement $expectedBehavior
        }
    }

    for ($run = 1; $run -le $Runs; $run++) {
        $offset = ($run - 1) % $Arms.Count
        for ($position = 0; $position -lt $Arms.Count; $position++) {
            $arm = $Arms[($offset + $position) % $Arms.Count]
            $measurement = Invoke-CapturedProcess `
                -FileName $compiled[$arm].OutputPath `
                -Arguments $ProgramArguments `
                -TimeoutSeconds $ProgramTimeoutSeconds
            Assert-ProgramBehavior $arm "sample $run" $measurement $expectedBehavior
            $samples.Add([pscustomobject]@{
                Run = $run
                Position = $position + 1
                Arm = $arm
                WallSeconds = $measurement.WallSeconds
                CpuSeconds = $measurement.CpuSeconds
                PeakWorkingSetBytes = $measurement.PeakWorkingSet
            })
        }
    }
}

$baselineArm = if ($Arms -contains "O0") { "O0" } else { $Arms[0] }
$baselineSamples = @($samples | Where-Object Arm -eq $baselineArm | Sort-Object Run)
$summary = [Collections.Generic.List[object]]::new()

foreach ($arm in $Arms) {
    $optimizationSamples = @($samples | Where-Object Arm -eq $arm | Sort-Object Run)
    $wallValues = [double[]]@($optimizationSamples | ForEach-Object WallSeconds)
    $cpuValues = [double[]]@($optimizationSamples | ForEach-Object CpuSeconds | Where-Object { $null -ne $_ })
    $ratios = [Collections.Generic.List[double]]::new()
    for ($index = 0; $index -lt $optimizationSamples.Count; $index++) {
        $baselineSeconds = [double]$baselineSamples[$index].WallSeconds
        $optimizationSeconds = [double]$optimizationSamples[$index].WallSeconds
        if ($optimizationSeconds -gt 0.0) {
            $ratios.Add($baselineSeconds / $optimizationSeconds)
        }
    }
    $summary.Add([pscustomobject]@{
        Arm = $arm
        Samples = $optimizationSamples.Count
        MedianWallSeconds = [Math]::Round((Get-Median $wallValues), 9)
        MedianCpuSeconds = if ($cpuValues.Count -eq 0) { $null } else { [Math]::Round((Get-Median $cpuValues), 9) }
        MedianPairedSpeedupVsBaseline = [Math]::Round((Get-Median $ratios.ToArray()), 6)
        OutputBytes = $compiled[$arm].OutputBytes
        CompileWallSeconds = $compiled[$arm].CompileWallSeconds
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
    Arms = $Arms
    Warmups = $Warmups
    Runs = $Runs
    ProgramArguments = $ProgramArguments
    ProgramRuntime = $runtimeMetadata
    BaselineArm = $baselineArm
    Compilations = @($compiled.Values)
    Verification = $verification
    Samples = $samples
    Summary = $summary
}

$reportPath = Join-Path $runRoot "report.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
$summary | Format-Table Arm, Samples, MedianWallSeconds, MedianCpuSeconds, MedianPairedSpeedupVsBaseline, OutputBytes, CompileWallSeconds
Write-Output "Report: $reportPath"
