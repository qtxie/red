[CmdletBinding()]
param(
	[string]$Bootstrap,
	[string]$Output = 'build\red-toolchain\windows-x64\red-toolchain.exe',
	[string]$Dumpbin,
	[int]$CompileTimeoutSeconds = 900,
	[int]$RunTimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'windows-toolchain-tools.ps1')

if (-not $Bootstrap) {
	$Bootstrap = 'build\self-hosting\cc-speed1\red-bootstrap-speed1.exe'
}
$Bootstrap = Resolve-ToolchainPath $Bootstrap $root -MustExist
$Output = Resolve-ToolchainPath $Output $root
if ($Output.Equals($Bootstrap, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw 'The toolchain output must differ from the bootstrap compiler'
}
$Dumpbin = Resolve-ToolchainDumpbin $Dumpbin
$outputDirectory = Split-Path -Parent $Output
$logDirectory = Join-Path $outputDirectory 'logs'
$buildDirectory = Join-Path $root 'build\red-toolchain\windows-x64'
$generatedDirectory = Join-Path $root 'build\generated'
$generator = Join-Path $buildDirectory 'generate-toolchain-resources.exe'
$resources = Join-Path $generatedDirectory 'red-toolchain-resources.generated.red'
$generatorSource = Join-Path $root 'tools\self_hosting\generate-toolchain-resources.red'
$toolchainSource = Join-Path $root 'red-toolchain-windows-hybrid.red'
if ($generator.Equals($Bootstrap, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw 'The resource generator output must differ from the bootstrap compiler'
}
$buildEnvironment = @{
	SOURCE_DATE_EPOCH = Get-ToolchainSourceDateEpoch $root
}

New-Item -ItemType Directory -Force -Path @(
	$outputDirectory
	$logDirectory
	$buildDirectory
	$generatedDirectory
) | Out-Null

Remove-Item -LiteralPath $generator -Force -ErrorAction SilentlyContinue
Write-Host "Building resource generator with $Bootstrap"
Invoke-ToolchainProcess $Bootstrap @(
	'-r'
	'-t', 'Windows-X86-64'
	'-o', (ConvertTo-RedPath $generator)
	(ConvertTo-RedPath $generatorSource)
) $CompileTimeoutSeconds $root `
	(Join-Path $logDirectory 'generator-build.stdout.log') `
	(Join-Path $logDirectory 'generator-build.stderr.log') `
	-Environment $buildEnvironment | Out-Null

Remove-Item -LiteralPath $resources -Force -ErrorAction SilentlyContinue
Write-Host 'Generating deterministic embedded resources'
$generatorOutput = Invoke-ToolchainProcess $generator @(
	(ConvertTo-RedPath $root)
	(ConvertTo-RedPath $resources)
) $RunTimeoutSeconds $root `
	(Join-Path $logDirectory 'generator.stdout.log') `
	(Join-Path $logDirectory 'generator.stderr.log')
if ($generatorOutput -notmatch 'resources:\s+[1-9][0-9]*') {
	throw "Resource generator did not report a non-empty archive`n$generatorOutput"
}

Remove-Item -LiteralPath $Output -Force -ErrorAction SilentlyContinue
Write-Host "Building standalone hybrid toolchain at $Output"
Invoke-ToolchainProcess $Bootstrap @(
	'-r'
	'-t', 'Windows-X86-64'
	'-o', (ConvertTo-RedPath $Output)
	(ConvertTo-RedPath $toolchainSource)
) $CompileTimeoutSeconds $root `
	(Join-Path $logDirectory 'toolchain-build.stdout.log') `
	(Join-Path $logDirectory 'toolchain-build.stderr.log') `
	-Environment $buildEnvironment | Out-Null

$selfCheck = Invoke-ToolchainProcess $Output @('--self-check') $RunTimeoutSeconds `
	$outputDirectory (Join-Path $logDirectory 'self-check.stdout.log') `
	(Join-Path $logDirectory 'self-check.stderr.log')
if ($selfCheck -notmatch 'resource-self-check: ok resources: [1-9][0-9]*') {
	throw "Toolchain resource self-check did not pass`n$selfCheck"
}

$information = Invoke-ToolchainProcess $Output @('--toolchain-info') $RunTimeoutSeconds `
	$outputDirectory (Join-Path $logDirectory 'toolchain-info.stdout.log') `
	(Join-Path $logDirectory 'toolchain-info.stderr.log')
foreach ($expected in @(
	'host: Windows-X86-64'
	'targets: Windows-X86-64 Windows-X86-64-DLL'
	'backend: hybrid-rsir'
	'standalone: true'
)) {
	if ($information -notmatch [regex]::Escape($expected)) {
		throw "Toolchain information is missing '$expected'`n$information"
	}
}

$targets = Invoke-ToolchainProcess $Output @('--list-targets') $RunTimeoutSeconds `
	$outputDirectory (Join-Path $logDirectory 'targets.stdout.log') `
	(Join-Path $logDirectory 'targets.stderr.log')
$targetLines = @($targets -split "`r?`n" | Where-Object { $_ })
if ($targetLines.Count -ne 2 -or
	$targetLines[0] -ne 'Windows-X86-64' -or
	$targetLines[1] -ne 'Windows-X86-64-DLL') {
	throw "Unexpected toolchain target list`n$targets"
}

$manifest = (Invoke-ToolchainProcess $Output @('--resource-manifest') $RunTimeoutSeconds `
	$outputDirectory (Join-Path $logDirectory 'manifest.stdout.log') `
	(Join-Path $logDirectory 'manifest.stderr.log')).Trim()
if ($manifest -notmatch '^[0-9a-f]{64}$') {
	throw "Invalid resource manifest digest: $manifest"
}

Assert-X64PeImage $Output $Dumpbin $RunTimeoutSeconds $outputDirectory `
	(Join-Path $logDirectory 'toolchain-headers.log')
$imports = Get-DumpbinOutput $Dumpbin '/imports' $Output $RunTimeoutSeconds `
	$outputDirectory (Join-Path $logDirectory 'toolchain-imports.log')
if ($imports -match 'LIBREDRT\.DLL') {
	throw 'Standalone release toolchain imports libRedRT.dll'
}

Write-Host "Built $Output"
Write-Host "Resource manifest: $manifest"
