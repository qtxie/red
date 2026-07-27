# Handover: Windows x64 GC-on Stage1 cutover

**Date:** 2026-07-27
**Branch:** `red-64`
**Baseline commit:** `22a832e95` - Windows x64 Stage1 passes Red tests
**Bootstrap compiler:** `build/self-hosting/red-bootstrap-stage1-x64-gc-fixed.exe`
**Bootstrap SHA-256:** `13476CD765F640E975DEA357FA2F6B425C6AD49A9E90770FEEAC07A0BCF4BDC0`
**Development runtime:** `libRedRT.dll`

## Compiler policy

The Rebol-hosted Stage0 compiler is retired from normal development. All next
compiler, runtime, and test work must be compiled by the Windows x64 Stage1
compiler above.

The current seed was rebuilt once with the old Rebol Stage0 compiler after the
previous `fixed24` driver was found to call `recycle/off`. The replacement calls
`recycle/on`, fixes global case-alias emission, and is the active seed. This was
an explicitly requested recovery build, not a return to Stage0 for normal work.

The one-time recovery command was:

```powershell
cmd /c D:\EE\QTool\rebcmdview.exe -cqs .\red.r -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe `
    red-bootstrap-windows.red
```

- Do not invoke `red.r` through `rebcmdview.exe` for normal builds or tests.
- Treat the current x64 Stage1 executable as the bootstrap seed.
- The next compiler built from source is Stage2, not another Stage1.
- Rebuild `libRedRT.dll` with Stage1 whenever development-mode runtime code
  changes.
- Keep Rebol Stage0 only as an explicit disaster-recovery or historical audit
  tool. Using it requires a deliberate request; it is not a parity gate.
- When an old algorithm is useful, inspect the committed `.r` source or Git
  history. Do not execute Stage0 merely to copy its output.

This cutover currently applies to Windows x64. Other targets must be brought
into the Red-hosted compiler rather than restoring Stage0 to the main workflow.

## Verified baseline

| Gate | Result |
| --- | --- |
| Stage1 image | PE32+ x64 (`8664`) |
| Stage1 startup GC | active; 243 cycles in release `points-test` compilation |
| Red unit suite, development mode | 8,801 tests; 16,849/16,849 assertions |
| Red/System Windows x64 suite | 10,575 tests; 12,640/12,640 assertions |
| `points-test`, release mode | 142/142 assertions |
| Stage1 builds Stage2 | complete; 635 GC cycles; Stage2 starts successfully |
| Stage1-built `libRedRT.dll` | PE32+ x64; CSV and JSON included |

The Red suite covers all 60 non-View unit files in
`tools/self_hosting/run-red-unit-tests.red`. The Red/System runner selects
`struct-x64-test.reds` and `size-x64-test.reds` and uses an x64 `structlib.dll`.

## Standard commands

Set the compiler once in PowerShell:

```powershell
$stage1 = Resolve-Path .\build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe
```

Compile a release Red or Red/System program:

```powershell
& $stage1 -r -d -t Windows-X86-64 -o <output> <source>
```

Compile in development mode using `libRedRT.dll`:

```powershell
& $stage1 -d -t Windows-X86-64 -o <output> <source>
```

Build Stage2 from the current sources:

```powershell
& $stage1 -r -d -t Windows-X86-64 `
    -o build\self-hosting\red-bootstrap-stage2-x64-gc-fixed.exe `
    red-bootstrap-windows.red
```

Rebuild the x64 development runtime with Stage1:

```powershell
& $stage1 -d -t Windows-X86-64 -o libRedRT.dll `
    build\self-hosting\stage1-libredrt.red
```

Run all Red unit tests in development mode:

```powershell
$env:RED_COMPILER = $stage1
$env:RED_COMPILER_ARGUMENTS = '-t Windows-X86-64'
& D:\EE\QTool\red-console.exe .\tools\self_hosting\run-red-unit-tests.red
```

Run the Windows x64 Red/System suite:

```powershell
$env:RED_SYSTEM_COMPILER = $stage1
$env:RED_SYSTEM_COMPILER_ARGUMENTS = '-t Windows-X86-64'
$env:RED_SYSTEM_STRUCTLIB = Resolve-Path .\build\self-hosting\structlib-x64.dll
& D:\EE\QTool\red-console.exe .\tools\self_hosting\run-red-system-tests.red
```

`red-console.exe` is only the test-runner host here; it is not compiling the
test programs. Watch it for a hung process after the runner exits.

## Next work

1. Rebuild `libRedRT.dll` with Stage2 and rerun both complete suites.
2. Build Stage3 with Stage2 and compare Stage2/Stage3 expanded source, Red/System
   output, relocations, and final PE images after normalizing only documented
   metadata.
3. Give the bootstrap seed a stable artifact name in artifact storage and record
   its source commit, build command, and test totals beside the checksum above.
4. Remove remaining normal-path `.r` loads and Rebol executable references from
   build, test, and CI entry points.
5. Port additional targets into the Red-hosted compiler without reintroducing a
   Stage0 dependency.

## Relevant files

| Area | Path |
| --- | --- |
| Bootstrap driver | `red-bootstrap-windows.red` |
| Red frontend | `compiler/frontend.red` |
| Red/System compiler | `system/compiler-core.red` |
| Windows x64 target | `system/targets/X86-64.red` |
| Stage1 runtime export builder | `system/utils/libRedRT.red` |
| Red unit runner | `tools/self_hosting/run-red-unit-tests.red` |
| Red/System unit runner | `tools/self_hosting/run-red-system-tests.red` |
| Long-term migration plan | `red-self-hosting-plan.md` |
