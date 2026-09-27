# Run suite runners through the harness console and gate on what they return.
#
# Every Windows suite job calls this instead of writing its own gate, because
# the naive form passes without ever running the console. PowerShell resolves an
# extensionless path as a *document*: ShellExecute reports success, no process
# starts, $LASTEXITCODE stays unset, and `exit $null` is exit 0. Two defences
# follow, and this script is the second one -- setup-red-harness proves the
# console runs before any job gets here, and an unset exit code below is a
# failure rather than a zero.
param(
	[Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
	[string[]]$Runners
)

$ErrorActionPreference = 'Stop'
# A throwing native command would stop a multi-runner job after its first
# failure, and the gate below is what reports failures here.
$PSNativeCommandUseErrorActionPreference = $false

if (-not $env:RED_CONSOLE) { throw 'RED_CONSOLE is not set; run setup-red-harness first' }

$failed = @()
foreach ($runner in $Runners) {
	& $env:RED_CONSOLE $runner
	if ($null -eq $LASTEXITCODE) {
		Write-Host "::error::$runner -- the console reported no exit code, so it never ran"
		$failed += $runner
	}
	elseif ($LASTEXITCODE -ne 0) {
		Write-Host "::error::$runner failed with exit code $LASTEXITCODE"
		$failed += $runner
	}
}
if ($failed.Count -gt 0) {
	Write-Host "::error::$($failed.Count) of $($Runners.Count) runners failed: $($failed -join ', ')"
	exit 1
}
