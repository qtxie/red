# Handover: Windows x64 self-hosted compiler cutover

**Date:** 2026-07-30
**Branch:** `red-64`
**Source commit:** `d1a7cb976a89e282330bdbf2401eefbb5a3431c7`
**Canonical compiler:** `build/self-hosting/red-bootstrap-stage1-x64-gc-fixed.exe`
**Compiler SHA-256:** `4916BF13E1E9DD52582364C990D1C96AACE96DCD74746AE341CB36FC49FEE589`
**Development runtime:** `libRedRT.dll`
**Runtime SHA-256:** `D3DB5807A072CDBBCD84B3172A7D077592093837016B895006479579708FDB73`

## Compiler policy

The Rebol-hosted Stage0 compiler is retired from normal development. All normal
Windows x64 compiler, runtime, and test work uses the canonical self-hosted
compiler above. The filename retains `stage1` for compatibility with local
commands, but its contents are the tested Stage5 fixed-point candidate.

The original GC-on recovery seed is preserved as:

`build/self-hosting/red-bootstrap-recovery-seed-x64-gc-fixed.exe`

Its SHA-256 is
`13476CD765F640E975DEA357FA2F6B425C6AD49A9E90770FEEAC07A0BCF4BDC0`.
It was built by Stage0 during the explicitly requested recovery and must only be
used for disaster recovery or a requested historical audit. Do not invoke
`red.r` through a Rebol executable during normal builds, tests, or debugging.

## Fixed-point evidence

The compiler generation used for the final comparison is:

| Generation | Built by | SHA-256 |
| --- | --- | --- |
| Stage4 | Stage3 | `6ADF563DCBD1FBE0E602F5D8489CA9DACCF951ABE14B777459BBDCF5EAE9C8EE` |
| Stage5 | Stage4 | `4916BF13E1E9DD52582364C990D1C96AACE96DCD74746AE341CB36FC49FEE589` |

Both images are 6,156,288 bytes. Only eight bytes differ:

- PE timestamp: offsets `0x88` and `0x89`
- PE checksum: offsets `0xD8` and `0xD9`
- embedded output filename digit: offset `0x5010A6`
- embedded build-time digits: offsets `0x5C764A`, `0x5C764C`, and `0x5C764D`

After zeroing only those eight build-specific bytes, both images have SHA-256
`449399816A98AB2CF9044E35FF1926394640D68FC2911F5E0E146AE3CA7CB4F8`.
All generated code and non-build-specific data are byte-identical.

## Verified baseline

| Gate | Result |
| --- | --- |
| Stage5 image | PE32+ x64 (`8664`) |
| Stage5 startup GC | active; 541 cycles while building Stage5 |
| Stage5 fixed point | Stage4/Stage5 normalized images identical |
| Red unit suite, development mode | 59 programs; 8,802 tests; 16,850/16,850 assertions |
| Red/System Windows x64 suite | 10,575 tests; 12,640/12,640 assertions |
| Stage5-built `libRedRT.dll` | PE32+ x64; View, CSV, and JSON included |
| Stage5 runtime GC | active; 367 cycles while building `libRedRT.dll` |

The Red runner's configured non-View list currently contains 59 source files.
The earlier handover's claim of 60 files was a counting error; the aggregate
test and assertion totals above are from the runner itself.

## Standard commands

Set the canonical compiler once in PowerShell:

```powershell
$compiler = Resolve-Path .\build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe
```

Compile a release Red or Red/System program:

```powershell
& $compiler -r -d -t Windows-X86-64 -o <output> <source>
```

Compile in development mode using the Stage5-built `libRedRT.dll`:

```powershell
& $compiler -d -t Windows-X86-64 -o <output> <source>
```

Rebuild the development runtime:

```powershell
& $compiler -d -t Windows-X86-64 -o libRedRT.dll `
    build\self-hosting\stage1-libredrt.red
```

Build the next compiler generation:

```powershell
& $compiler -r -d -t Windows-X86-64 `
    -o build\self-hosting\red-bootstrap-stage6-x64.exe `
    red.red
```

`red.red` is the official Red-only command-line entrypoint. It selects the
hybrid Red/System backend, defaults to development mode, and accepts `-r` for
release builds. `red-bootstrap-windows.red` remains available as a
transitional target wrapper for older bootstrap binaries.

Run the development-mode Red suite:

```powershell
$env:RED_COMPILER = $compiler
$env:RED_COMPILER_ARGUMENTS = '-t Windows-X86-64'
& D:\EE\QTool\red-console.exe .\tools\self_hosting\run-red-unit-tests.red
```

Run the Windows x64 Red/System suite:

```powershell
$env:RED_SYSTEM_COMPILER = $compiler
$env:RED_SYSTEM_COMPILER_ARGUMENTS = '-t Windows-X86-64'
$env:RED_SYSTEM_STRUCTLIB = Resolve-Path .\build\self-hosting\structlib-x64.dll
& D:\EE\QTool\red-console.exe .\tools\self_hosting\run-red-system-tests.red
```

`red-console.exe` only hosts the Red test-runner scripts. Check for a stale
process after a runner exits.

## Remaining work

1. Publish the checksummed compiler and runtime where clean CI checkouts can
   retrieve them. The binaries are currently ignored local artifacts.
2. Replace the Rebol bootstrap in Windows CI with the published self-hosted
   compiler and the runners under `tools/self_hosting/`.
3. Cross-compile and run the ARM and ARM64 suites on `ssh armbian` using the
   self-hosted compiler. macOS support remains deferred.
4. Port or retire remaining normal-path `.r` build and test entry points.

## Relevant files

| Area | Path |
| --- | --- |
| Official compiler entrypoint | `red.red` |
| Transitional bootstrap wrapper | `red-bootstrap-windows.red` |
| Bootstrap driver | `compiler/bootstrap-driver.red` |
| Red frontend | `compiler/frontend.red` |
| Red/System compiler | `system/compiler-core.red` |
| Windows x64 target | `system/targets/X86-64.red` |
| Runtime export builder | `system/utils/libRedRT.red` |
| Runtime build driver | `build/self-hosting/stage1-libredrt.red` |
| Red unit runner | `tools/self_hosting/run-red-unit-tests.red` |
| Red/System unit runner | `tools/self_hosting/run-red-system-tests.red` |
| Long-term migration plan | `red-self-hosting-plan.md` |
