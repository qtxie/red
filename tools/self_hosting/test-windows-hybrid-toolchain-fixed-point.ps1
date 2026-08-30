[CmdletBinding()]
param(
	[string]$Bootstrap,
	[string]$OutputRoot = 'build\red-toolchain\windows-x64-fixed-point',
	[string]$Dumpbin,
	[string]$Python,
	[int]$CompileTimeoutSeconds = 900,
	[int]$RunTimeoutSeconds = 120,
	[switch]$KeepArtifactsOnFailure
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'windows-toolchain-tools.ps1')

if (-not $Bootstrap) {
	$Bootstrap = 'build\self-hosting\cc-speed1\red-bootstrap-speed1.exe'
}
$Bootstrap = Resolve-ToolchainPath $Bootstrap $root -MustExist
$OutputRoot = Resolve-ToolchainPath $OutputRoot $root
$Dumpbin = Resolve-ToolchainDumpbin $Dumpbin

if ($Python) {
	$Python = Resolve-ToolchainPath $Python $root -MustExist
} else {
	$pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
	if (-not $pythonCommand) { throw 'python.exe was not found; pass -Python' }
	$Python = $pythonCommand.Source
}

$buildScript = Join-Path $PSScriptRoot 'build-windows-hybrid-toolchain.ps1'
$hermeticScript = Join-Path $PSScriptRoot 'test-windows-hybrid-toolchain.ps1'
$comparisonScript = Join-Path $PSScriptRoot 'selfhost.py'
$logDirectory = Join-Path $OutputRoot 'logs'
$stage = Join-Path $OutputRoot 'stage\red-toolchain.exe'
$generations = @(
	(Join-Path $OutputRoot 'h1\red-toolchain.exe')
	(Join-Path $OutputRoot 'h2\red-toolchain.exe')
	(Join-Path $OutputRoot 'h3\red-toolchain.exe')
)
$succeeded = $false

try {
	New-Item -ItemType Directory -Force -Path $OutputRoot,$logDirectory | Out-Null
	$currentBootstrap = $Bootstrap
	for ($index = 0; $index -lt $generations.Count; $index++) {
		$generation = $index + 1
		Write-Host "Building Windows hybrid toolchain H$generation"
		& $buildScript `
			-Bootstrap $currentBootstrap `
			-Output $stage `
			-Dumpbin $Dumpbin `
			-CompileTimeoutSeconds $CompileTimeoutSeconds `
			-RunTimeoutSeconds $RunTimeoutSeconds
		New-Item -ItemType Directory -Force -Path `
			(Split-Path -Parent $generations[$index]) | Out-Null
		Copy-Item -LiteralPath $stage -Destination $generations[$index] -Force
		$currentBootstrap = $generations[$index]
	}

	$manifests = foreach ($index in 1,2) {
		(Invoke-ToolchainProcess $generations[$index] @('--resource-manifest') `
			$RunTimeoutSeconds $OutputRoot `
			(Join-Path $logDirectory "h$($index + 1)-manifest.stdout.log") `
			(Join-Path $logDirectory "h$($index + 1)-manifest.stderr.log")).Trim()
	}
	if ($manifests[0] -ne $manifests[1]) {
		throw "H2 and H3 embedded resource manifests differ: $($manifests -join ' != ')"
	}

	Invoke-ToolchainProcess $Python @(
		$comparisonScript
		'compare-pe'
		$generations[1]
		$generations[2]
	) $RunTimeoutSeconds $root `
		(Join-Path $logDirectory 'compare-pe.stdout.log') `
		(Join-Path $logDirectory 'compare-pe.stderr.log') | Write-Host

	$hermeticArguments = @{
		Toolchain = $generations[2]
		Dumpbin = $Dumpbin
		CompileTimeoutSeconds = $CompileTimeoutSeconds
		RunTimeoutSeconds = $RunTimeoutSeconds
	}
	if ($KeepArtifactsOnFailure) { $hermeticArguments.KeepArtifactsOnFailure = $true }
	& $hermeticScript @hermeticArguments

	Write-Host "Windows hybrid toolchain fixed point: $($generations[2])"
	Write-Host "Resource manifest: $($manifests[1])"
	$succeeded = $true
}
finally {
	if (-not $succeeded) {
		Write-Warning "Preserved failed fixed-point build at $OutputRoot"
	}
}
