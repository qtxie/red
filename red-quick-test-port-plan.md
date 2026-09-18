# Revised plan: retire Rebol from the test harness

Supersedes "move GitHub test workflows to the hybrid toolchain" Phases 2-4.
Phase 1 (the reusable toolchain supply workflow) is unaffected and stays as
written.

## Status

- **Phase A — done.** `tools/self_hosting/qt-runner.red` written; all three
  existing runners are thin clients of it; 19 Red/System compiler scripts
  ported to `.red` and running with no shim.
- **Phase B — done.** 9 more Red-side scripts ported (the dylib auto-test
  generator, item 6, turned out to be part of Phase C instead — see below).
- **Phase C — done.** 59 Rebol files deleted. The Red/System suite no longer
  needs Rebol for anything.
- Phases D-E not started.
  (`regression-test-redc-1..5`, `compile-error-test`, `run-time-error-test`,
  `print-test`, `preprocessor-test`) behind a new `run-red-compiler-tests.red`,
  and the headless View suite behind a new
  `run-red-view-headless-tests.red`. All 28 ported scripts load as valid Red.
  Both deferred scripts decided (see below).
- Phases C-E not started.

## Why the plan changed

Rebol cannot run on ARM64. That is not a coverage gap in the hybrid toolchain,
it is a gap in the **test driver**: `quick-test/quick-test.r` and every runner
that `do`es it are Rebol scripts, so `ARM64.yml` and `macOS-ARM64.yml` can
never execute them on a native ARM64 runner no matter which compiler we inject.
Injecting `--binary` (the completed Phase 2 work) fixes *which compiler* the
tests use; it does not fix *what runs the tests*.

The fix is to run the harness on Red. Red already compiles to all four hybrid
targets, so a Red driver runs natively on `ubuntu-24.04-arm` and `macos-15`,
and the Rebol interpreter disappears from CI entirely as a side effect.

Host: the Red CLI console, `environment/console/CLI/console.red`
(`D:\EE\QTool\red-console.exe`), invoked as
`red-console.exe tools/self_hosting/<runner>.red`. This is already the
documented host in `handover.md`.

## The port is further along than it looks

The framework is not a greenfield port. Two of its three layers are already
Red, and working drivers exist:

| Layer | State |
| --- | --- |
| In-test DSL (`--test--`, `--assert`, groups, `~~~start-file~~~`) | **Red already** — `quick-test/quick-test.red`. Every `.red`/`.reds` test uses it, and it emits the `Number of Tests Performed:` summary block. |
| Red unit driver | **Red already** — `run-red-unit-tests.red`, 57 units |
| Red/System unit driver | **Red already** — `run-red-system-tests.red`, 40 units |
| Red/System Compiler tests | **Red already** — `run-red-system-compiler-tests.red`, 19 scripts |
| Red Compiler tests | **Red already** — `run-red-compiler-tests.red`, 9 scripts |
| View headless suite | **Red already** — `run-red-view-headless-tests.red`, 16 files through one compiled interpreter |
| Cross-target suite builder | **Red already** — `arm-red-system-suite-builder.red` (in-process, no subprocess) |
| Darwin ARM64 Red suite | **Red already** — `build-darwin-arm64-red-tests.red` (includes `run-all-interp.red`) |

Only the **driver** layer (`quick-test.r`, 24 KB, Rebol) has no Red
equivalent — and the existing runners each re-implement a slice of it.

### Port directly. No shims.

`run-red-system-compiler-tests.red` currently loads the legacy Rebol scripts
rather than porting them:

```red
do transcode read/binary script-file
```

plus a Rebol-compatibility shim. **That shortcut is rejected.** The scripts get
ported to Red, one for one, and loaded natively with `do %file.red`.

The shim is not merely inelegant, it is unsound. It defines
`change-dir: func [path][none]` — a silent no-op — so every legacy script that
opens with `change-dir %../` has been running against whatever directory it
happened to inherit, not the one it asked for. It also discards the `REBOL []`
header outright. A shim makes a script *load*; it does not make it *correct*.
Porting directly is the only way to know what the tests actually assert.

### The port is small

The scripts total ~5,800 lines, but the Rebol-specific surface is tiny:

| Construct | Count | Red equivalent |
| --- | --- | --- |
| `found?` | 43 | `not none?` |
| `make object!` | 12 | `object [...]` / `context [...]` |
| `attempt` | 6 | `try` (Red returns an `error!` value; no `disarm`) |
| `system/words` | 1 | drop, or the Red equivalent |
| `reform` | 1 | `rejoin` / `form` |

No `disarm`, no `throw-on-error`. Most of each script is already just the test
DSL (`--test--`, `--assert`, `--compiled?`, source strings in `{...}`), which
the new Red driver implements directly. `alias-test.r` is 60 lines of header,
one `change-dir`, and DSL calls — the port is nearly mechanical.

## Revised architecture

- **`tools/self_hosting/qt-runner.red`** (new) — the ported driver. One
  implementation of the Quick-Test driver API on Red: `qt/compile`, `qt/run`,
  `--run-test-file-quiet`, `--run-script-quiet`, `--compile-dll`,
  `--run-unit-test`, `--compiled?`, `--compile-and-run`, `--assert-msg?`,
  `--assert-printed?`, group/section markers, run totals, process exit code.
  Backed by Red's `call` native (`/wait /output /error /shell`, returns an
  integer status).
- **No `rebol-compat` module.** Every test script is real Red. The shim
  vocabulary in `run-red-system-compiler-tests.red` is deleted, not extracted.
- **Existing runners become thin clients** that `#include` the driver and
  declare their unit list, instead of each owning a private copy of the
  compile/run/parse logic.
- **Configuration stays on environment variables** — `RED_COMPILER`,
  `RED_COMPILER_ARGUMENTS`, `RED_SYSTEM_COMPILER`,
  `RED_SYSTEM_COMPILER_ARGUMENTS`, `RED_SYSTEM_LIBRARY_TARGET`. This is the
  established convention and is what the workflows will set.

## Phases

### Phase A — Build the driver (start here)

Write `qt-runner.red`: the full driver API, plus the features the existing
runners lack — dylib support on the Red side, `-d`/`-r` modes, interpreter
(`interp`) and per-test (`each`) modes, and negative-compile tests that capture
their diagnostics. Then move the three existing runners onto it.

Exit criterion: 57 Red units, 40 R/S units and 19 compiler scripts keep
passing on Windows x64, with unchanged totals.

### Phase B — Port the Rebol test scripts, one for one

Each legacy `.r` becomes a `.red` beside it; the `.r` stays untouched so the
Rebol path remains green during the grace period. Order by risk, cheapest
first:

1. The 19 `system/tests/source/compiler/*.r` scripts (20-263 lines each) —
   already run under the shim, so their expected behaviour is known.
2. `system/tests/source/compiler/regression-test-rsc.r` (1,602 lines) — the
   largest; split by group if it will not port in one pass.
3. `tests/source/compiler/regression-test-redc-1..5.r` (494/553/305/249/641).
4. `compile-error-test.r`, `run-time-error-test.r` — these are what Phase A's
   negative-compile path exists for.
5. `tests/source/compiler/print-test.r` (78).
6. The Red dylib tests, currently
   `system/tests/source/units/compile-test-dylibs.r`.
7. View: `run-view-headless-tests.r` already targets the headless `test` GUI
   backend and compiles its interpreter once, so it needs no display. Ported
   as `run-red-view-headless-tests.red`; it compiles
   `tests/view-headless-interpreter.red` once with `-r` plus an explicit `-t`
   and feeds it the 16 `tests/source/view/*.red` files through `qt/run/with`.

**Deferred, decided per script:** `lexer-test.r` and `preprocessor-test.r`.
The Red compiler has its own lexer and preprocessor, so these may be worth
porting after all — but only if they test that implementation rather than the
Rebol one. Do not port them by reflex.

Decided:

- **`preprocessor-test.r` — ported** (`tests/source/compiler/preprocessor-test.red`).
  It drives the Red preprocessor (`#do`, `#if`, `#macro`, `#switch`, `#case`,
  `#reset`, `preprocessor/fetch-next`) through `--compile-and-run-this-red`,
  so it tests the Red implementation. It was the only script of the two that
  `tests/source/units/run-pre-extra-tests.r` ran as a compiler test.
- **`lexer-test.r` — not ported.** It `do`es `%../../../encapper/lexer.r` and
  asserts on `lexer/process`, i.e. it tests a *Rebol* implementation. Red's own
  lexer is already covered by `tests/source/units/lexer-test.red` (58 KB),
  which `run-red-unit-tests.red` has been running all along.

Each port is verified individually: same assertions, same expected messages,
same totals as the `.r` it replaces. A port that changes what is asserted is a
bug, not a cleanup.

### Phase C — Retire the Rebol entry points

Done. 59 files deleted:

- **The driver and its entry points (22):** `quick-test/quick-test.r`,
  `quick-unit-test.r`, `run-test.r`, `tests/qt-test.r`; `run-all-tests.r`,
  `run-all-tests-x64.r`, `run-all-tests-linux-x64.r`;
  `tests/{run-all,run-all-together,run-all-tests-common,run-core-tests,run-regression-tests,run-view-tests,run-view-headless-tests,build-arm-tests,build-separate-arm-tests}.r`;
  `system/tests/{run-all,build-arm-tests}.r`; and the four
  `tests/source/units/{run-all-init,run-all-together-init,run-pre-extra-tests,run-post-extra-tests}.r`
  phases those runners `do`ne.
- **The ported `.r` originals (28):** 19 in `system/tests/source/compiler/`,
  9 in `tests/source/compiler/` (including `lexer-test.r`, which was not ported
  but drove a Rebol implementation).
- **The Rebol dylib tooling (9):** `make-red-system-auto-tests.r`,
  `make-dylib-auto-test.r`, `create-dylib-auto-test.r`, `compile-test-dylibs.r`,
  `prepare-dependencies.r`, `run-float.r`, `make-red-auto-tests.r`,
  `make-lexer-auto-tests.r`.

**Phase B item 6 turned out to be a Phase C blocker.** The Red/System suite's
`%auto-tests/dylib-auto-test.reds` was generated by three Rebol scripts, so the
suite still needed Rebol with the entry points gone. `run-red-system-tests.red`
now assembles it in Red from the same four `dylib-*.txt` templates. The one
deliberate change: the `#import` block always names the DLLs by absolute path,
where the Rebol generator used a bare name on Windows — a compiled test runs
from the repo root, not from the output directory the DLLs sit in.

**Coverage preserved rather than lost:** `tests/source/runtime/unicode-test.red`
and `tests/source/runtime/tools-test.reds` were only reachable through the
deleted pre/post-extra phases, so they were folded into
`run-red-unit-tests.red` and `run-red-system-tests.red`.

**Coverage knowingly dropped:** `tests/source/view/base-self-test.red`, which
only `tests/run-view-tests.r` ran and which wants a real GUI backend, not the
headless `test` one. It stays in the tree with no runner.

Two Rebol scripts remain in the harness directories but are now unreachable:
`tests/source/library/call-test.r` and the `make-*-auto-test*.r` generators
that no runner calls. They are dead, not broken; Phase E can sweep them.

### Phase D — Rewrite the workflows

Done. No `rebol -cqs` anywhere, and no `rebview.exe`.

- **`.github/workflows/build-hybrid-toolchain.yml`** (new, reusable,
  `workflow_call` + `workflow_dispatch`) — matrix over `windows-x64`,
  `linux-x64`, `linux-arm64`, `darwin-arm64`. Each leg runs on its own runner,
  because a bootstrap compiler only runs on the platform it was built for:
  checkout → download the pinned bootstrap from
  `RED_<PLATFORM>_HYBRID_BOOTSTRAP_URL` → SHA-256 check → build → package →
  upload `red-toolchain-<platform>`. Callers pass the subset they need via
  `with: platforms: '["windows-x64"]'`; unselected legs are skipped by a
  job-level `if`.
  - Windows keeps `test-windows-hybrid-toolchain-fixed-point.ps1`.
  - The three Unix legs use `tools/self_hosting/build-red-toolchain.sh`,
    generalised to take `-t <target>` instead of hardcoding `Darwin-ARM64`.
  - `RED_LINUX_X64_*` / `RED_LINUX_ARM64_*` are new repository variables. The
    two Windows and Darwin checksums stay hardcoded as today; the two Linux
    ones are read from `RED_<PLATFORM>_BOOTSTRAP_SHA256`, since no binary is
    pinned in the tree for them yet.
- **`.github/actions/setup-red-harness`** (new composite action) — downloads
  the toolchain artifact, unpacks it to `build/toolchain/bin/red-toolchain`,
  and downloads the Red CLI console from `RED_CLI_CONSOLE_URL` to
  `build/toolchain/red-console`. One definition, four workflows.
- **`main.yml`** — Windows. `Core` / `Core-Release` / `Core-Debug` run
  `run-red-unit-tests.red` with no extra flag / `-r` / `-d` passed through
  `RED_COMPILER_ARGUMENTS`; `Regression` runs `run-red-compiler-tests.red`;
  `Red-System-Test` runs `run-red-system-tests.red` +
  `run-red-system-compiler-tests.red`; `View-Headless` runs
  `run-red-view-headless-tests.red`; `Windows-X64-All` runs all five and
  reports each failure.
- **`linux.yml`** — Linux-X64-All on `ubuntu-24.04`, all five runners.
- **`ARM64.yml`** — builds *and* runs natively on `ubuntu-24.04-arm`. The
  cross-build-on-x64 step and the artifact hop are gone; this is the job Rebol
  could never run.
- **`macOS-ARM64.yml`** — builds and runs on `macos-15`. The
  `rebview.exe`-on-Windows cross-build disappears entirely, which is the single
  biggest simplification. The native View smoke test is kept and now compiled
  by the toolchain instead of Rebol + `red.r`.

**This is where the earlier `--binary` plumbing got retired.** A job now takes
its compiler from `RED_COMPILER`, not `--binary`. The 17 modified files that
carried it were deleted in Phase C.

One thing did not survive, and two earlier claims about it were wrong.

- **`base-self-test.red` does not need a real GUI backend.** Its
  `Needs: 'View` is commented out and it carries no `Config:` of its own,
  because the headless suite *interprets* its tests: the backend comes from
  `%view-headless-interpreter.red`, which is built with
  `Config: [GUI-engine: 'test]`. A test file's own header only matters when it
  is compiled. It is now part of `run-red-view-headless-tests.red`, so
  `main.yml`'s `View` job is covered by `View-Headless` rather than dropped.
- **The `--each` jobs were not a lost mode.** The Rebol default compiled many
  units into one binary (`auto-tests/run-all-comp1.red`); `--each` compiled and
  ran each unit separately. `run-red-unit-tests.red` compiles and runs each unit
  separately *always*, so `Core` and `Each-Mode` are the same thing now — what
  the Red runner has no equivalent for is the merged-compile mode, not `each`.
- **The Windows native phases are only half Rebol-bound.** `Invoke-PreparePhase`
  already had a `-HybridCompiler` branch and builds `structlib.dll` with
  `cl.exe`, so `Windows-X64-All` runs it with `-HybridCompiler` and needs no
  Rebol. What genuinely is Rebol-bound are the six `Invoke-NativePhase` scripts
  (`run-windows-x64-{abi,release,development,dll,view}-tests.ps1`,
  `run-windows-window-long-ptr-tests.ps1`): each shells out to
  `cmd.exe /c $Compiler -cqs red.r`, and `$Compiler` resolves to `rebview.exe`.
  Those are not migrated.

`.appveyor.yml` is the last file left invoking the deleted Rebol scripts. It is
AppVeyor config, long superseded by these workflows, and has been left alone
rather than deleted.

### Phase E — Validation and cutover

Run both paths on a branch, diff per-job results against the legacy baseline
from the same commit, triage only count deltas and strictness changes. Update
`AGENTS.md` with the new baseline and platform matrix.

## Risks

- **`red-console.exe` leaves a stale process** after a runner exits
  (documented in `handover.md`). CI jobs need an explicit kill or `timeout`,
  or they will hang.
- **stderr is not captured by `call/output`** — the existing runners work
  around it with `call/shell/wait` and `> log 2>&1` redirection, which costs
  shell quoting portability. Prefer `call/wait/output/error` in the new driver
  and verify on Windows.
- **Direct porting surfaces dormant bugs.** The shim's no-op `change-dir` is
  the proof: scripts have been asserting against the wrong directory. Expect
  some ports to fail on first run, and treat that as the port working.
- **Interpreter mode is not compiled mode.** `run-all-interp.red` is compiled
  once and then fed test files; a Red driver running tests in-process through
  `do` exercises a different path and may surface distinct failures.
- **One binary covers all four targets**, so the toolchain matrix is three
  builds, not four — but the `-t` names are strict (`Windows-X86-64`, not
  `MSDOS`), and `--no-view` has no hybrid equivalent.
