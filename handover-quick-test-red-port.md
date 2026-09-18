# Handover: porting the Red test harness off Rebol

## Paste-ready resume prompt

> Continue the work described in `red-quick-test-port-plan.md` and
> `handover-quick-test-red-port.md`.
>
> Goal: retire Rebol from the test harness. Rebol cannot run on ARM64, so the
> Rebol Quick-Test driver (`quick-test/quick-test.r`) and every runner that
> `do`es it can never execute on a native ARM64 CI runner. The harness is being
> ported to Red and run with the Red CLI console
> (`D:\EE\QTool\red-console.exe`).
>
> Phase A is complete and Phase B is nearly complete: `qt-runner.red` exists,
> four runners are thin clients of it, and 27 Rebol test scripts have been
> ported to `.red` beside their `.r` originals (which are deliberately left in
> place so the Rebol path stays green during the transition). Do NOT reintroduce
> the `transcode` + Rebol-compatibility-shim loading that
> `run-red-system-compiler-tests.red` used to do — the shim defined
> `change-dir` as a no-op, so scripts ran in the wrong directory. Port directly.
>
> Next step: finish Phase B by porting the headless View suite
> (`tests/run-view-headless-tests.r`, 193 lines) to a Red runner. The driver
> already has the `qt/run/with` refinement it needs; nothing calls it yet.
>
> Then Phase C (retire the Rebol entry points), Phase D (rewrite the workflows
> to run `red-console.exe <runner>` with `RED_*` env vars — this is where the
> earlier `--binary` plumbing gets deleted), Phase E (cutover).
>
> Constraints: the real packaged toolchain at
> `build/red-toolchain/windows-x64/red-toolchain.exe` SEGFAULTS on every
> invocation, so validate with a fake compiler (see "How to test" below).
> Always `timeout` red-console: it leaves a stale process behind.
> Read `AGENTS.md` first.

## Why this work exists

Rebol cannot run on ARM64. That is a gap in the **test driver**, not in the
hybrid toolchain: `quick-test/quick-test.r` is Rebol, so `ARM64.yml` and
`macOS-ARM64.yml` cannot execute the harness on `ubuntu-24.04-arm` or
`macos-15` no matter which compiler is injected. Injecting `--binary` fixes
*which compiler* the tests use; it does not fix *what runs the tests*.

Red compiles to all four hybrid targets, so a Red driver runs natively there.

## Where things stand

| Phase | State |
| --- | --- |
| A — build the driver, consolidate runners | **done** |
| B — port the Rebol test scripts | **done** |
| C — retire the Rebol entry points | **done** |
| D — rewrite the workflows | **done** |
| E — validation and cutover | not started |

Separately, an earlier effort (superseded by this plan) added `--binary`
compiler-injection plumbing to the Rebol runners and `quick-test.r`. Those 17
modified files are still in the tree. They are the interim path for the Windows
and Linux-x64 jobs and are deleted in Phase D, once a job runs a Red runner and
takes its compiler from `RED_COMPILER` instead.

## Files

**Driver (new):**
- `tools/self_hosting/qt-runner.red` — the Red Quick-Test driver. A `qt`
  context holds state (`comp-output`, `output`, `compile-ok?`, totals) because
  the test scripts reference `qt/...` directly; the test DSL (`--assert`,
  `--compiled?`, `--compile-this-red`, `--test--`, file/group markers) is
  global so scripts pulled in with `do %file.red` see it.

**Runners (all thin clients of the driver):**
- `run-red-unit-tests.red` — 57 Red units (`RED_COMPILER`)
- `run-red-system-tests.red` — 43 Red/System units (`RED_SYSTEM_COMPILER`,
  `RED_SYSTEM_STRUCTLIB`)
- `run-red-system-compiler-tests.red` — 19 Red/System compiler scripts
- `run-red-compiler-tests.red` — **new**, 9 Red compiler scripts
- `run-red-view-headless-tests.red` — **new**, 16 `tests/source/view/*.red`
  files run through the once-compiled `tests/view-headless-interpreter.red`

**Ported scripts (new `.red` beside the `.r` original):**
- `system/tests/source/compiler/` — 19 files
- `tests/source/compiler/` — 9 files (`regression-test-redc-1..5`,
  `compile-error-test`, `run-time-error-test`, `print-test`,
  `preprocessor-test`)

All 28 `load` as valid Red with zero errors.

**Not ported:** `tests/source/compiler/lexer-test.r`. It `do`es
`%../../../encapper/lexer.r` and asserts on `lexer/process`, so it tests a
*Rebol* implementation; Red's own lexer is already covered by
`tests/source/units/lexer-test.red` (58 KB), which `run-red-unit-tests.red`
runs. `preprocessor-test.r` was the opposite case and *was* ported.

## Phase C: what got deleted

59 Rebol files. `git status` is the authoritative list; in summary:

- the driver `quick-test/quick-test.r` and `quick-unit-test.r` / `run-test.r` /
  `tests/qt-test.r`;
- every entry point: `run-all-tests*.r`, `tests/run-{all,all-together,all-tests-common,core-tests,regression-tests,view-tests,view-headless-tests}.r`,
  both `build-arm-tests.r`, `system/tests/run-all.r`;
- the four `tests/source/units/run-*-init.r` / `run-{pre,post}-extra-tests.r`
  phases those entry points pulled in;
- the 28 `.r` originals of the ported scripts;
- the Rebol dylib tooling (`make-dylib-auto-test.r`, `create-dylib-auto-test.r`,
  `compile-test-dylibs.r`, `make-red-system-auto-tests.r`,
  `prepare-dependencies.r`, `run-float.r`) and the two Red-side generators that
  `do`ne the deleted driver.

Uncommitted `--binary` plumbing in 13 of them was saved to
`local/phase2-binary-plumbing.patch` before the forced `git rm` (delete it once
Phase D lands).

### The dylib generator had to be ported first

`system/tests/source/units/auto-tests/dylib-auto-test.reds` was generated by
three Rebol scripts, so the Red/System suite still needed Rebol after the entry
points were gone. `run-red-system-tests.red` now builds it from the same four
`dylib-*.txt` templates. One deliberate difference from the Rebol generator: the
`#import` block always names the DLLs by absolute path instead of using a bare
name on Windows, because a compiled test runs from the repo root rather than
from the output directory the DLLs are emitted into.

### Coverage

- Kept: `tests/source/runtime/unicode-test.red` and
  `tests/source/runtime/tools-test.reds` were only reachable through the deleted
  pre/post-extra phases; they are now folded into `run-red-unit-tests.red` and
  `run-red-system-tests.red`.
- Dropped: `tests/source/view/base-self-test.red` had exactly one runner,
  `tests/run-view-tests.r`, and wants a real GUI backend. It stays in the tree
  with no runner.
- Dead but unbroken: `tests/source/library/call-test.r` and the
  `make-*-auto-test*.r` generators no runner calls.

## Port recipe

Mechanical, then hand-fixed:

```
REBOL [            -> Red [
delete `change-dir %../`        (the driver sets cwd to the repo root)
found? find        -> not none? find
reform [           -> rejoin [
join "*** X: " v   -> rejoin ["*** X: " v]
```

`dylib-test.r` needed a hand port: its `fourth system/version` platform switch
has no Red equivalent, so it uses `qt/target`.

## Red semantics that cost real debugging time

These are the reasons the port could not be done by inspection. All were found
by running the harness.

- **`do %file` change-dir's into that file's directory**, and resolves relative
  paths against `system/options/path` (the *runner's* directory), not the
  working directory. Save/restore `what-dir` around every `do`.
- **Red file operations resolve relative paths against `system/options/path`
  too.** `make-dir` with a relative path silently returns the argument and
  creates nothing. The driver's `absolute` / `out-path` / `local-path` exist for
  this; use them everywhere.
- The absolute-path test must accept a drive letter (`E:/...`, from an env var),
  not just a leading `/`.
- `#include` under the interpreter becomes `do`, which **requires a Red
  header** in the included file.
- **Red has no `join`** — the old shim supplied it. Use `rejoin`.
- `to logic! none` does not yield a logic. `--assert --compile-and-run` passes
  `none` when the compile fails, so `record-assertion` coerces.
- **`bug$0` is a money! literal**, and Red validates currency codes at load
  time, so it cannot appear in script code (only inside string payloads, where
  the tests are in fact testing currency lexing).
- Scripts set `qt/compile-flag` and `qt/source-file?`, and read the globals
  `qt-temp-file` / `qt-tmp-file` / `qt-temp-dir` / `qt-tmp-dir`. Setting an
  unknown field on the `qt` context raises `invalid-path`, so the driver must
  declare all of them.
- `--compile-and-run-this/error` and `--compile-and-run/pgm` refinements are
  used; `/error` can be accepted and ignored (the driver never counts a runtime
  error as a failure).
- Red sources from a string need a `.red` file and a `Red []` header inserted
  when absent; Red/System ones need `.reds` / `Red/System []`.
- `call/wait/output/error` works and separates stderr — the old
  `> log 2>&1` shell redirection is unnecessary.
- **`parse <string> " "` is rejected** (`parse does not allow string! for its
  rules argument`). Use `split <string> " "`. Every runner copied the Rebol
  spelling from `quick-test.r`, and `any` short-circuits on the target env
  var, so the bug only bites when `RED_TARGET` / `RED_SYSTEM_TARGET` is unset
  and the runner has to recover the target from
  `RED_*_COMPILER_ARGUMENTS` — exactly what a Phase D workflow that sets only
  the arguments would do. All five runners and the driver's `qt/target-flag`
  now use `split`.

## How to test

The real toolchain binary is broken locally, so drive the suites with a fake
compiler. Create `local/fake-rs-compiler.cmd`:

```bat
@echo off
setlocal enabledelayedexpansion
set OUT=
set PREV=
for %%a in (%*) do (
	if "!PREV!"=="-o" set OUT=%%~a
	set PREV=%%a
)
if defined OUT (echo fake-binary> "!OUT!")
exit /b 0
```

That fake is enough for the compile-only runners. The View runner also *runs*
what it compiled, so it needs the fake to emit a real PE — copy any small
console exe (`copy /y C:\Windows\System32\attrib.exe "!OUT!"`) instead of
writing text, or `call` cannot start the "interpreter" at all.

Then, from the repo root:

```bash
export RED_COMPILER='C:\Windows\System32\cmd.exe'
export RED_COMPILER_ARGUMENTS='/d /c E:\temp3\red\local\fake-rs-compiler.cmd -t Windows-X86-64'
export RED_TARGET=Windows-X86-64
timeout 300 /d/EE/QTool/red-console.exe tools/self_hosting/run-red-compiler-tests.red
```

Expected: no `harness error`, no `Script Error`, no `Access Error`, and a totals
line. A fake compiler always succeeding means every negative test
(`--assert-msg?` expecting a real diagnostic) fails by construction — the pass
count is meaningless, only the absence of harness errors is signal.

To prove the harness discriminates, invert the fake: a compiler that prints
`*** Compilation Error: ...` and `exit /b 1`. Compile-failures should jump and
the pass count should drop (observed: 124 assertions / 32 pass / 0
compile-failures succeeding vs 123 / 11 / 118 failing).

For the View runner the interesting branches are the interpreter compile and
the per-file run. Both were checked with a fake: a failing fake prints
`** view-headless-interpreter.red - compiler error **` and quits 1 (and its
command line shows `-r` with exactly one `-t`, proving `qt/target-flag`
suppresses the duplicate), and a succeeding fake walks all 16 files, scores
each through `qt/read-summary` and reports a totals line.

Delete the fake compiler and any `build/self-hosting/<suite>/` output it
produced when done — stale fake binaries can satisfy an `exists?` check.

## Known issues to resolve

1. **`tests/source/compiler/print-test.red` was overwritten.** It already
   existed in git as a 2-line stub (`Red [...]` header + `print 1`). The ported
   `print-test.r` replaced it. Nothing referenced the stub and the ported
   version is the real test, but this is a tracked-file overwrite that should be
   confirmed or reverted. The `.r` original still exists.
2. `run-red-system-tests.red`'s `--run-only` path is the one branch never
   exercised (a fake compiler cannot reach it).
3. No real-compiler validation has happened at all. Every total recorded so far
   comes from a fake compiler. In particular `run-red-view-headless-tests.red`
   has never compiled a real `test`-backend interpreter, so whether the
   `-r -t <host>` combination actually produces one is still unverified.
4. Under a fake compiler `regression-test-redc-5.red` reports a `harness
   error`: it ends with `--assert (load qt/output) > 0`, and `load ""` is `[]`,
   so `[] > 0` raises `invalid-compare`. That is an artefact of a program that
   never ran, not a port bug — but it means the script aborts early there, so
   its remaining assertions are never counted.

## Next steps, in order

1. **Phase E:** cutover. Everything needs a real compiler first —
   `build/red-toolchain/windows-x64/red-toolchain.exe` SEGFAULTs on every
   invocation, so not one of these workflows has ever run. Beyond that:

   - Four repository variables have to exist before any job passes:
     `RED_LINUX_X64_HYBRID_BOOTSTRAP_URL`, `RED_LINUX_ARM64_HYBRID_BOOTSTRAP_URL`
     and their `RED_<PLATFORM>_BOOTSTRAP_SHA256` checksums, plus
     `RED_CLI_CONSOLE_URL`.
   - `RED_CLI_CONSOLE_URL` is used as a single variable across all four
     platforms. If the console binary differs per platform (it must, in
     practice) this needs to become `RED_<PLATFORM>_CLI_CONSOLE_URL` — one
     line in each of the four workflows.
   - `<target>-DLL` as the `RED_SYSTEM_LIBRARY_TARGET` default on non-Windows
     is a derived guess; `Windows-X86-64-DLL` is the only spelling verified
     anywhere in the tree.
   - `run-red-view-headless-tests.red` has still never compiled a real
     `test`-backend interpreter, so `-r -t <host>` producing a working binary
     is unverified. `base-self-test.red` now rides along in that suite and reads
     `system/view/metrics/dpi` and `system/view/screens/1/size`, so whether the
     `test` backend supplies them is the first thing a real run will answer.
     - The six `Invoke-NativePhase` scripts under `tests/` still shell out to
     `cmd.exe /c $Compiler -cqs red.r` and resolve `$Compiler` to `rebview.exe`.
     Giving each a `-HybridCompiler` branch, the way
     `run-windows-x64-all-tests.ps1`'s Prepare phase already has, is what would
     finish retiring Rebol from the Windows native phases.
     - `.appveyor.yml` still invokes the deleted Rebol scripts. AppVeyor looks
     abandoned; delete the file or leave it, but it cannot work as written.
