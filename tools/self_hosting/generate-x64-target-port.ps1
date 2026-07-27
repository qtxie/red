$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$source = Get-Content (Join-Path $root 'system\targets\X86-64.r') -Raw
$body = Get-Content (Join-Path $root 'system\targets\target-class-body.red') -Raw

$body = [regex]::Replace($body, '(?s)^.*?\]\s*', '')
$body = $body.Trim()
$body = $body -replace 'compiler-api/last-type/1', '(first compiler-api/last-type)'
$archStart = $source.IndexOf("target: 'X86-64")
if ($archStart -lt 0) { throw 'x64 target body marker not found' }
$arch = $source.Substring($archStart).Trim()

# The Red-hosted emitter exposes compiler state through compiler-api. Keep the
# target implementation's behavior and translate only the host-object paths.
$arch = $arch -replace '\bcompiler/last-type:', 'compiler-api/set-last-type '
$arch = $arch -replace '\bcompiler/last-type\b', 'compiler-api/last-type'
$arch = $arch -replace '\bcompiler/job/([A-Za-z0-9?_-]+)', 'compiler-api/job-value ''$1'
$arch = $arch -replace '\bcompiler/([A-Za-z0-9?_-]+)', 'compiler-api/$1'
$arch = [regex]::Replace($arch, "compiler-api/job-value '([A-Za-z0-9?_-]+)", {
	param($match)
	"(compiler-api/job-value '" + $match.Groups[1].Value + ")"
})
$arch = $arch -replace '/routine name', '/routine-call name'
$arch = $arch -replace '\bif routine \[', 'if routine-call ['
$arch = $arch -replace '\beither routine \[', 'either routine-call ['
$arch = $arch -replace '\bdecimal\?', 'float?'
$arch = $arch -replace '\bto-bin8\b', 'int-to-bin/to-bin8'
$arch = $arch -replace '\bto-bin16\b', 'int-to-bin/to-bin16'
$arch = $arch -replace '\bto-bin32\b', 'int-to-bin/to-bin32'
$arch = $arch -replace '\bto-bin64\b', 'int-to-bin/to-bin64'
$arch = $arch -replace '(?m)^\s*/sysv type \[block!\]', "`t`t/sysv type [block!]`r`n`t`t/aggregate aggregate-spec [block!]`r`n`t`t/returned"
$arch = $arch -replace 'if logic\? value \[value: to integer! value\]', 'if logic? value [value: either value [1][0]]'
$arch = $arch -replace 'if logic\? right \[right: to integer! right\]', 'if logic? right [right: either right [1][0]]'
$arch = $arch -replace 'compiler-api/last-type/1', '(first compiler-api/last-type)'
$arch = $arch -replace '\btrue\b', 'yes'
$arch = $arch -replace '\bfalse\b', 'no'

$header = @'
Red [
	Title:   "Red/System x86-64 code emitter"
	Author:  "Red Foundation"
	File:    %X86-64.red
	Tabs:    4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

'@
$content = $header + "system-target-X86-64: context [`r`n" + $body + "`r`n`r`n" + "homogeneous-floats?: func [spec [block!]][reduce [no 0]]`r`n`r`n" + $arch + "`r`n"
$content = $content -replace "`r`n", "`n"
Set-Content -LiteralPath (Join-Path $root 'system\targets\X86-64.red') -Value $content -Encoding UTF8 -NoNewline
Write-Host "generated x64 target: $((Get-Item (Join-Path $root 'system\targets\X86-64.red')).Length) bytes"
