# Handover: Darwin ARM64 hybrid codegen — make the Red tests pass

Date: 2026-09-12. Branch: `red-64-v2`. HEAD: `edb9bfb3b`.
Goal: cross-compile the Red **unit test suite** for `Darwin-ARM64` with the
hybrid compiler and make it pass on `macmini`. The Red/System suite is
already done (40/40 on the mac). Only one compile blocker remains, then
runtime verification.

---

## 1. State check (run these first, before touching anything)

```bash
cd /e/temp2/red
# 1. Latest compiler binary (must be newer than speed1, ~5.9 MB):
ls -la build/self-hosting/merge-red64/hybrid-compiler2.exe
# 2. Red/System hello still cross-compiles and runs on the mac:
./build/self-hosting/merge-red64/hybrid-compiler2.exe -r -t Darwin-ARM64 \
  -o build/darwin-hybrid/hello-rs2 build/darwin-hybrid/hello2.reds
scp build/darwin-hybrid/hello-rs2 macmini:/tmp/ && ssh macmini 'chmod +x /tmp/hello-rs2 && /tmp/hello-rs2'
#   -> expect: rs-darwin-hybrid-ok
# 3. The Red compile fails at the known blocker:
./build/self-hosting/merge-red64/hybrid-compiler2.exe -r -t Darwin-ARM64 \
  -o build/darwin-hybrid/hello-red build/darwin-hybrid/hello.red
#   -> expect: "measure compile failure function=1803 ... FAILING op=7/0/1/217"
# 4. mac mini reachable:
ssh macmini 'uname -m'    # -> arm64
```

## 2. Environment

- Windows host, repo `E:\temp2\red`, shell Git Bash. `ssh macmini` works
  (arm64, macOS 15.7, clang at /usr/bin/clang).
- `D:\EE\QTool\red-console.exe` — interpreted Red console. WARNING: it can
  hang burning CPU; always wrap in `timeout`.
- `D:\EE\QTool\rebcmdview.exe` — Rebol (legacy red.r path; not needed here).
- pwsh 7 required for `tools/self_hosting/*.ps1` (PowerShell 5.1 fails on
  Start-Process ArgumentList).
- dumpbin: `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\dumpbin.exe`
  — Git Bash eats `/headers`; use `//headers` or run via cmd.

## 3. Bootstrap chain — CRITICAL gotcha

- `build/self-hosting/cc-speed1/red-bootstrap-speed1.exe` (Aug 30) **can no
  longer build this tree**: its old x64 backend rejects the merged tree's
  RSIR ("native codegen rejected invalid RSIR", dump ends inside
  common.reds). Do NOT use it.
- Current bootstrap: `build/self-hosting/merge-red64/hybrid-compiler.exe`
  (or `hybrid-compiler2.exe`, 5917184 bytes, contains all fixes). Build a
  new generation with:
  ```bash
  ./build/self-hosting/merge-red64/hybrid-compiler.exe -r -t Windows-X86-64 \
    -o build/self-hosting/merge-red64/hybrid-compiler3.exe \
    red-bootstrap-windows-hybrid.red
  ```
- **Always check the build's exit code.** `build ... | tail -1` masks
  failures (the `&&` chain keeps going on a dead binary). Use
  `echo BUILD_EXIT=$?`.
- A plain bootstrap exe can only compile Red/System. Compiling Red
  programs needs the full toolchain (embedded resources), built via
  `tools/self_hosting/build-windows-hybrid-toolchain.ps1` (pwsh 7). The
  toolchain entry is `red-toolchain-windows-hybrid.red`; its RSIR exceeded
  the old 16 MB limit, hence DEFAULT-MAX-BYTES is now 64 MB
  (compiler/rsir-frontend.red).
- `hybrid-compiler.exe` is currently on disk at the pre-custom-call state;
  `hybrid-compiler2.exe` is the newest (all fixes through edb9bfb3b).
  When in doubt, rebuild from source with whichever bootstrap works.

## 4. Test infrastructure (all verified)

- **Red/System suite (Windows)**: passes 12,648 assertions, 0 failed.
  ```bash
  RED_SYSTEM_COMPILER="E:\temp2\red\build\self-hosting\merge-red64\hybrid-compiler2.exe" \
  RED_SYSTEM_COMPILER_ARGUMENTS="-t Windows-X86-64" \
  RED_SYSTEM_STRUCTLIB="E:\temp2\red\build\self-hosting\merge-red64\structlib-x64\structlib.dll" \
  D:/EE/QTool/red-console.exe tools/self_hosting/run-red-system-tests.red
  ```
  (RED_SYSTEM_COMPILER is mandatory — the legacy fallback entry was
  deleted. structlib-x64 is an MSVC-built 64-bit structlib.dll; the
  checked-in one is 32-bit and breaks struct-x64-test with 0xC000007B.)
- **Red unit suite (Windows)**: passes 16,826 assertions, 0 failed.
  ```bash
  RED_COMPILER="...hybrid-compiler2.exe" RED_COMPILER_ARGUMENTS="-t Windows-X86-64" \
  D:/EE/QTool/red-console.exe tools/self_hosting/run-red-unit-tests.red
  ```
  The runner deletes a stale libRedRT.dll in its output dir first (do not
  "fix" that away — it caused 23 phantom failures once).
- **Darwin Red/System suite**: 40/40 on macmini. Rebuild/deploy:
  `bash build/darwin-hybrid/build-rs-suite.sh` then
  `cd build/darwin-hybrid/rs-suite && tar -cf ../rs-suite.tar *-test run-suite.sh`
  and `scp` + extract to `/tmp/rs-suite` on the mac, run
  `/tmp/rs-suite/run-suite.sh`. (zsh on the mac: `status` is read-only —
  use another variable name.)
- **Darwin Red unit suite (TO DO)**: compile each unit from
  `tools/self_hosting/run-red-unit-tests.red`'s unit-sources list with
  `-r -t Darwin-ARM64` (release mode = standalone, no libRedRT.dylib
  involved), package like rs-suite.tar, run on macmini, parse
  "Number of Assertions Failed" per suite.

## 5. Architecture primer (what you are editing)

All in `system/codegen/arm64-codegen.reds` unless noted:

- The hybrid frontend (`compiler/rsir-frontend.red`) emits a flat RSIR
  binary; `system/compiler-rsir-core.red` drives it;
  `compiler/codegen-bridge.red` (routine) → `system/codegen/codegen-bridge.reds`
  → `x64-codegen/generate` or `arm64-codegen/generate` by architecture
  (1=x64, 2=ARM64).
- ARM64 generate = per function: `plan-function` (stack-depth simulation,
  spill-window reservation, storage home assignment) then a measure
  `compile-function` pass, then the emitting pass.
- Expression stack: slot k maps to temp register FIRST_TEMP(9)+k-1.
  TEMP_REGISTER_COUNT=7 (X9–X15). Depth > 7 must live in the region spill
  window: displacement = -((region-base + slot) * 8), guarded by
  `(region-base + depth) > region-limit` → INVALID_IR. Fixed scratch:
  X16/X17. Home registers for locals: 19–28.
- x64 is the reference behavior for every gate; when an ARM64 gate fails,
  diff against the x64 arm (x64 is frame-based and has no depth limit, so
  its arg passing relies on frame slots — the ARM64 needs the explicit
  spill/park instead).

## 6. THE REMAINING BLOCKER (one site)

Cross-compiling `build/darwin-hybrid/hello.red` fails at:

```
ARM64 measure compile failure function=1803 status=-1 ordinal=145
  FAILING op=7/0/1/217
```

- fn 1803 = `red/interpreter/exec-routine` (the interpreter's routine
  caller). Instruction: `CALL a=0 (callee on stack), b=1 (one arg),
  c=217 (typed-call signature type)`. resolve-call now succeeds:
  ret=-5 (i32), pcnt=0 (the signature declares no params), flags=33
  (CUSTOM + CDECL).
- The -1 comes from the argument-loading loop's stack-passing branch:
  `unless (call-flags and VARIADIC) <> 0 [return INVALID_IR]`
  (the site was temporarily labeled "CALLFAIL site=20"), because the
  custom call has pcnt=0 but 1 argument.
- x64 semantics to port (x64-codegen.reds ~7353): `custom-call?:
  call-mode = CUSTOM`, `physical-count: custom-call? [0]`, outgoing=0 —
  i.e. **no ABI argument passing at all**; the argument was already
  pushed by the frontend (ir[143] ADDRESS local19, ir[144] LOAD).
- Already in place in the ARM64 arm: `custom-call?` flag
  (`call-mode = CUSTOM`), the plan + compile arity exemptions for
  CUSTOM, and an X0 materialize of the single argument injected in the
  a=0 `true [...]` branch right before
  `arm64-encoder/call-register ... X17`.
- The fix: guard the argument-ABI application loop (and the
  indirect-aggregate copy loop) with `not custom-call?` so the loop is
  skipped entirely for custom calls; the pre-injected X0 move then feeds
  the `call-register X17`. Verify the X0 convention against the x64's
  custom-call argument register before trusting runtime results.
- After fn 1803 compiles: expect possibly 1–3 more single-site failures
  elsewhere in the 2396-function runtime (same classes: dead paths after
  `red/fire`, deep stacks, strict gates vs x64). Iterate with the
  diagnostics below.

## 7. Diagnostic tooling (in the tree, keep them)

- `--dump-o2-ir <file>` on any hybrid compiler writes the whole RSIR
  module (compiler-rsir-core.red). The build-time failure dump prints
  `FAILING op=a/b/c` = the exact failing instruction (uses
  last-compile-ordinal; trustworthy).
- ARM64 internal status codes: INVALID_IR=-1, UNSUPPORTED=-2,
  OUTPUT_FULL=-3. The bridge maps -3 → OUTPUT_FULL(4) and the driver
  RETRIES the whole codegen with doubled capacity (16→256 MB, 5
  attempts). So a `-3` failure prints 5 identical dumps; only the first
  is clean. `-1`/-2 fail immediately.
- `last-plan-ordinal` in a plan-failure print can be STALE (from a
  previous function) when plan-function fails in its pre-loop
  (prepare-exception-structure or the aggregate-return layout). The
  compile-failure `FAILING op=` line is always current.
- RSIR binary layout (for python parsing): header 9×u32 (module-kind,
  entry, type-count, import-count, function-count, instruction-count,
  global-count, switch-count, export-count); then types 20 B
  (kind,target,flags,first-member,member-count); members 8 B (type,flags);
  imports 32 B; globals 24 B (name,name-size,type,flags,
  first-initializer,initializer-count); functions 36 B (name,name-size,
  return-type,flags,first-parameter,parameter-count,first-local,
  local-count,instruction-count); exports 12 B; parameters 8 B
  (type,flags) covering imports' + all functions' params+locals
  contiguously; initializers 16 B; switches 12 B; instructions 16 B
  (op,a,b,c); rest = strings. Function records give names via offsets
  into the trailing string blob. Parameter record base for fn N =
  sum(import param counts) + sum(prev functions' param+local counts)
  — fn/first-parameter field is authoritative.
- The compiler source compiles in ~55 s with the newer bootstrap; the
  failing hello.red compile ~40 s. Iterate quickly, always `-v` the build
  exit code.

## 8. Commits already on red-64-v2 (in order)

1. `7416f1b70` toolchain-support include for the hybrid chain + RSIR
   limit 64 MB (without this no compiler builds at all).
2. `d6d8b0f28` unit runner drops stale libRedRT.dll (phantom test
   failures — the suite had a stale runtime cached).
3. `f18c408f9` removed Windows-only legacy self-host entries
   (red-system-selfhost-windows.red etc.); RS runners now require
   RED_SYSTEM_COMPILER.
4. `6d260b096` ARM64: pointer-difference gate, OP_INDEX lazy temp,
   OP_LOAD frame fallback, plan spill reservation, --dump-o2-ir.
5. `802aba15e` ARM64: comparison category/null gates, LOG_B,
   FUNCTION_ADDRESS, REFERENCE deep fallbacks, layout-type -8, dead-path
   skips, sub-return merge normalization, custom resolution.
6. `edb9bfb3b` custom-call + dead-path tolerance (see §6).

Windows regression state after all of the above: Red/System 12,648
assertions 0 failed; Red unit 16,826 assertions 0 failed.

## 9. After the Red suite compiles

1. Cross-compile the ~35 Red unit tests (release, no -d — the RSIR
   frontend rejects debug builds) into `build/darwin-hybrid/red-suite/`.
2. Package with the run-suite.sh pattern (already proven) and run on
   macmini. The Red runtime's startup, GC and print on Darwin are
   exercised for the first time here — treat any runtime crash like a
   codegen bug: `--dump-o2-ir`, find the function, compare the ARM64
   emission against x64.
3. Known-safe anchors: hello-rs prints correctly on the mac; exceptions,
   atomic and dylib smoke tests passed via the RS suite.

## 10. Landmines checklist

- Never bootstrap from speed1 for the current tree.
- Always check build exit codes (piped tail masks failures).
- Do not reuse an old libRedRT.dll; the runners/compilers regenerate it.
- RS suite needs the MSVC-built x64 structlib.dll.
- pwsh 7 (not powershell) for the .ps1 tooling.
- `red-console` may hang; wrap with `timeout`.
- dumpbin args from Git Bash: `//headers`, `//dependents`.
- The old comparison worktrees red-premerge / red-mac were removed; the
  git stashes (stash@{0} WIP on red-64-v2: x64-codegen O2 edits) are the
  user's — leave them alone.
