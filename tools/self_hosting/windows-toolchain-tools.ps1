Set-StrictMode -Version Latest

function Resolve-ToolchainPath {
	param(
		[Parameter(Mandatory)][string]$Path,
		[Parameter(Mandatory)][string]$BasePath,
		[switch]$MustExist
	)

	$absolute = if ([System.IO.Path]::IsPathRooted($Path)) {
		[System.IO.Path]::GetFullPath($Path)
	} else {
		[System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
	}
	if ($MustExist) {
		if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
			throw "File not found: $absolute"
		}
		return (Resolve-Path -LiteralPath $absolute).Path
	}
	$absolute
}

function ConvertTo-RedPath {
	param([Parameter(Mandatory)][string]$Path)

	$value = [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
	if ($value -match '^([A-Za-z]):/(.*)$') {
		return "/$($Matches[1])/$($Matches[2])"
	}
	$value
}

function ConvertTo-NativeArgument {
	param([AllowEmptyString()][string]$Argument)

	if ($Argument.Length -eq 0) { return '""' }
	if ($Argument -notmatch '[\s"]') { return $Argument }
	$builder = [System.Text.StringBuilder]::new()
	$null = $builder.Append('"')
	$slashes = 0
	foreach ($character in $Argument.ToCharArray()) {
		if ($character -eq '\') {
			$slashes++
			continue
		}
		if ($character -eq '"') {
			$null = $builder.Append(('\' * (($slashes * 2) + 1)))
			$null = $builder.Append('"')
			$slashes = 0
			continue
		}
		if ($slashes -gt 0) {
			$null = $builder.Append(('\' * $slashes))
			$slashes = 0
		}
		$null = $builder.Append($character)
	}
	if ($slashes -gt 0) { $null = $builder.Append(('\' * ($slashes * 2))) }
	$null = $builder.Append('"')
	$builder.ToString()
}

function Write-ToolchainLog {
	param(
		[string]$Path,
		[AllowEmptyString()][string]$Content
	)

	if (-not $Path) { return }
	$directory = Split-Path -Parent $Path
	if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
	[System.IO.File]::WriteAllText(
		[System.IO.Path]::GetFullPath($Path),
		$Content,
		[System.Text.UTF8Encoding]::new($false)
	)
}

function Invoke-ToolchainProcess {
	param(
		[Parameter(Mandatory)][string]$FilePath,
		[string[]]$ArgumentList = @(),
		[Parameter(Mandatory)][int]$TimeoutSeconds,
		[Parameter(Mandatory)][string]$WorkingDirectory,
		[string]$OutputPath,
		[string]$ErrorPath,
		[hashtable]$Environment = @{}
	)

	$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
	$startInfo.FileName = $FilePath
	$startInfo.WorkingDirectory = $WorkingDirectory
	$startInfo.UseShellExecute = $false
	$startInfo.CreateNoWindow = $true
	$startInfo.RedirectStandardOutput = $true
	$startInfo.RedirectStandardError = $true
	foreach ($name in $Environment.Keys) {
		$startInfo.Environment[$name] = [string]$Environment[$name]
	}
	if ($null -ne $startInfo.ArgumentList) {
		foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }
	} else {
		$startInfo.Arguments = ($ArgumentList | ForEach-Object {
			ConvertTo-NativeArgument $_
		}) -join ' '
	}

	$process = [System.Diagnostics.Process]::new()
	$process.StartInfo = $startInfo
	try {
		if (-not $process.Start()) { throw "Unable to start $FilePath" }
		$stdoutTask = $process.StandardOutput.ReadToEndAsync()
		$stderrTask = $process.StandardError.ReadToEndAsync()
		if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
			try { $process.Kill($true) } catch { $process.Kill() }
			$process.WaitForExit()
			throw "$FilePath timed out after $TimeoutSeconds seconds"
		}
		$process.WaitForExit()
		$stdout = $stdoutTask.GetAwaiter().GetResult()
		$stderr = $stderrTask.GetAwaiter().GetResult()
		Write-ToolchainLog $OutputPath $stdout
		Write-ToolchainLog $ErrorPath $stderr
		$output = $stdout + $stderr
		if ($process.ExitCode -ne 0) {
			throw "$FilePath exited with $($process.ExitCode)`n$output"
		}
		$output
	}
	finally {
		$process.Dispose()
	}
}

function Get-ToolchainSourceDateEpoch {
	param([Parameter(Mandatory)][string]$RepositoryRoot)

	$value = $env:SOURCE_DATE_EPOCH
	if (-not $value) {
		$git = Get-Command git.exe -ErrorAction SilentlyContinue
		if ($git) {
			$gitOutput = @(& $git.Source -C $RepositoryRoot log -1 --format=%ct 2>$null)
			if ($LASTEXITCODE -eq 0) { $value = ($gitOutput -join '').Trim() }
		}
	}
	$parsed = 0L
	if (-not $value -or
		-not [long]::TryParse($value, [ref]$parsed) -or
		$parsed -lt 0) {
		throw 'Set SOURCE_DATE_EPOCH to a non-negative integer when a Git commit timestamp is unavailable'
	}
	$parsed.ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-ToolchainDumpbin {
	param([string]$Path)

	if ($Path) {
		return Resolve-ToolchainPath $Path (Get-Location).Path -MustExist
	}
	if ($env:RED_TEST_DUMPBIN) {
		return Resolve-ToolchainPath $env:RED_TEST_DUMPBIN (Get-Location).Path -MustExist
	}
	$command = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
	if ($command) { return $command.Source }
	$vswhere = Get-Command vswhere.exe -ErrorAction SilentlyContinue
	$vswherePath = if ($vswhere) { $vswhere.Source } else { $null }
	if (-not $vswherePath) {
		$candidate = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			$vswherePath = (Resolve-Path -LiteralPath $candidate).Path
		}
	}
	if ($vswherePath) {
		$matches = @(& $vswherePath -latest -products * `
			-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
			-find 'VC\Tools\MSVC\**\bin\Hostx64\x64\dumpbin.exe')
		$match = $matches | Where-Object {
			Test-Path -LiteralPath $_ -PathType Leaf
		} | Select-Object -First 1
		if ($match) { return (Resolve-Path -LiteralPath $match).Path }
	}
	throw 'dumpbin.exe was not found; pass -Dumpbin or set RED_TEST_DUMPBIN'
}

function Get-DumpbinOutput {
	param(
		[Parameter(Mandatory)][string]$Dumpbin,
		[Parameter(Mandatory)][string]$Mode,
		[Parameter(Mandatory)][string]$Image,
		[Parameter(Mandatory)][int]$TimeoutSeconds,
		[Parameter(Mandatory)][string]$WorkingDirectory,
		[string]$LogPath
	)

	Invoke-ToolchainProcess $Dumpbin @($Mode, $Image) $TimeoutSeconds `
		$WorkingDirectory $LogPath
}

function Assert-X64PeImage {
	param(
		[Parameter(Mandatory)][string]$Image,
		[Parameter(Mandatory)][string]$Dumpbin,
		[Parameter(Mandatory)][int]$TimeoutSeconds,
		[Parameter(Mandatory)][string]$WorkingDirectory,
		[Parameter(Mandatory)][string]$LogPath
	)

	if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) {
		throw "PE image not found: $Image"
	}
	$headers = Get-DumpbinOutput $Dumpbin '/headers' $Image $TimeoutSeconds `
		$WorkingDirectory $LogPath
	if ($headers -notmatch '8664 machine \(x64\)') { throw "$Image is not x64" }
	if ($headers -notmatch '20B magic # \(PE32\+\)') { throw "$Image is not PE32+" }
	if ($headers -notmatch 'Dynamic base') { throw "$Image is not dynamic-base" }
	if ($headers -notmatch 'NX compatible') { throw "$Image is not NX-compatible" }
}

function Remove-VerifiedDirectory {
	param(
		[Parameter(Mandatory)][string]$Path,
		[Parameter(Mandatory)][string]$AllowedRoot
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
	$resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
	$root = [System.IO.Path]::GetFullPath($AllowedRoot)
	$prefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
	if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to remove directory outside $root`: $resolved"
	}
	Remove-Item -LiteralPath $resolved -Recurse -Force
}
