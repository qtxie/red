param(
	[string]$Compiler,
	[string]$Remote = 'macmini',
	[string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) {
	$OutputDir = Join-Path $repo 'build\macos-arm64-view-tests'
}
$outputDir = [System.IO.Path]::GetFullPath($OutputDir)
$name = 'macos-arm64-view-smoke'
$output = Join-Path $outputDir $name
$app = "$output.app"
$archive = Join-Path $outputDir "$name.tar"
$source = Join-Path $repo 'tests\source\view\macos-arm64-smoke.red'

if (-not $Compiler) {
	$Compiler = Get-ChildItem (Join-Path $repo 'build\self-hosting') `
		-Filter 'red-bootstrap-stage1-darwin-arm64*.exe' -File |
		Sort-Object LastWriteTime -Descending |
		Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Compiler -or -not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
	throw 'A Stage1 Darwin ARM64 compiler is required'
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Remove-Item -LiteralPath $app -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $output,$archive -Force -ErrorAction SilentlyContinue

& $Compiler -d -t macOS-ARM64 -o $output $source
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $app -PathType Container)) {
	throw "macOS ARM64 View compilation failed with exit code $LASTEXITCODE"
}

$bundleExecutable = Join-Path $app "Contents\MacOS\$name"
$bundleRuntime = Join-Path $app 'Contents\MacOS\libRedRT.dylib'
$bundleResources = Join-Path $app 'Contents\_CodeSignature\CodeResources'
foreach ($file in @($bundleExecutable, $bundleRuntime, (Join-Path $app 'Contents\Info.plist'), $bundleResources)) {
	if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
		throw "Bundle artifact is missing: $file"
	}
}

$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
& $tar -cf $archive -C $outputDir "$name.app"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
	throw 'Failed to package the macOS ARM64 View bundle'
}

$remoteDir = (& ssh $Remote 'mktemp -d /tmp/red-macos-arm64-view.XXXXXX').Trim()
if ($LASTEXITCODE -ne 0 -or $remoteDir -notmatch '^/tmp/red-macos-arm64-view\.[A-Za-z0-9]+$') {
	throw "Failed to create a safe remote test directory: $remoteDir"
}

try {
	$copied = $false
	foreach ($attempt in 1..3) {
		& scp -O -o ConnectTimeout=10 $archive "${Remote}:$remoteDir/$name.tar"
		if ($LASTEXITCODE -eq 0) {
			$copied = $true
			break
		}
		if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
	}
	if (-not $copied) { throw 'Failed to copy the macOS ARM64 View bundle' }

	$command = @"
set -eu
cd '$remoteDir'
tar -xf '$name.tar'
exe='$name.app/Contents/MacOS/$name'
runtime='$name.app/Contents/MacOS/libRedRT.dylib'
chmod 755 "`$exe" "`$runtime"
test "`$(uname -m)" = arm64
file "`$exe" | grep -q 'Mach-O 64-bit executable arm64'
file "`$runtime" | grep -q 'Mach-O 64-bit dynamically linked shared library arm64'
otool -L "`$exe" | grep -q '@loader_path/libRedRT.dylib'
otool -L "`$runtime" | grep -q 'AppKit.framework'
otool -D "`$runtime" | grep -q '@rpath/libRedRT.dylib'
dyld_info -validate_only "`$exe"
dyld_info -validate_only "`$runtime"
cp "`$runtime" '$name-runtime-signature-probe.dylib'
codesign --verify --strict --verbose=4 '$name-runtime-signature-probe.dylib'
rm '$name-runtime-signature-probe.dylib'
plutil -lint '$name.app/Contents/Info.plist'
plutil -lint '$name.app/Contents/_CodeSignature/CodeResources'
codesign --verify --deep --strict --verbose=4 '$name.app'
signature_details=`$(codesign --display --verbose=4 '$name.app' 2>&1)
printf '%s\n' "`$signature_details" | grep -q 'Identifier=org.redlang.$name'
printf '%s\n' "`$signature_details" | grep -q 'Hash choices=sha1,sha256'
printf '%s\n' "`$signature_details" | grep -q 'Signature=adhoc'
printf '%s\n' "`$signature_details" | grep -q 'Sealed Resources version=2'

console_user=`$(stat -f %Su /dev/console)
ssh_user=`$(id -un)
if test "`$console_user" != "`$ssh_user"; then
  printf 'Static View validation passed; GUI run skipped (console user %s, SSH user %s).\n' "`$console_user" "`$ssh_user"
  exit 0
fi

rm -f macos-arm64-view-smoke.ok macos-arm64-view-smoke.error
./"`$exe"
test "`$(cat macos-arm64-view-smoke.ok)" = MACOS-ARM64-VIEW-OK
"@
	& ssh $Remote $command
	if ($LASTEXITCODE -ne 0) { throw 'macOS ARM64 View validation failed on the remote runner' }
}
finally {
	if ($remoteDir -match '^/tmp/red-macos-arm64-view\.[A-Za-z0-9]+$') {
		& ssh $Remote "rm -rf '$remoteDir'" | Out-Null
	}
}

Write-Host "macOS ARM64 Stage1 View validation passed on $Remote."
