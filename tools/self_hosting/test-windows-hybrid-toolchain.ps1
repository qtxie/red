[CmdletBinding()]
param(
	[Parameter(Mandatory)][string]$Toolchain,
	[string]$Dumpbin,
	[int]$CompileTimeoutSeconds = 900,
	[int]$RunTimeoutSeconds = 120,
	[switch]$KeepArtifactsOnFailure
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'windows-toolchain-tools.ps1')

$Toolchain = Resolve-ToolchainPath $Toolchain $root -MustExist
$Dumpbin = Resolve-ToolchainDumpbin $Dumpbin
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$work = Join-Path $temporaryRoot ("red-toolchain-windows-" + [guid]::NewGuid().ToString('N'))
$fixtureDirectory = Join-Path $root 'tools\self_hosting\fixtures\toolchain'
$logDirectory = Join-Path $work 'logs'
$localToolchain = Join-Path $work 'red-toolchain.exe'
$succeeded = $false

function Invoke-Compiler {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][string[]]$CompilerArguments
	)

	$output = Invoke-ToolchainProcess $localToolchain $CompilerArguments `
		$CompileTimeoutSeconds $work `
		(Join-Path $logDirectory "$Name-compile.stdout.log") `
		(Join-Path $logDirectory "$Name-compile.stderr.log")
	if ($output -match [regex]::Escape($root)) {
		throw "$Name compilation exposed the repository path`n$output"
	}
	$output
}

function Invoke-Fixture {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][string]$Executable
	)

	Invoke-ToolchainProcess $Executable @() $RunTimeoutSeconds $work `
		(Join-Path $logDirectory "$Name-run.stdout.log") `
		(Join-Path $logDirectory "$Name-run.stderr.log")
}

function Assert-Marker {
	param(
		[Parameter(Mandatory)][string]$Output,
		[Parameter(Mandatory)][string]$Marker,
		[Parameter(Mandatory)][string]$Name
	)

	$lines = @($Output -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	$matches = @($lines | Where-Object { $_ -eq $Marker })
	if ($matches.Count -ne 1 -or $lines[-1] -ne $Marker) {
		throw "$Name produced unexpected output`n$Output"
	}
}

function Get-Imports {
	param(
		[Parameter(Mandatory)][string]$Image,
		[Parameter(Mandatory)][string]$Name
	)

	Get-DumpbinOutput $Dumpbin '/imports' $Image $RunTimeoutSeconds $work `
		(Join-Path $logDirectory "$Name-imports.log")
}

function Assert-StandaloneImage {
	param(
		[Parameter(Mandatory)][string]$Image,
		[Parameter(Mandatory)][string]$Name
	)

	Assert-X64PeImage $Image $Dumpbin $RunTimeoutSeconds $work `
		(Join-Path $logDirectory "$Name-headers.log")
	$imports = Get-Imports $Image $Name
	if ($imports -match 'LIBREDRT\.DLL') { throw "$Name unexpectedly imports libRedRT.dll" }
}

try {
	New-Item -ItemType Directory -Path $work,$logDirectory | Out-Null
	Copy-Item -LiteralPath $Toolchain -Destination $localToolchain
	foreach ($fixture in Get-ChildItem -LiteralPath $fixtureDirectory -File) {
		Copy-Item -LiteralPath $fixture.FullName -Destination $work
	}

	$selfCheck = Invoke-ToolchainProcess $localToolchain @('--self-check') `
		$RunTimeoutSeconds $work `
		(Join-Path $logDirectory 'self-check.stdout.log') `
		(Join-Path $logDirectory 'self-check.stderr.log')
	if ($selfCheck -notmatch 'resource-self-check: ok resources: [1-9][0-9]*') {
		throw "Embedded resource self-check failed`n$selfCheck"
	}
	$information = Invoke-ToolchainProcess $localToolchain @('--toolchain-info') `
		$RunTimeoutSeconds $work `
		(Join-Path $logDirectory 'toolchain-info.stdout.log') `
		(Join-Path $logDirectory 'toolchain-info.stderr.log')
	if ($information -notmatch 'backend: hybrid-rsir' -or
		$information -notmatch 'standalone: true') {
		throw "Copied compiler is not a standalone hybrid toolchain`n$information"
	}

	$release = Join-Path $work 'hello-release.exe'
	Invoke-Compiler 'hello-release' @(
		'-r', '-t', 'Windows-X86-64', '-o', 'hello-release.exe', 'hello.red'
	) | Out-Null
	Assert-StandaloneImage $release 'hello-release'
	Assert-Marker (Invoke-Fixture 'hello-release' $release) `
		'RED-TOOLCHAIN-HERMETIC-OK' 'release Red fixture'

	$o2 = Join-Path $work 'hello-o2.exe'
	Invoke-Compiler 'hello-o2' @(
		'-r', '-O2', '-t', 'Windows-X86-64', '-o', 'hello-o2.exe', 'hello.red'
	) | Out-Null
	Assert-StandaloneImage $o2 'hello-o2'
	Assert-Marker (Invoke-Fixture 'hello-o2' $o2) `
		'RED-TOOLCHAIN-HERMETIC-OK' 'O2 Red fixture'

	$modules = Join-Path $work 'modules.exe'
	Invoke-Compiler 'modules' @(
		'-r', '-t', 'Windows-X86-64', '-o', 'modules.exe', 'modules.red'
	) | Out-Null
	Assert-StandaloneImage $modules 'modules'
	Assert-Marker (Invoke-Fixture 'modules' $modules) `
		'RED-TOOLCHAIN-MODULES-OK' 'embedded module fixture'

	$redSystem = Join-Path $work 'hello-red-system.exe'
	Invoke-Compiler 'hello-red-system' @(
		'-r', '-t', 'Windows-X86-64', '-o', 'hello-red-system.exe', 'hello.reds'
	) | Out-Null
	Assert-StandaloneImage $redSystem 'hello-red-system'
	Assert-Marker (Invoke-Fixture 'hello-red-system' $redSystem) `
		'RED-TOOLCHAIN-REDS-OK' 'Red/System fixture'

	$development = Join-Path $work 'hello-development.exe'
	Invoke-Compiler 'hello-development' @(
		'-t', 'Windows-X86-64', '-o', 'hello-development.exe', 'hello.red'
	) | Out-Null
	$runtime = Join-Path $work 'libRedRT.dll'
	foreach ($required in @(
		$development
		$runtime
		(Join-Path $work 'libRedRT-include.red')
		(Join-Path $work 'libRedRT-defs.red')
	)) {
		if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
			throw "Development compilation did not produce $required"
		}
	}
	Assert-X64PeImage $development $Dumpbin $RunTimeoutSeconds $work `
		(Join-Path $logDirectory 'hello-development-headers.log')
	Assert-X64PeImage $runtime $Dumpbin $RunTimeoutSeconds $work `
		(Join-Path $logDirectory 'libRedRT-headers.log')
	$developmentImports = Get-Imports $development 'hello-development'
	if ($developmentImports -notmatch 'LIBREDRT\.DLL') {
		throw 'Development Red executable does not import libRedRT.dll'
	}
	Assert-Marker (Invoke-Fixture 'hello-development' $development) `
		'RED-TOOLCHAIN-HERMETIC-OK' 'development Red fixture'

	$library = Join-Path $work 'toolchain-library.dll'
	Invoke-Compiler 'toolchain-library' @(
		'-r', '-dlib', '-t', 'Windows-X86-64-DLL',
		'-o', 'toolchain-library.dll', 'library.reds'
	) | Out-Null
	Assert-StandaloneImage $library 'toolchain-library'
	$exports = Get-DumpbinOutput $Dumpbin '/exports' $library $RunTimeoutSeconds $work `
		(Join-Path $logDirectory 'toolchain-library-exports.log')
	if ($exports -notmatch '(?m)\stoolchain-answer\s*$') {
		throw 'Red/System DLL does not export toolchain-answer'
	}
	if (-not ('RedToolchainNativeLoader' -as [type])) {
		Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class RedToolchainNativeLoader {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern IntPtr LoadLibraryW(string path);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool FreeLibrary(IntPtr module);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate int Answer();

    public static int InvokeAnswer(string path) {
        IntPtr module = LoadLibraryW(path);
        if (module == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            IntPtr address = GetProcAddress(module, "toolchain-answer");
            if (address == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            return ((Answer)Marshal.GetDelegateForFunctionPointer(address, typeof(Answer)))();
        } finally {
            if (!FreeLibrary(module)) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
'@
	}
	if ([RedToolchainNativeLoader]::InvokeAnswer($library) -ne 42) {
		throw 'Red/System DLL returned the wrong value'
	}

	$view = Join-Path $work 'view.exe'
	Invoke-Compiler 'view' @(
		'-r', '-t', 'Windows-X86-64', '-o', 'view.exe', 'view.red'
	) | Out-Null
	Assert-StandaloneImage $view 'view'
	$viewOutput = Invoke-Fixture 'view' $view
	$viewMarker = Join-Path $work 'red-toolchain-view.ok'
	if (-not (Test-Path -LiteralPath $viewMarker -PathType Leaf) -or
		(Get-Content -LiteralPath $viewMarker -Raw) -ne 'RED-TOOLCHAIN-VIEW-OK' -or
		$viewOutput -notmatch 'RED-TOOLCHAIN-VIEW-OK') {
		throw "View fixture did not complete successfully`n$viewOutput"
	}

	Write-Host 'Windows x64 hybrid toolchain hermetic test passed.'
	$succeeded = $true
}
finally {
	if ((-not $KeepArtifactsOnFailure -or $succeeded) -and
		(Test-Path -LiteralPath $work -PathType Container)) {
		Remove-VerifiedDirectory $work $temporaryRoot
	} elseif (Test-Path -LiteralPath $work -PathType Container) {
		Write-Warning "Preserved failed toolchain test at $work"
	}
}
