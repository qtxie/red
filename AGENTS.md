- run/interpret Red script: `D:\EE\QTool\red-console.exe red-script-path.red` for quick testing without waiting a long time to compile it.
- Be careful when you using red-console.exe or running tests, sometime it does not exit properly and keep burning cpu
- dumpbin: C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\dumpbin.exe
- cdb: C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe
- think more time before writing code. The code should be Red or Red/System idiomatic. The architecture and algorithms must be elegant, refined, direct, fast, and free of any unnecessary overhead.
- The architecture and algorithms should be elegant, clear, fast, and free of unnecessary overhead. They should not rely on special-case hacks that distort the compiler.
- do a git commit when finish a major task
- sudo password: toto

# Hybrid Bootstrap Chain Discipline

- Verified self-hosting baseline: `build/self-hosting/merge-red64/hybrid-compiler60.exe`
  (built from `hybrid-compiler59.exe`). 59->60 successfully self-compiles
  `red-bootstrap-windows-hybrid.red` (fixed point, output 5983232 bytes; the two
  generations emit byte-identical Red/System programs apart from the PE
  timestamp and checksum).
  Debug-mode baseline: `hybrid-compiler59d.exe` (58d->59d, output 8648192
  bytes); 58d and 59d emit byte-identical programs.
  The compiler image itself is never byte-identical between generations because
  it embeds a `dd-Mmm-yyyy/h:mm:ss` build date of varying length, which shifts
  the serialized data and every absolute address by one byte. Compare generated
  output, not the compiler image, when checking the fixed point.
- Current baseline: `build/self-hosting/merge-red64/hybrid-compiler194.exe`
  (193->194, output 6419968 bytes; 194 and 195 differ in 15 bytes -- the PE
  timestamp, the PE checksum, the output file name, the two `movabs rax`
  immediates that carry the compiler's build clock, and the
  `dd-Mmm-yyyy/h:mm:ss` dates -- so the chain is at a fixed point. 194 carries
  the **GDI+ startup** fix described below: `GdiplusStartupInput!` now declares
  `DebugEventCallback` as `int-ptr!`, which is what GDI+ expects on X86-64
  (pointer at offset 8, struct 24 bytes) and is still exactly right on IA-32.
  Without it every GDI+ call answered `GdiplusNotInitialized` (18) and
  `size-text` segfaulted. It also carries two DirectWrite struct overflow
  fixes (see below). Re-measured at 194: Red/System suite 10593 tests / 12680
  assertions / 12680 passed / 0 failed / 0 compile-failures; native View suite
  (`tools/self_hosting/run-red-view-tests.red`) 107 tests / 507 assertions /
  507 passed / 0 failed; headless View suite 16/16 files / 148 tests / 246
  assertions / 246 passed / 0 failed; `gui-console` 3320832 bytes, starts
  clean. `build/red-toolchain/windows-x64/red-toolchain-194.exe` is 7690240
  bytes, `--self-check` reports 276 resources, and a program it builds prints
  the same `size-text` as one built by hybrid-compiler194.
  Cross-target (every source that changed is Windows-only, so this is a
  control, not an expectation): `hello.red` still prints `red-linux-ok` on
  Linux-X86-64 (1958480 bytes) and Linux-ARM64 (1632264 bytes). (The
  hybrid compiler rejects plain `Darwin`: it supports Windows-X86-64 PE,
  Darwin-ARM64 Mach-O and Linux X86-64/ARM64 ELF only.)
  Darwin-ARM64 **compiles and runs**. `hello.red` is a valid Mach-O --
  1667288 bytes, magic `0xfeedfacf`, cputype `0x0100000c`, `MH_EXECUTE`, 17
  load commands, linking libSystem / ApplicationServices / CoreFoundation /
  CoreServices / libobjc / libcurl / AppKit -- and prints `red-linux-ok` on
  the Mac (macOS 15.7.7, T8132). The full Red unit suite runs there for the
  first time: **65/65 units, 9363 tests, 18034 assertions, 0 failed**
  (`build/darwin-hybrid/build-red-suite194.sh` + `deploy-red-suite194.sh`,
  logged in `red-suite194-run.txt`). That is the 57 units the old 83-era run
  covered (8808 tests / 16854 assertions) plus the 8 that had no driver
  before -- clipboard, csv, draw, image, json, reactivity, routine,
  regression-test-red (374 tests / 912 assertions). Caveats for the harness,
  not the target: macOS has no `timeout` (the watchdog is hand-rolled, and
  its `sleep` subshell must have stdout redirected or every test blocks for
  the full limit), `scp`-ed binaries need
  `xattr -dr com.apple.quarantine`, `file-test` leaves a `testfile.txt` that
  a naive `*` glob counts as a failing suite, and the `macmini` tunnel drops
  long-lived ssh sessions -- launch the runner with `nohup ... & disown` and
  poll the log.
  Darwin toolchain fixed point, measured on matched pairs: `dt194b` vs
  `dt195b` differ in **140 bytes** and `dt194b` vs `dt194c` (same compiler,
  rebuilt) in **68** -- generation drift is the same order as rebuild noise,
  so Darwin is at a fixed point.
  **When you compare two generations, give the outputs names of equal
  length.** The output file name is embedded in the image, and a name one
  character longer shifts the serialized data the same way the
  `dd-Mmm-yyyy/h:mm:ss` build date does -- except the effect is far larger:
  a 5-vs-6-character pair differs in ~1.85 MB, almost all of it in
  `__DATA,__data` (1,830,687 of 2,144,688 bytes; `__TEXT,__text` moves by
  only 4,825 of 4,544,468), while every equal-length pair sits at 68-140
  bytes. `dt19a` vs `dt194` (5 vs 5, built a session apart) is 70 bytes and
  `dt19a` vs `dt194b` (5 vs 6, built minutes apart) is 1,848,597, so it is
  the length that matters, not the clock or the session. This cost me a
  detour: a "1.85 MB unexplained spread" between generations was just
  `dt194` vs `dt194b`.
  The old open bug where a `#import` library name past 32 bytes was truncated
  in the PE DLL-name buffer is still fixed at 194: `dumpbin /dependents`
  prints `E:\TEMP3\RED\BUILD\TMP-CLEAN\ZEBRA.DLL` and 28/32/33-char names
  whole. Note the repro needs the imported function to be *called* -- an
  unused import is pruned and the library never reaches the table.
- Previous baseline: `build/self-hosting/merge-red64/hybrid-compiler190.exe`
  (189->190, output 6419968 bytes; 190 and 191 differ in 17 bytes -- the PE
  timestamp, the PE checksum, the output file name, the two `movabs rax`
  immediates that carry the compiler's build clock, and the
  `dd-Mmm-yyyy/h:mm:ss` dates -- so the chain is at a fixed point. 189 carries
  the **UTF-16 literal alignment** fix described below: `#u16` literals are
  interned as 16-bit units so they land on an even address, which is what let
  the Windows View backend register a class and open a window for the first
  time. Re-measured at 190: Red/System suite 10593 tests / 12680 assertions /
  12680 passed / 0 failed / 0 compile-failures, headless View suite 16/16
  files / 148 tests / 246 assertions / 246 passed / 0 failed.
  (187 was the previous baseline: 186->187, 6419456 bytes, 19 bytes between
  186 and 187. No source changed between 185 and 187 -- only the ported #4613
  assertion, which no compiler compiles -- so every number measured at 185
  held at 187.)
  182 is the generation that implements the **System V aggregate ABI** for
  Linux-X86-64 (below): eightbyte classification at every native boundary,
  which takes `struct-x64-test` from five failing assertions plus an access
  violation to 621/621 there while Windows-X86-64 stays 621/621. 185 then
  fixes the **ARM64 stack slot width** (below), which takes Linux-ARM64 from
  627/628 to 628/628 -- so `struct-x64-test` is now clean on every 64-bit
  target that can be run. The Red/System suite stays at 10593 tests / 12680
  assertions / 12680 passed / 0 failed / 0 compile-failures, and both Linux
  slices of it at 40/40 compile, 40/40 run, 0 differed with every unit
  reporting 0 failed assertions. The two are independent backends: the first
  touches `x64-codegen.reds`, whose `generate` accepts only `ABI_WIN64` or
  `ABI_SYSV`; the second touches `arm64-codegen.reds`.
- Earlier baseline: `build/self-hosting/merge-red64/hybrid-compiler179.exe`
  (178->179, output 6408192 bytes; 179 and 180 differ in 17 bytes -- the PE
  timestamp, the 3-byte PE checksum, the two `movabs rax` immediates that carry
  the compiler's build clock, the output file name's last digit in the two
  places it is embedded, and the two `dd-Mmm-yyyy/h:mm:ss` dates -- so the chain
  is back at a fixed point. 178 is the generation that implements a global
  initialised with an import's address (below), and it leaves the Red/System
  suite at 10593 tests / 12680 assertions / 12680 passed / 0 failed /
  0 compile-failures. All 40
  Darwin-ARM64 Red/System executables are byte-identical between 169 and 176,
  and all 23 dev-mode Red units between 172 and 175, which is what says the
  callback, variadic and `-v` changes are inert for everything already
  passing). 157 is the first generation that
  cross-compiles the
  whole macOS toolchain: `hybrid-compiler157.exe -r -t Darwin-ARM64 -o
  build/red-toolchain/darwin-arm64/red-toolchain
  red-toolchain-darwin-hybrid.red` produces a 6690688-byte Mach-O that
  reports `host: Darwin-ARM64, backend: hybrid-rsir, standalone: true,
  resources: 276`, passes `--self-check`, and compiles and runs both a Red
  and a Red/System program on an Apple Silicon Mac.   Re-verified on the Mac at 179:
  40/40 Red/System units and 23 Red units -- logic, integer, float, char,
  series, append, path, object, map, function, loop, parse, make, convert,
  mold, load, lexer, evaluation, binding, type, routine, recycle and
  comparison -- pass, 10298 Red assertions with 0 failures, and every
  per-unit count is the one 160 reported (logic 95, integer 1760, float 1793,
  char 35, series 1119, append 327, path 60, object 658, map 86, function 147,
  loop 58, parse 1518, make 3, convert 451, mold 54, load 225, lexer 929,
  evaluation 294, binding 25, type 42, routine 22, recycle 39, comparison
  558). Cross-compile a slice of the Red suite with
  `build/tmp-redmac/red-cross-darwin.sh COMPILER OUTDIR`, or drive both
  slices with `build/tmp-mac179/build.sh` and run them with
  `build/tmp-mac179/run.sh DIR LABEL` on the Mac -- note `run.sh` must invoke
  `./$f`, since a bare `$f` makes the shell search PATH and every unit reports
  127. `scp -r` drops the execute bit, so chmod on the Mac side. The 40-unit
  slice is the 43-entry list in `run-red-system-tests.red` minus
  `struct-test` and `size-test` (they need `structlib.dll`) and
  `dylib-auto-test` (it is generated with host absolute paths).
  Windows on 156: Red/System suite 10593 tests / 12680 assertions / 12680
  passed / 0 failed / 0 compile-failures.
  157 adds the four deep-stack ARM64 repairs below to 153, which adds the
  region-spill planner fix to 152, which adds the operator-named object
  field fix to 151, which adds the
  header currency registration below to 150, which adds the
  set-path type check below to 149, which adds the
  return-type check below to 148, which adds the dev-mode
  `#system-global` fix to 147, which adds the
  callback spec check to 146, which adds the
  compiler-owned syntax-error wording to 145, which adds
  the conditional-expression check to 144, which adds the
  `as`-cast check to 143, which carries the
  syntax-error fix, which sits on 140, which carries the c-string literal fix
  on top of
  138 -- the first baseline whose own runtime is built from the fixed
  `collector.reds` and `binary.reds`. 136 was built one minute before those
  fixes landed, so it still carries the old runtime. It also compiles the
  headless test View backend (`Config: [GUI-engine: 'test]`, e.g.
  tests/view-headless-interpreter.red, 7.3M IR instructions, 2490880 bytes) and
  the 16 unit files under tests/source/view/ run clean through it: 16/16 with
  246 assertions, 0 failures. `red-console.exe
  tools/self_hosting/run-red-view-headless-tests.red` (RED_COMPILER pointed at
  the binary) drives the whole suite; it takes under a minute and is still
  148 tests / 246 assertions / 246 passed / 0 failed at **185**, so the
  Win64 side of the `hidden-return?` change is unchanged.
  Windows regression: 58/58 Red unit files
  (57 units plus unicode-test, now run in dev mode without `-r`) -- 8812 tests,
  16893 assertions, 16893 passed, 0 compile failures -- and 40/40 Red/System
  units, with the Red/System runner reporting 12680 assertions, 12680 passed,
  0 failures -- up from 12052 because dylib-auto-test finally loads and
  struct-x64-test finally links.
  All five suites are clean on 152: Red/System compiler tests 124/124,
  Red/System units 12680/12680, Red units 16893/16893, View headless 246/246,
  and the Red compiler tests are 319 passed / 2 failed of 321 (below), up
  from 251/12 of 262 on 145 -- the 59 extra assertions are the tail of
  `regression-test-redc-5.red`, which #4526 used to truncate. The two left
  are #4190 (`face!` needs the View backend) and one assertion of #4613
  (money molding is the runtime's). Of the 319: three are the
  `#system-global` group, seven the
  syntax-error wording group; before those the twelve were the cast group,
  the twenty-two before them the conditional group and the last two a wrong
  path in output-test. The Red/System compiler tests went 84/40 on 142,
  120/124 on 145, 122/124 on 147, 123/124 on 149 and 124/124 on 150 -- the
  last four gained are the callback spec check, the return-type check and
  the set-path type check.
  COVERAGE GAP CLOSED ON 152: five scripts under `tests/source/units/` were
  in no runner at all -- `run-red-unit-tests.red` only named its 54 "core
  console language" units. All five compile and run:
  `regression-test-red.red` (911 assertions, 910 pass), `csv-test.red` (56),
  `json-test.red` (47), `reactivity-test.red` (68) and `routine-test.red`
  (22) -- 1104 assertions, one failure. `regression-test-red.red` exercises
  the CSV codec in #5645, and CSV -- like JSON -- is an opt-in module
  (compiler/modules.red), so its header now carries `Needs: CSV`; without it
  the whole 911-assertion script dies at `load-csv/with` with "load-csv
  returned a unset! value", which is what its commented-out `; Needs: 'View`
  used to hide. clipboard-test / draw-test / image-test stay out: they need
  the View backend.
  The one failure is #5220, and it is runtime-side, not a codegen bug: the
  emitted code does carry `stack/unwind-flush` after the discarded statement
  (check with `--red-only`), three such statements in a row measure 0, and
  moving the same statement behind a function call makes it measure 160216.
  The number tracks allocation history, not liveness -- the interpreter
  reports -284 where a compiled program reports 162484 on the same source.
  MEASURING BEHIND A HARNESS ABORT: `regression-test-redc-5.red` dies at
  #4526 (`do bind [probe 1 ** 2] context [...]` prints `1` then `** has no
  value`, and `--assert 3 = load qt/output` raises a *syntax* error on that
  text in the harness itself). The runner catches it and goes on to the next
  script, so the file's own #4527 onwards is never measured -- 6 of its 95
  assertions were hidden that way. To see them, temporarily replace that one
  assertion with `--assert not none? qt/output`, run
  `red-console.exe tools/self_hosting/run-red-compiler-tests.red
  regression-test-redc-5.red`, and revert with `git checkout --`.
  Release mode now has a full-suite number: `RED_COMPILER_ARGUMENTS="-r"`
  gives 9311 tests, 18025 assertions, 18024 passed, 1 failure, 0
  compile failures -- 63 files, the 58 above plus the five named in
  COVERAGE GAP CLOSED ON 152. It was 8820 tests / 16921 assertions / 16921
  passed / 0 failures for the 58 on 145, re-measured unchanged on 148 and
  150; the 1104 added assertions are the five new files and the single
  failure is #5220. Release mode is
  *more* than dev mode's 16893 by 28 assertions and 8 tests, not less: a
  handful of tests only run when the runtime is linked in. It costs ~40
  minutes, which is why nobody had run it. The earlier `-r` spot
  check of the seven collector-heavy units on 142 agrees: series 1119/1119,
  append 327, make 3, convert 451, redbin-codec 1762, recycle 39,
  unicode 67/67.
  MACOS TOOLCHAIN (built on 157): see `docs/red-toolchain.md`. The ARM64
  backend had four gaps, all the same root cause -- an expression stack
  deeper than the seven temp registers (x9-x15), which x64 cannot see
  because it has no place concept and a different register budget:
    * site 324, op=7  OP_CALL   -- OP_LOAD's inline deep fallback parked the
      address of an inline aggregate but never re-tagged the slot to VALUE.
      An inline aggregate *is* that address, so the parked word was already
      the loaded value. (Not the frontend leaving a place: `take o/in`
      compiles clean, the frontend emits the OP_LOAD.)
    * site 293, op=6  OP_MEMBER -- out of temp registers, nowhere to put the
      member address.
    * site 282, op=21 OP_INDEX  -- same for a dynamic index.
    * site 148, op=16 OP_JUMP   -- canonicalize-stack/restore-control-stack
      put every live slot in its canonical temp register because an edge
      carries only a depth and a type; slots past the pool now canonicalize
      into the slot the region reserves for that depth.
    * spill-live-stack, reached only by system/stack/push-all|pop-all, parked
      a PLACE as LOCATION_FRAME. On a place that tag denotes "the addressed
      object lives here", not "the address is stored here", so every member,
      load and store below it would have been silently retargeted. It now
      refuses a place (site 396) rather than emit code that lies: a place
      cannot survive a full register push, and nothing in the language leaves
      one live there -- the native consumes no operand, so it cannot appear
      inside a path or an argument list, which is the only place a place is
      ever live.
  All four sites are reached only by 19 MB of IR -- `compile-function` alone is
  34k instructions -- so unit tests cannot find them; the toolchain build is
  the test.
  Linux ARM64 at 185, on the `armbian` board (Cortex-A53, ARMv8.0, no LSE):
  `bash build/linux-hybrid/rs-suite-linux.sh
  build/self-hosting/merge-red64/hybrid-compiler185.exe Linux-ARM64 armbian`
  compiles 41/41 and runs 41/41 with 0 failed assertions -- `atomic-test` 33/33
  and `queue-test` 64/64 included, which is what closes the SIGILL note above.
  Linux x86-64 at 185 (`HOST=wsl`) is the same: 41/41 compile, 41/41 run,
  0 failed assertions. The 41st unit is `struct-x64-test` -- 621/621 on
  x86-64 and 628/628 on ARM64 -- which the suite never carried before because
  it could not load a library there; the driver now ships the 64-bit
  `structlib.so` / `structlib-arm64.so` for its target to the host and points
  `LD_LIBRARY_PATH` at it.
  The driver compares every run against
  `build/win-regression/rs-hybrid-compiler179/`, the Windows logs from the same
  generation; three ARM64 units and one x86-64 unit come out "differing" and
  all four are count-only, with 0 failures on both sides, because the bodies
  are platform-conditional: `int64-test` is `#if target = 'ARM64` (0 tests on
  Windows, 12 on ARM64), `pointer-test` is `#if target = 'X86-64`, and
  `lib-test` is `#either any [OS = 'Linux OS = 'macOS]` (7 tests on Linux,
  6 on Windows). The output directory is `rs-<gen>-<target>` because the two
  Linux targets share one generation and would otherwise overwrite each other.
  Watch the `noref:` count: the reference is `build/win-regression/rs-<gen>/`,
  so a generation whose Windows logs were never produced has nothing to
  compare against. It used to print `OK` and `differed: 0` in that case, which
  reads like a match; it now prints `NOREF` and counts them separately, so
  `differed: 0 noref: 41` means "all 41 ran, none was actually compared".
  The compile and run counts and each unit's own
  `Number of Assertions Failed` are the part that stands on its own.
  Fixed at 160: **the linker could not tell a variable import from a function
  import.** `codegen-import!` carried no kind, so `linker/load-codegen` named
  every import with a plain `string!` and every `issue?` test in ELF.red,
  Mach-O.red and Mach-O-ARM64.red was dead code -- a convention three formats
  already implement, with nothing feeding it. Two consequences on ARM64:
    * An ADRP/ADD page reference is how an import is named, and the ARM64
      codegen emitted the `ldr` that reads the slot only for `ABI_AAPCS64`, on
      the stated assumption that "Mach-O patches the pair to the symbol
      itself". It cannot: an imported symbol lives in a dylib at a distance no
      ADRP can span, so Mach-O reaches it through a `__got` slot exactly as
      ELF does. The load is now unconditional.
    * Mach-O's `patch-imports` aimed a page reference at the *stub* for a
      function and at the GOT slot only for an issue!. Since there were no
      issues, `environ` was aimed at stub #14, and `ldr` read the stub's first
      instruction word (`adrp x16, ...`) as if it were a pointer and
      dereferenced it: `*** Runtime Error 16: invalid virtual address`. With
      the load restored, the pair names the slot for *every* import -- a stub
      is fine to branch to but wrong to read.
  The image now carries `flags` (the RSIR import flags: zero means variable),
  `IMAGE_IMPORT_SIZE` is 28 in both codegens, and `linker/load-codegen`
  publishes a variable as `to issue! external`. ELF routes it to
  `.data.rel.ro` with an `R_*_GLOB_DAT` instead of borrowing the `.got.plt`
  slot a call uses -- which is what `DT_BIND_NOW` was papering over -- and
  Mach-O drops it from `__stubs`. `system/tests/source/units/lib-test.reds`
  now pins all three spellings on Linux and macOS: a read of an imported
  variable, the address of an imported function and a call. Darwin ARM64 goes
  from a crash to 17/17; Linux ARM64 and Linux x86-64 print the same
  `environ/value` a C program does. Windows PE was checked by hand and reads
  an imported variable correctly -- from `msvcrt.dll`, `_environ` prints a
  real environment entry. Do **not** reach for `__argc`, `__argv` or
  `_pgmptr` to test this: a Red/System image has no MSVC CRT startup, so
  msvcrt leaves those three at zero and dereferencing `__argv` faults.
  `_environ` survives because msvcrt fills it from the PEB when the DLL is
  attached. Nothing in either suite imports a Windows data symbol;
  `lib-win32-test.reds` only imports `GetComputerNameA`.
  Red on Linux ARM64 at 160 (`logic-test` 95, `float-test` 1793, `series-test`
  1119, `parse-test` 1518 assertions, 0 failures) agrees with the Mac run
  assertion for assertion.
- Fixed at 162: `system/runtime/darwin.reds` declared `NXArgcPtr` **twice** in
  the `#switch type [dll [...]]` `program-vars!`, so every Darwin *dylib*
  build -- `libRedRT` included -- died with "duplicate aggregate member". Darwin's
  `<crt_externs.h>` `ProgramVars` puts `NXArgvPtr` between `NXArgcPtr` and
  `environPtr`; that is what the second field is now called. Neither field is
  ever read, so only the declaration changed. An exe was never affected, which
  is why the toolchain looked fine: only dev mode compiles `libRedRT`.
- **Editing a runtime file is not enough for the toolchain**: it embeds a
  compressed copy in `build/generated/red-toolchain-resources.generated.red`,
  which is checked in. Regenerate it or the fix is invisible --
  `hybrid-compilerN.exe -r -t <host> -o build/tmp/gen-res.exe
  tools/self_hosting/generate-toolchain-resources.red` then
  `build/tmp/gen-res.exe <repo-root> build/generated/red-toolchain-resources
  .generated.red`. Build the generator for the *host*, not the target:
  `tools/self_hosting/build-red-toolchain.sh` compiles it for `$target`, which
  cannot run when cross-compiling.
- **Dev mode now builds and runs a Red program on macOS** (fixed at 175, was
  the open item above). Three independent blockers, all of them invisible to
  `-r` because only dev mode compiles `libRedRT`:
  * `compiler/rsir-frontend.red`'s `add-library-callbacks` injected the
    *Windows* prototype -- `on-load [handle [pointer! [integer!]]]` -- on
    every platform. Darwin's `***-dll-entry-point` calls
    `on-load argc argv envp apple pvars`, so the frontend passed `argc` alone
    into an `int-ptr!` parameter and codegen stopped at
    `INVALID_IR site 329 (compile-function/scratch/stack-locations#163) op=7`;
    Linux's calls `on-load` with no argument at all and never got past
    "missing expression". `callback-prototype` now mirrors the legacy
    `get-proto` (`system/compiler-core.red`): Windows the handle, macOS the
    five arguments, Linux `[[cdecl]]`. The frontend needed the OS for that, so
    `compile-rsir` sets `compiler-rsir-frontend/OS: job/OS`.
  * `arm64-codegen.reds`'s `resolve-call` refused a variadic callee whose
    convention was not cdecl unless it was a named function with *no*
    convention -- but `add-runtime-export` stamps every runtime export
    `stdcall`, and the generated `libRedRT-include.red` mirrors it, so
    `red/fire` and three others arrived as stdcall variadic on *both* sides of
    the dylib. That pairing is deliberate and harmless: cdecl means real
    varargs, anything else packs the trailing arguments into a list, both are
    already lowered, and AAPCS64 has one convention either way. The convention
    test is gone.
  Verified: dev mode cross-compiles all 23 Red units for `Darwin-ARM64` and
  the Mac runs them 23/23, 5723 tests / 10270 assertions / 0 failures
  (`series-test` 1119, `parse-test` 1518, `float-test` 1793, `logic-test` 95
  -- the same counts release mode reports). The macOS toolchain rebuilt at 179
  (`build/red-toolchain/darwin-arm64/red-toolchain-179`, 6707072 bytes,
  `--self-check` 276 resources) does the same natively on the Mac: it compiles
  a Red program in 10s and runs it. A dylib that declares no callbacks of its own
  still loads, runs and `dlclose`s, and one that does still fires `on-load`
  and `on-unload`. Linux dev mode builds now too, and so does **Windows** --
  the access violation dev mode used to take there was the collector's bitmap
  table choice, fixed above, not anything dev mode owns. Verified again on the
  Windows toolchain rebuilt at 179: `print collect [loop 5 [keep 1]]` after
  200000 `append`s on a string runs in dev mode and prints the same three
  lines as `-r`. The runners still pass `-r`, but that is only because a
  dev-mode run needs a `libRedRT` built from current sources next to the
  output, not because dev mode is broken.
  Note the toolchain only embeds `environment/`, `runtime/`,
  `system/runtime/`, `modules/` and `system/assets/` (see
  `tools/self_hosting/generate-toolchain-resources.red`): a fix in `compiler/`
  needs the toolchain *rebuilt*, not the resources regenerated.
- Implemented at 178: **a global initialised with the address of an import.**
  `#import [...] [imp-fn: "strcmp" [...]]` then `p: :imp-fn` now works on all
  four targets; it used to die in codegen, on ARM64 at
  `prepare-global-data site 34` and on x64 at
  `validate-module-initializers site 310`. Functions, globals and imports
  already shared one reference-id space in that order, so such an initializer
  needs no table of its own: its reference rides in the slice the import's
  *calls* already use, told apart by sign -- a positive entry is a code offset
  to patch, a negative one is the 1-based position of a slot in the writable
  data for the loader to fill. That is the encoding `load-codegen` already
  uses for a data reference, so the bounds checks come for free. ARM64 needed
  only the arm in `valid-static-address-initializer?` and the `target-id`
  arithmetic, now shared by its three call sites through
  `static-address-target-id`; x64 also needed the reference *counted*, in
  `measure-module-functions` under `argument-marking?` -- the pass that owns
  the per-import counts -- because an import whose address is only taken
  would otherwise be handed no slice at all.
  The three loaders differ only in how the slot gets filled:
  * PE has no relocation that resolves a name to an address after loading, so
    the import table is the only mechanism. Each slot gets an
    `IMAGE_IMPORT_DESCRIPTOR` of its own reusing the library's name, a
    one-entry lookup table with a null terminator, and `FirstThunk` aimed at
    the slot. **The slot's on-disk content has to be the lookup table's own
    hint/name RVA**: the loader skips a thunk whose slot does not still hold
    it, reading it as one a bind already filled, and a slot left at zero is
    silently left at zero. That was the entire bug -- hand-patching
    `FirstThunk` to a range of `.data` addresses filled every one of them as
    soon as the slot was seeded, and none of them while it was zero.
  * ELF: one `R_*_GLOB_DAT` per slot in `.rela.dyn`, the fixup the GOT
    entries get, pointed at the global instead. The symbol index is its
    1-based position in the flat import list, which is also its `.dynsym`
    index.
  * Mach-O: one extra bind per slot, aimed at the data offset. dyld writes
    the resolved address straight in, which is what the inline
    `IMPORT_ADDRESS` path already relies on, so the two forms agree.
  A protected global is rejected: its slot lives in the read-only section,
  where no dynamic relocation may write. Verified on Windows-X86-64,
  Darwin-ARM64, Linux-X86-64 and Linux-ARM64 with
  `build/tmp-imp/iag-check-*.reds` (call through the slot, then compare with
  the address `:imp-fn` yields in code), `iag-only-*.reds` (address taken and
  never called) and `iag-arr-*.reds` (array of two import addresses).
  Two traps: `resolve-import-refs` in ELF.red patches *code* at every entry of
  an import's reference list, so a negative entry there lands at the head of
  `.text` and corrupts the entry point -- PE and Mach-O already skip
  non-code entries for the same reason. And the repro's `#import` must sit at
  top level, not inside `#switch`: from inside a conditional the frontend
  fails earlier and misleadingly with "missing expression".
- Fixed: **an aggregate passed across a native call** on **Linux-X86-64**.
  The x64 backend applied the *Win64* aggregate rule on every target: an
  aggregate of exactly 1, 2, 4 or 8 bytes went into one integer register, any
  other one was handed over **by reference**, and both classes drew from one
  shared slot counter. Found through the 64-bit structlib builds:
  `checkTriple8 [t [triple8! value] bias [integer!]]` emitted
  `lea 0x10(%rsp),%rax` / `mov %rax,%rdi` / `mov %r11d,%esi` -- the struct's
  address where its three bytes belong -- and answered 290 instead of 10.
  System V splits an aggregate of at most 16 bytes into eightbytes and gives
  each one a register by what it holds -- a vector one if that eightbyte holds
  a floating-point field, an integer one otherwise -- drawing six GPRs and
  eight XMMs from **independent** counters. Anything larger goes in memory, as
  does any aggregate whose class has run out. Returns differ too: the integer
  eightbytes come home in RAX then RDX and the vector ones in XMM0 then XMM1,
  each class from its own pair, while a MEMORY return rides a hidden pointer in
  **RDI** where Win64 uses RCX.
  `x64-codegen.reds` now classifies per eightbyte
  (`sysv-aggregate-eightbytes`) and one helper, `sysv-claim-argument`, owns the
  register counting for **every** boundary -- the copy pass, the argument loop,
  `plan-storage`, the prologue and the return path -- so all five agree by
  construction instead of by convention. Two traps, both caught only by the
  assertion totals: (1) the copy pass and `plan-storage` reserve an argument's
  stack slot **before** the claim counts it out, so `stack-offset` in the
  argument loop has to be built from that same pre-claim slot and not from the
  running one -- otherwise every argument that misses a register lands eight
  bytes high; (2) a hidden return pointer takes the first integer register on
  both ABIs, so the caller's GPR counter starts at `hidden-shift`, not zero.
  Measured with the real unit, cross-compiled and run with the new 64-bit
  library beside it (`LD_LIBRARY_PATH=.`): `struct-x64-test` went from five
  failing `x64-native-aggregate-abi` assertions plus an access violation to
  **621/621** on Linux-X86-64, with Windows-X86-64 holding 621/621 and
  Linux-ARM64 at 627/628 (one pre-existing assertion). The five were all
  register-exhaustion or hidden-return-boundary cases -- `checkBigOverflow`,
  `returnHugeBoundary`, `callHugeBoundaryCallback`, `checkMixedExhaustion` --
  i.e. exactly the paths where an aggregate does not fit.
  Probes: `build/tmp-imp/structlib-probe-{lin,mac,win,la}.reds` and
  `build/tmp-imp/sv-probe.reds`.
  Red/System-to-Red/System is *not* affected and does not need to be: both
  sides of an internal call use the same by-reference convention, so it is
  self-consistent on every target. `build/tmp-imp/sv-probe.reds` confirms it --
  five functions taking structs by value answer identically on all four
  targets. What must match the C compiler is the boundary: a native call out,
  a callback in, and a value returned either way.
  It stayed invisible because `struct-test` and `size-test` were skipped on
  every non-Windows target -- `libs/` only carried 32-bit structlib builds, so
  those two units were never run there, only excluded.
- To inspect a codegen failure without rebuilding the compiler, dump the IR
  the frontend hands it: `red-console.exe build/tmp-imp/rsir-dump.red
  <target> <out.rsir>` (it stubs `codegen-module` because the console cannot
  run routines), then read it with
  `build/self-hosting/merge-red64/rsir.py <out.rsir> <fn>:<limit>`. Note
  `rsir.py` takes 0-based function and instruction indices while what codegen
  prints is 1-based, and `first_parameter` is 1-based.
- Fixed at 176: **`-v N` was swallowed as `--version`.** Red's `find` is
  case-insensitive unless you ask for `/case`, so `find ["-V" "--version"] "-v"`
  matched, the flag was taken for the version flag and `N` was then parsed as a
  source file -- the command died with "multiple source files" and `--verbose`
  was the only way through. Both branches now match with `/case`. Watch for the
  same trap anywhere two options differ only in case: `find` will not tell them
  apart, and swapping the order of the two branches only moves the bug.
- Fixed at 164: **Linux shared objects could not be built at all.** Two
  independent blockers, both only reachable through `#export`, which is why
  nothing in either suite ever saw them:
  * `compiler-rsir-core.red` demanded `all [job/PIC? job/PIE?]` for *every*
    Linux module. The registry gives `Linux-{X86-64,ARM64}-SO` `PIC?` but not
    `PIE?`, so both `-SO` targets died with "invalid hybrid target linking
    mode". Linux is now required to be PIC full stop, and an *executable*
    additionally PIE. A shared object is `ET_DYN` by `job/type` -- `PIE?`
    would only have stamped it `DF_1_PIE`, which is a claim about
    executables.
  * `ELF.red`'s `collect-exports` computed each exported symbol's size by
    walking `reverse copy job/symbols` from the highest offset down. That was
    written for a block; `job/symbols` is a map now, so it raised
    `reverse does not allow map!`. It now groups the candidates (dropping
    imports, which have no offset of their own), sorts them by offset
    descending and walks that. Sorting rather than trusting iteration order
    matters: a map says nothing about layout.
  `system/tests/shared-lib.reds` now produces a working `.so` on both Linux
  targets -- `readelf` reports `DYN`, and a C loader calling `dlopen` gets
  `on-load executed`, `foo(41) = 42`, `i = 56` and `on-unload executed` on
  AArch64 and x86-64 alike. `-t Darwin-ARM64-SO` and `-t Windows-X86-64-DLL`
  *built* fine at the time but only Windows actually worked -- see the 167
  and 169 bullets. The linker appends the platform suffix, so the output
  lands at `<name>.dylib` / `<name>.so` / `<name>.dll`, not at `-o <name>`.
  As of 169 all three are load-tested, not just built, and all three print
  `on-load executed`, `foo(41) = 42`, `i = 56`, `on-unload executed`. Windows
  goes through the PE entry point, which is a real `DllMain`
  (`DLL_PROCESS_ATTACH` -> `on-load`, `DLL_PROCESS_DETACH` -> `on-unload`),
  so it needs nothing from the linker beyond `AddressOfEntryPoint`; it is
  driven by `build/tmp-imp/dll-loader-win.reds`, an R/S program that calls
  `LoadLibrary`/`GetProcAddress`/`FreeLibrary` -- no C toolchain needed.
  The cross-build is a fixed point as well: 157 and 158, each writing a
  6690688-byte Mach-O to an output name of the same length
  (`build/red-toolchain/darwin-arm64/red-toolchain-157|158`), differ in 144
  bytes -- the output name's last character in the two places the name is
  embedded, the two `dd-Mmm-yyyy/h:mm:ss` clocks, two materialized 64-bit
  constants and four 32-byte windows of the compressed resource blob.
  Compare two builds only under equal-length `-o` names: the output embeds its
  own path, so a longer name shifts the whole resource blob and repaints every
  address literal that points into it -- 157's `red-toolchain` against 158's
  `red-toolchain-158` differ in 1.87 MB, almost all of it that shift.
  Editing a file the toolchain embeds changes it too: 158 against 159 differ
  in 219 KB -- the recompressed resource blob and the address literals that
  point into it -- although no generated instruction changed.
  Fixed point: with `SOURCE_DATE_EPOCH` pinned, 149 self-compiles to 150 at
  the same 6366720 bytes. Unpinned they differ in ~1600 bytes, which is the
  clock -- the build date is a variable-length string, so it shifts every
  absolute address by one and repaints a few thousand bytes. Pin it and two
  self-compilations of 142 differ in 4 bytes, so the chain genuinely
  converges. (140 vs 141 happened to differ by only 15 because that run's
  clock string kept the same length.)
- Fixed at 167: **a Darwin dylib's tail was laid out from a stale length.**
  `Mach-O-ARM64.red` derived `__mod_init_func`, `__mod_term_func` and the
  rodata base from `length? data` *before* rodata was folded into `data`.
  rodata is appended to `data` and written as part of it on purpose -- a
  separate `__DATA,__const` page is remapped r/o by dyld on Apple Silicon and
  SIGBUS-es later stores -- so every tail offset came out short by the rodata
  size, the following `insert/dup` was handed a negative count and silently
  did nothing, and the 16-byte lifecycle payload landed that many bytes past
  the file offset its two sections advertise. In `shared-lib.reds` rodata is
  6 bytes, so `__mod_init_func` read `0x1504000a00000001` instead of
  `0x100001504`: dyld branched into rodata instead of `***-dll-entry-point`,
  `on-load` never ran, and rodata symbol references resolved 16 bytes high.
  The fix measures rodata where the file is built from it -- `const-offset` is
  now the writable end, and the lifecycle slots follow `data + rodata`.
  Verified: `__mod_init_func` = `0x100001504`, `__mod_term_func` =
  `0x1000027d4`, matching `--show-func-map`'s `***-dll-entry-point` /
  `on-unload`, and a C loader gets `on-load executed`, `foo(41) = 42`,
  `i = 56`. `--show-func-map` is what made it diagnosable: it prints
  `code-ptr + spec/2 - 1`, the exact expression the slots are built from, so
  the two numbers can be compared directly. The 40-unit Red/System suite
  cross-compiled for Darwin-ARM64 is **byte-identical** between 164 and 166,
  so only the dylib path moved; on the Mac it is 40/40 with 12025 assertions
  and 0 failures.
  A Python Mach-O dumper (`build/tmp-imp/macho-dump.py`) reads the sections,
  decodes the rebase opcodes and prints the 8 bytes at every rebased address,
  which is how the shifted payload was located: the correct pointers were
  still in the file, just 6 bytes past where the sections pointed.
- Fixed at 169: **`on-unload` never ran on Darwin.** Not the linker's fault:
  dyld logs `registering old style destructor 0x... for <dylib>` and then
  never calls it, and a dylib assembled from
  `__DATA,__mod_term_func,mod_term_funcs` by Apple's own toolchain
  (`cc -shared ct2.c ct2.s`) behaves exactly the same on Darwin 24.6 -- its
  `__mod_init_func` runs, its `__mod_term_func` does not, whether the image
  is `dlclose`d, `RTLD_NODELETE`d, or left loaded until exit. Modern clang
  emits no terminator section at all: `__attribute__((destructor))` compiles
  to `__cxa_atexit`, registered from the initializer. So the hook is now
  armed the same way -- `***-dll-entry-point` calls
  `atexit as int-ptr! :on-unload null as int-ptr! system/image/base`, using
  `system/image/base` (the mach header, which is what dyld hands back) as the
  dso handle. **The handle must not be NULL**: a NULL one leaves the handler
  armed until process exit and then calls into an image `dlclose` already
  unmapped -- verified, the handler never runs and the loader dies at exit
  with 255. `Mach-O-ARM64.red` no longer emits `__mod_term_func` at all, so
  there is exactly one mechanism; it still looks `on-unload` up so a dylib
  without it fails with a message that names the reason. Guarded to
  `ABI = 'apple-aarch64` because the legacy `Darwin` / `DarwinSO` (x86-64)
  targets go through `Mach-O.red`, which still emits the section and is not
  buildable here. Verified: `on-load executed`, `foo(41) = 42`, `i = 56`,
  `on-unload executed` -- once per `dlclose`, and again across a second
  load/unload round, matching Linux exactly.
- Fixed: seven compiler-test assertions wanted the **compiler's** syntax-error
  wording and were getting the runtime's. #2671 (`#"^(0000001)"`), #1774
  (`system/options/`), #3670 (a source with no header) and ce-1 issue #608
  grep the compile output for `*** Syntax Error: Invalid char! value`,
  `Invalid string! value`, `Invalid path! value` and `Invalid Red program`.
  That wording is the compiler's own: upstream's compiler lexer says
  `reform ["Invalid" mold type "value"]` (`encapper/lexer.r:741`), while
  `transcode` -- the scanner this fork feeds source through -- reports the
  shared catalog entry `syntax/invalid` as `(line 1) invalid char at ...`.
  The catalog is shared with `load` and with the interpreter, so it is the
  wrong layer to change; the compiler now speaks for itself:
  `compiler/lexer.red`'s `error-text` turns a `syntax/invalid` into
  `Invalid <type>! value`, `compiler/frontend.red` prints it as
  `*** Syntax Error:` followed by the file and the offending text, and
  `compiler/bootstrap-driver.red` rejects a headerless source with
  `fail-syntax "Invalid Red program"` the way `red.r:755` does. Red compiler
  tests went from 251 passed / 12 failed on 145 to 258 passed / 5 failed on
  146. Fixed since then: #274, #377 and #1090 were all `#system-global`
  (next entry), #4613 was the currency header (below) and #4526 was an
  operator-named object field (below). The 185 run is 320 passed / 1 failed,
  and the one left is #4190 (`face!` needs the View backend); #4613's money
  molding was the port's own strict text compare, fixed above.
- Fixed: **`#system-global` was dropped from every dev-mode build.**
  `system/compiler-rsir-core.red` loaded `red/sys-global` inside
  `if embed-red-runtime?`, and that flag is `runtime-linkage = 'embedded`,
  which is only true for `-r`: dev mode links libRedRT instead, so the block
  was never compiled and any `routine` written against it failed to resolve
  (`unknown context c`, `undefined symbol: data`). The block belongs to the
  program, not to the runtime -- it declares what the Red-level routines are
  written against -- so it is now loaded whenever `job/runtime?` is set, and
  only the *Red* runtime splice stays under `embed-red-runtime?`. That is
  #274 (`Symptom of the universe: 42` now prints), #377 and #1090; Red
  compiler tests 258/5 -> 261/2. Worth knowing: in `-r` builds the block runs
  *before* `runtime/red.reds` is spliced in and its `print` output is lost,
  while in dev mode it lands after and prints. The two modes still differ in
  where the block sits relative to the Red runtime.
- Fixed: **a money literal's currency was validated before the header that
  declares it had been read.** `Red [Currencies: [bug]] probe bug$0` died as
  `*** Syntax Error: Invalid money! value`: TRANSCODE checks a currency
  against the runtime list *as it scans*, so a code only the header declares
  is still unknown when the body is scanned. Upstream never had the problem
  -- its lexer did not validate, so its `process-currencies` could run after
  the whole file had been lexed. `compiler/frontend.red` now reads the
  marker and the header block on their own first -- `transcode/next` stops
  after one value, so the body is never touched -- and registers those codes
  before the real scan. A code that is still unknown is then reported in
  `to-currency-code`'s own words,
  `*** Compilation Error: unknown money! currency bug, add it to the
  Currencies: header.`, which is a *compilation* error the way upstream's is
  rather than a syntax error. That is #4613: 4 of its 5 assertions, all of
  them hidden behind the #4526 abort. The fifth is runtime-side and stays
  failing -- `probe bug$0` prints `BUG$0.00` here, the same convention as
  `USD$0.00`, while the test expects `bug$0`; molding money is
  `runtime/datatypes/money.reds`, not the compiler.
- Fixed: **an object field named like an operator was never assigned.**
  `context [**: 99]` left `**` unset and stored 99 into the *global* `**`
  instead -- so `do bind [probe 1 ** 2] context [**: make op! ...]` could not
  see the op and #4526 printed `1` then `** has no value`. `comp-set-word`
  runs the name through `clean-lf-flag`, which maps every operator to its
  native's name (`**` -> `op_power`, `//` -> `op_modulo`) because that is how
  the global function namespace spells them; but an object field is named by
  its spelling -- `comp-context` collects the set-words as written -- so the
  field lookup in `emit-set-top`, `emit-push-from` and `get-path-word` now
  tries the spelling too (new `object-field-index`). Only the operators in
  `operator-symbols` were affected: `++`, which is not an op, always worked.
  #4526 passing also stops `regression-test-redc-5.red` from truncating: the
  Red compiler tests go from 262 assertions (261 passed) to 321 (319
  passed), the 59 extra being the tail of that file, measured for the first
  time.
  `system/tests/source/units/libs/structlib.dll` is a 32-bit image, so
  struct-x64-test.exe used to die with STATUS_INVALID_IMAGE_FORMAT before it
  ran; the runner now copies `libs/structlib-x64.dll` for X86-64 targets and
  that test runs 155 tests / 621 assertions with 0 failures, bringing the
  Red/System suite to 12680 assertions, 12680 passed, 0 failures. Build the
  64-bit library with `cl /LD /O2 /MT /Fe:structlib.dll structlib.c` from
  `system/tests/source/units/libs/`; the 32-bit dll is left alone so 32-bit
  targets keep working.
- `libs/` now carries a 64-bit build for every host that can run one --
  `structlib-x64.dll`, `structlib.so` (Linux x86-64), `structlib-arm64.so`
  (Linux aarch64) and `structlib.dylib` (macOS arm64) -- and
  `struct-x64-test.reds` names them, so the unit runs on every 64-bit target
  instead of only Windows: its `#switch OS` picks `structlib.dylib` on macOS
  and, on other Unix, switches on `target` for `structlib-arm64.so` versus
  `structlib.so`. Windows keeps `structlib.dll` because the runner copies the
  x64 build under that name. Verified at 184 straight from the committed
  source: Windows-X86-64 621/621, Linux-X86-64 621/621, Linux-ARM64 627/628
  (its one pre-existing assertion), Darwin-ARM64 compiles and names
  `@loader_path/structlib.dylib` but has not been run. The old i386 names it
  replaced -- `libstructlib.dylib` and `libstructlib.so` -- are still in
  `struct-test.reds`, which is the 32-bit unit and keeps using them.
- The standalone toolchain builds and runs again. Re-verified at 179:
  `hybrid-compiler179.exe -r -t Windows-X86-64 -o
  build/red-toolchain/windows-x64/red-toolchain-179.exe
  red-toolchain-windows-hybrid.red` produces 7677952 bytes (it needs
  `build/generated/red-toolchain-resources.generated.red`, which
  `generate-toolchain-resources.exe` regenerates). `--self-check` reports 276
  resources; it compiles and runs a Red program with `-r` and in dev mode, and
  dev mode survives the collector. It cross-compiles **and runs** on all four
  targets -- `hello.red` printing `"hello from the 179 toolchain"` and `9`:
  Windows-X86-64 1971200 bytes, Linux-X86-64 1958904 (run under WSL),
  Linux-ARM64 1632576 (run on the armbian box) and Darwin-ARM64 1667280 (run
  on the Mac; strip the quarantine attribute after `scp`). Earlier numbers for
  this were 140's: 7609344 bytes. The Phase E note in
  `handover-quick-test-red-port.md` saying `red-toolchain.exe` SEGFAULTs on
  every invocation is stale -- the checked-in binary answers
  `missing source file` and exits 1.
  Re-verified at **185**, after the System V and ARM64 ABI changes:
  `red-toolchain-185.exe` is 7688704 bytes, `--self-check` still reports 276
  resources, a Red `hello.red` compiles (1970688 with `-r`, 128512 in dev
  mode) and prints, and a Red/System `print` program compiles and runs.
  Re-verified again at **187**, the current baseline, and byte-for-byte the
  same size: 7688704 bytes, `--self-check` 276 resources, `hello.red` 1971200
  with `-r` and 129024 in dev mode, both printing. It cross-compiles **and
  runs** `hello.red` on Linux-X86-64 (1958784 bytes, under WSL) and
  Linux-ARM64 (1632496 bytes, on `armbian`) as well, which is the toolchain
  end-to-end over both ABI changes. Darwin-ARM64 cross-compiles but the Mac is
  unreachable, so it is not run.
  Re-verified at **190** after the UTF-16 alignment and GDI+ changes:
  `red-toolchain-190.exe` is 7690240 bytes, `--self-check` 276 resources, and
  it compiles `environment/console/GUI/gui-console.red` with `-r` to 3319296
  bytes in 66 s -- and that console now **opens a window and runs**, which no
  earlier generation could do here.
  Cross-target at 190, since the change touched both codegen backends:
  `hello.red` compiles and prints on **Linux-X86-64** (1958496 bytes, under
  WSL) and **Linux-ARM64** (1632280 bytes, on `armbian`); `struct-x64-test` is
  **621/621** on Linux-X86-64 and **628/628** on Linux-ARM64 (run it with
  `LD_LIBRARY_PATH=/home/qt`, where `structlib-arm64.so` lives). A
  `Red/System` probe printing `as integer! #u16 "..." and 1` reports parity 0
  on Windows-X86-64, Linux-X86-64 and Linux-ARM64 alike -- that is the
  alignment fix holding on every backend. Darwin-ARM64 is still not run: the
  `macmini` tunnel is down (`Connection refused` on 127.0.0.1:5588), but its
  `layout-type` derives an inline array's alignment from `record/flags` exactly
  as x64 does, so the Linux-ARM64 numbers cover the same code.
  Worth re-running after any codegen change: this is the only build that
  reaches some sites (see above), and it takes about two minutes.
  Note `build/linux-hybrid/hello.reds` is a **no-op** -- `main: does [...]` is
  never called in Red/System, since the entry point is the top level -- so it
  proves the link works and nothing else. Use a top-level `print` to check a
  Red/System program actually runs.
- `red-console.exe tools/self_hosting/run-red-compiler-tests.red` (the nine
  scripts under tests/source/compiler/) with **185: 321 assertions, 320 passed,
  1 failed, 30 compile-failures** (140 was 262 / 251 / 12 / 27). It takes a
  filename argument to run one script, which is how to iterate on a single
  failure -- `... run-red-compiler-tests.red regression-test-redc-5.red` takes
  1m40s against the full suite's 8m.
  - The 30 compile-failures are bookkeeping, not breakage: those tests feed the
    compiler deliberately broken snippets, and the runner counts every expected
    compile error as a failure.
  - The one real failure is **#4190** in `regression-test-redc-5.red`, and it is
    not a compiler defect: the snippet is `fc: make face! [...]`, `face!` lives
    in `modules/view/view.red`, and `--compile-and-run-this-red` only prepends a
    bare `Red []`, so it dies as `undefined word face!`. Compiled with
    `Needs: [View]` the program prints `boom` and both of its assertions pass.
    Declaring that is left undone on purpose: it turns a 20s compile into a 40s
    one and every Windows View program here prints a pre-existing
    `*** Error in GetClassInfoEx` at startup, even `print "hi"`.
  - **#4613** was the other failure and is fixed. Upstream asserted
    `bug$0 = load qt/output` -- money! equality, which ignores both the case of
    the currency word and the fraction's formatting. The Red port cannot write
    that literal (the harness rejects an unregistered currency when it loads
    the script), so it compared text instead and compared it too strictly: the
    program prints `BUG$0.00`, because `register-header-currencies` registers
    the code uppercased and `probe` molds money with
    `system/options/money-digits` decimals. It now asserts
    `"bug$0.00" = lowercase trim/tail qt/output`.
  - Trap while debugging these: plain **`trim` puts the line feed it removed
    back** -- `trim-head-tail` in `runtime/datatypes/string.reds` sets
    `append-lf?` and re-pokes it whenever neither `/head` nor `/tail` was given
    -- so `trim "BUG$0.00^/"` is `"BUG$0.00^/"`. Use `trim/tail` or `trim/all`.
    And `lowercase` mutates its argument in place, so printing `mold qt/output`
    *after* a `lowercase trim qt/output` shows the lowercased string and sends
    you hunting a failure that is somewhere else.
  No earlier real-compiler number exists for this suite; 138 scores 240 passed
  / 23 failed on it, so the c-string literal fix also cleared issue #832.
- **Open, and pre-existing: the Windows View backend cannot create a window at
  all.** `Red [Needs: [View]] view/no-wait [button "OK"]` prints one
  `*** Error in GetClassInfoEx`, then `*** View Error: CreateWindowEx failed!`
  for every widget, and dies on a segfault. **133, 184 and 185 all behave
  identically and emit byte-identical 2716672-byte output**, so it has never
  worked here -- do not bisect 134..185 looking for a regression, and the
  System V and ARM64 work is not implicated. The fork's View coverage is the
  headless backend (246/246, above) and the terminal one; the Windows GUI
  backend is unexercised territory. `environment/console/GUI/gui-console.red`
  is the sharpest form of it: the 187 toolchain compiles it with `-r` in 52s to
  3319296 bytes (`GUI backend: native`, `Modules: View JSON CSV`) and the
  resulting console then died on the same three `CreateWindowEx failed!` lines.
  **Fixed at 189/190** -- see the two root causes below; `build/tmp-imp/
  gui-console.exe` now opens a window and runs the console.
  `CreateWindowExW` returns null with `GetLastError` **998 (ERROR_NOACCESS)**.
  Localized from inside the backend (temporary `print`s in `gui.reds`, since
  reverted). **It is not the call and not the arguments.** A scratch Red/System
  probe (`build/tmp-imp/gci*.reds`) registers a class and creates a window
  fine, and `CreateFontW` -- **fourteen** arguments -- also works when called
  from inside the failing Red program itself, one line above the
  `CreateWindowEx` that fails. Ruled out one by one: arity; struct-typed import
  parameters (`[WNDCLASSEX]` marshals identically to `[byte-ptr!]`);
  `handle!` versus `int-ptr!` (rewriting all four handle parameters changes
  nothing); NUL termination (`unicode/to-utf16-len` writes `dst/1: dst/2:
  null-byte`); pointer validity (`class/1` reads `82 0` and `caption/1` reads
  `112 0 114 0`, i.e. correct UTF-16, from our own code); literals versus
  `c-string!` variables; and every argument value (`ws=0`,
  `flags=2CA0000h`, `x/y=1173/692`, `w/h=233/103`, `id=0`, `parent=0`,
  `inst=400000h`). A **minimal** call still fails --
  `CreateWindowEx 0 #u16 "STATIC" null 0 0 0 0 0 null null null null` -- with
  `STATIC` a class Windows always has.
  Probing `init` itself then showed it is **not** a one-way state break: the
  same minimal call returns a real HWND at `init` entry, after
  `enable-visual-styles`, after the version block, after `DX-init` and after
  `set-defaults` -- but it returned 0/998 once, right after
  `dwm-composition-enabled?`. Same inputs, different outcomes, so the failure
  is intermittent and the real call site (deep in face layout, long after
  `init`) fails every time.   That pattern is now explained and fixed, and it was **not** the stack: the
  PE reserves *and* commits 8 MB (`dumpbin /headers`), every call site is
  16-byte aligned, and `sxe av; sxe sov; sxe sbo` catch nothing. **It is the
  address of the `#u16` literal.** UTF-16 literals were interned as
  `[array byte N 1]`, and an inline array takes its alignment from its element
  width (`layout-type`, `kind = -7`), so one odd-length predecessor left the
  next literal at an odd address. The kernel probes every `WCHAR*` with its own
  alignment and raises STATUS_DATATYPE_MISALIGNMENT, which user32 reports as
  998. `build/tmp-imp/args27.reds` is the proof: the *same* bytes register a
  class from an even heap address (atom, err 0) and fail with 998 from that
  same buffer at `+1`. That also explains the "intermittent" result -- which
  literals land odd depends on the blob layout, so a module-body call could
  succeed where the identical call inside a function failed.
  The fix is to intern a `#u16` literal as 16-bit units:
  `add-static-bytes/wide` in `compiler/rsir-frontend.red` calls
  `intern-array -4 ((length? data) / 2) 2`, and the bytes-initializer check in
  `system/codegen/x64-codegen.reds` (site 303) and `arm64-codegen.reds`
  (site 27) now accepts an element width of 2 rather than only 1.
  A second, independent blocker sat behind it: **GDI+ was never actually
  started, because `GdiplusStartupInput!` in `runtime/platform/win32.reds`
  declared `DebugEventCallback` as `integer!`.** That is correct for IA-32
  (4 x 4 = 16 bytes) but wrong for X86-64, where the callback is a pointer at
  offset 8 and the struct is 24 bytes; the two trailing BOOLs then land on
  whatever follows the 16-byte struct. `GdiplusStartup` answers
  InvalidParameter (2), every later GDI+ call answers GdiplusNotInitialized
  (18), `GdipCreateStringFormat` leaves its handle 0 and `GdipSetStringFormat
  Align` takes a null critical section -- so `size-text` segfaulted. Fixed by
  typing the callback `int-ptr!`; Red/System aligns struct members, so one
  declaration is now right on both targets. This is why `base.reds` needs no
  change at all: the legacy compiler emits IA-32, where the old layout was
  already correct. Do NOT route View text away from GDI+ to work around this.
  One follow-on, fixed in the same pass: the console printed two `Math Error:
  attempt to divide by zero` at startup. `view/flags/no-wait win [resize]`
  (gui-console.red:302) fires `on-resizing` before `terminal/update-cfg` has
  measured the font, so the layout divided by a still-zero `char-width` /
  `line-h`. Not a compiler bug -- an ordering wart in the console app; it
  self-corrected because `update-cfg` runs immediately after. `core.red` now
  has `measured?` and both layout entry points (`adjust-console-size` and the
  scroller block in `resize`) skip until the metrics exist, so startup is
  silent.
  Note `handle!` is not a Red/System type here at all (only Red programs
  define it), so a standalone probe has to spell parameters `int-ptr!`.
  Note too that the **toolchain cannot see edits to `modules/`** -- it embeds
  `build/generated/red-toolchain-resources.generated.red` -- so instrumenting
  the backend needs `hybrid-compilerN.exe`, not `red-toolchainN.exe`.
- Earlier baseline: `build/self-hosting/merge-red64/hybrid-compiler132-does.exe`
  (131->132, output 6337024 bytes; two SOURCE_DATE_EPOCH-pinned
  self-compilations of 132 differ in 1596 bytes -- PE timestamp, checksum, the
  output file name and a handful of embedded values; 131 shows the same 1601
  bytes of noise, so the chain still converges). On top of 107's System V
  argument classification and the Red-on-Linux fixes it carries the later
  generations' unwind, bitmap and atomics work, and now compiles the terminal
  View backend (`Needs: [JSON CSV View]` with `Config: [GUI-engine: 'terminal]`,
  e.g. environment/console/CLI/console.red) end to end. That needed two
  frontend changes: stack-module skips a stray module-level block literal --
  #define does [func []] turns name: does [][body] into name: func [] [] [body]
  and the body block used to die as "unsupported expression [0]" -- and
  stack-call / stack-indirect-call adapt bare call literals to the declared
  parameter type (literal 0 to a pointer parameter emits null, null to an
  integer parameter emits zero), which upstream's compiler always accepted
  (terminal/tty.reds WriteFile ... 0).
- The headless test backend needed one more frontend fix on top of 132's:
  `stack-function` emitted `RETURN <type>` with nothing on the stack for a
  function whose body produces no value, which codegen rejects at INVALID_IR
  site 236 (emit-control-operation/stack-kinds/depth#23, op=11). Upstream never
  checks, and `RETURN 0` cannot be used because codegen site 235 requires the
  operand to equal the published return type -- so the body now ends with the
  return type's zero literal (test/text-box.reds OS-text-box-layout is such a
  stub). Subroutine bodies already did the equivalent: their result falls back
  to 0 when the body produces nothing.
- That alone broke `sub-9` of subroutine-test.reds, and only the assertion
  totals caught it: `stack-subroutine` reported `last-stopped?: false` even for
  a body ending in RETURN, so `finish-selection` treated the returning SWITCH
  arms as arms that fall through with no value, cleared the result type and
  dropped the value the DEFAULT arm does produce. A subroutine is inlined, so
  its call site now adopts the body's stoppedness (new `stops?` field on the
  subroutine record). The shell regression could not have caught this: it only
  checks exit codes, so run `red-console.exe
  tools/self_hosting/run-red-system-tests.red` for the assertion totals.
- Fixed: a `#import` library name longer than 32 bytes -- any absolute path --
  was cut at 32 bytes in the PE DLL-name buffer and the *next* name was written
  into its tail, so dylib-auto-test.exe imported
  `E:\...\KERNEL32.DLL` and died with STATUS_DLL_NOT_FOUND. The 32 was not
  `RSIR_IMPORT_SIZE`: `repend` on a binary! is `insert/only` of a reduced
  block, and `binary/convert` spent the block's *storage* size as the /part
  byte budget -- 16 bytes per slot -- so every value of the list was truncated
  and the rest of the list was dropped. `convert` now treats /part as a byte
  budget only when /part was actually given (runtime/datatypes/binary.reds).
  `repend dlls [uppercase name null]` in PE.red emits whole paths again.
  Verified at 169: `system/tests/source/units/auto-tests/dylib-auto-test.reds`
  compiles and runs -- 8 tests / 7 assertions / 0 failures -- and `dumpbin
  /imports` shows both
  `E:\TEMP3\RED\BUILD\SELF-HOSTING\SYSTEM-SUITE\LIBTEST-DLL1.DLL` and
  `...-DLL2.DLL` whole. The old "still open" form of this bullet (which
  blamed RSIR_IMPORT_SIZE) was wrong about the cause and is gone.
- Fixed: IF/EITHER/UNTIL/WHILE/ALL/ANY accepted **any** expression as their
  condition. Upstream requires a logic! and says so in `check-conditional`
  (system/compiler.r), but the frontend never checked, so `if 123 []` reached
  codegen and died at `INVALID_IR site 220 (emit-control-operation/...)`, or
  compiled into a branch on whatever bits were lying around. `require-condition`
  (compiler/rsir-frontend.red) now checks the value's kind at the six sites:
  `stack-if`, `stack-either`, `stack-while`, `stack-until` (both report "as
  last expression", matching upstream) and `stack-conditions` for ALL/ANY.
  Two details matter:
  * `last-type` and `last-stopped?` are `none`, not 0, until something sets
    them, so both parameters accept `none!`. Typing them `[integer!]` /
    `[logic!]` crashed the compiler on the very first valid condition.
  * ALL/ANY tolerate an element that produces *no value*: upstream types a
    call to a function with no `return:` from its body, so
    `all [... all1-fail]` with `all1-fail: func [][failed: yes]` is a logic!
    element there. Here it is a value-less one, and float-test.reds and
    float32-test.reds both rely on it (3258 assertions between them). The
    `/void-ok?` refinement allows that; a value-less condition elsewhere is
    still an error, which is what `if foo []` for a void `foo` needs.
  Clears 22 of the 28 compiler-test failures that were left, 84 -> 96 -> 118
  of 124. Red/System units 12680/12680, Red units 16893/16893, View headless
  246/246, Red compiler tests 251/12 -- all unchanged. 145 self-compiles to
  146 at the same 6349824 bytes, so the whole Red runtime and compiler still
  compile under the stricter rule.
- Fixed: the hybrid frontend never ported the `as` type-cast compatibility
  check that upstream's `cast` performs (system/compiler.r, mirrored in
  system/compiler-core.red). Without it an invalid cast such as
  `as byte! 1.0` sailed through the frontend and died in codegen, so a plain
  type mistake surfaced as an internal error --
  `codegen INVALID_IR site 159 (emit-arithmetic-operation/cast-compatible-kinds#3)`
  -- and, when the value was a function address the frontend folded into a
  static global initializer, as `site 310 (validate-module-initializers/...)`.
  Both are pre-existing: 132 through 142 all answer the same way.
  `cast-forbidden?` (compiler/rsir-frontend.red) now carries upstream's eight
  rules and is called from the two places a cast is emitted: `stack-cast`,
  before the CAST op, and the `value = 'as` arm of the static-literal folder,
  where a rejected cast would otherwise leave a global with an initializer
  codegen cannot validate. Messages match upstream exactly, e.g.
  `*** Compilation Error: type casting from float! to byte! is not allowed`.
  Note `fail` renders a message *block* with `form`, which joins the pieces
  with a space, so the words carry no padding of their own -- "type casting
  from " would come out with a double space and miss the substring the test
  greps for. This clears all twelve cast assertions in the Red/System compiler
  tests (84 -> 96 passed) and changes nothing else: Red/System units stay
  12680/12680, Red units 16893/16893, View headless 246/246.
- Fixed: any **syntax error** used to take the compiler down with the internal
  `*** Script Error: cannot compare none with 4`. `load-source`
  (compiler/frontend.red) called `compiler-lexer/process/file` and then tested
  `(length? src) >= 4`, but on a syntax error the lexer records `last-error`
  and returns none, so `length?` handed `>=` a none. An unterminated string
  broke the same way. It now reports the lexer's error and stops:
  `*** Compilation Error: invalid source: *** Syntax Error: (line 1) invalid
  char at #"^(0000001)"`. A `syntax/invalid` now gets the compiler's own
  wording instead -- `*** Syntax Error: Invalid char! value`, plus the file
  and the offending text -- because that is what upstream's compiler lexer
  always said; everything else still comes out in this form.
- Fixed: the 44 `unicode-test` failures were **not** in `load-utf8` -- that
  decoder was already correct. They were in how Red/System c-string literals
  are emitted: the lexer decodes `^(XX)` to the codepoint U+00XX and
  `add-static-bytes to binary! value` then UTF-8-encoded the literal, so
  `"^(C4)^(80)"` came out as `C3 84 C2 80` instead of the raw bytes `C4 80`.
  Upstream is explicit about this: `system/emitter.r` stores c-string literals
  with `repend ptr [value null]`, one byte per character. `c-string-bytes`
  (compiler/rsir-frontend.red) now spells the literal out byte by byte and
  only falls back to UTF-8 for codepoints above 255, which would otherwise be
  dropped entirely. Every failing group fed the decoder a *literal*; the
  groups that build their input byte by byte (`lui2`, `lui3`, `luu22`) always
  passed. unicode-test is 67/67. The runtime has no non-ASCII string literals
  -- the only non-ASCII in any .reds source is inside comments -- so nothing
  else shifted.
- Fixed: a Red program built **without** `-r` (dev mode, linked against
  libRedRT) took an access violation the moment the collector ran. The
  collector chose the bitmap table from bit 30 of the frame's bitmap index, a
  flag only the legacy emitter ever set for libRedRT code, so runtime frames
  indexed the *program's* bitmap table, read foreign slot counts and rewrote
  live stack slots. It now selects the runtime's table whenever the frame's
  return address falls inside the runtime image -- the same test
  `resolve-compiled-code` already uses (runtime/collector.reds). Dev mode needs
  a libRedRT built from current sources, and it will silently keep an old one:
  `libRedRT-ready?` (compiler/bootstrap-driver.red) is satisfied by the dll,
  the -include.red and the -defs.red all being present, so deleting just the
  dll in the output directory is what forces a rebuild -- otherwise every run
  links against whatever was built last and the crash looks unfixed. Series,
  append, make, convert, enbase, recycle and redbin-codec all died with
  0xC0000005 before the fix; they now report the same totals as `-r`.
- Fixed: a function handed to a **callback** parameter whose spec does not
  match reached codegen, which could only answer `codegen INVALID_IR site 144
  (emit-call-operation/parameter/flags#30)` and then `*** Compilation Error:
  native codegen rejected invalid RSIR`. A parameter typed
  `function! [a [integer!] b [integer!] return: [logic!]]` states what the
  callee will call, so `compiler/rsir-frontend.red` now compares the two
  signatures -- `same-signature?` over `[return-ref params locals flags]`,
  canonicalizing aliases so `byte-ptr!` and `pointer! [byte!]` agree -- and
  `check-callback` reports upstream's
  `*** Compilation Error: argument type mismatch on calling: foo`, which is
  what `compare-func-specs` in system/compiler.r says. Both sites that walk a
  call's parameters use it (`stack-call`, `stack-indirect-call`). That is
  callback-test's "inference error 1" and "inference error 2"; Red/System
  compiler tests 120/124 -> 122/124, Red/System units still 12680/12680.
- Fixed: **a set-path never checked the stored value against the target's
  declared type.** `p: declare struct! [a [test!]] p/a: "a"` -- `test!` an
  `#enum` -- died at `INVALID_IR site 100 (emit-value-operation/compat#36)`;
  it now reports upstream's
  `*** Compilation Error: type mismatch on setting path: p/a`. Upstream's
  check is `comp-path-assign` in system/compiler.r, and
  `compiler/rsir-frontend.red`'s `stack-assignment` now applies
  `compatible-types?` (from the return-type fix) to the pair it already
  holds, `source-ref` and `target-ref`, just before it emits the SET op.
  Two pointer-shaped pairs the strict rule would otherwise reject, both
  found by the suites and not by the self-compile:
  * A literal array or binary is the address of its first element, so it
    fills any pointer slot -- that is how the Redbin payload reaches
    `system/boot-data`, a `byte-ptr!` (system/compiler-rsir-core.red). The
    literal's own flags are 0 (`stack-array-literal` puts the inline flag on
    the hidden global that owns the bytes), so this cannot be a test on
    flags.
  * A bare `pointer!` names no pointee, so anything pointer-shaped fills it.
    `ptr-ptr!`'s element is exactly that here (builtin-pointees), and a
    thread `handle!` -- a `pointer! [integer!]` -- is stored through it in
    system/tests/source/units/atomic-test.reds.
  Only a **path** is checked. Upstream also checks a set-word, with a
  different message (`attempt to change type of variable:`); that one is not
  ported, because this fork's word assignment infers and pins types in
  several places the upstream check never sees, and no test pins it.
- The Red/System **compiler** test suite (`run-red-system-compiler-tests.red`)
  went 84/124 on 142, 96/124 on 144, 120/124 on 145, 122/124 on 147,
  123/124 on 149 and 124/124 on 150 -- and is still 124/124 at **185**
  (0 failed, 70 compile-failures, the same bookkeeping as the Red suite's).
  It reads the compiler from **`RED_SYSTEM_COMPILER`**, not `RED_COMPILER`;
  with the wrong name it quits in 300ms saying so, which looks like a crash.
  Takes ~1 minute.
- Fixed: **`return` never checked its value against the declared return
  type.** `func [return: [integer!]][return true]` reported `*** Compilation
  Error: native codegen rejected invalid RSIR`; it now reports upstream's
  `wrong return type in function: foo`. `compiler/rsir-frontend.red` gained
  `integer-width`, `signed-integer?`, `lossless-integer-cast?` and
  `compatible-types?` -- the port of upstream's `same-type?` plus
  `lossless-integer-cast?` -- and `stack-return` applies it, which is where
  it belongs: the error is reported against the function that returns it,
  before the enclosing expression sees anything. That is return-test's
  "return as last statement in until block"; `until [return 123]` still
  reports `UNTIL requires a conditional expression`, so `stack-return`
  clearing `last-type` is right and was not the bug.
  Note `null` stands in for anything that is not a number or a logic:
  `runtime/allocator.reds` has `return null` in a `series!` function, and
  `series!` is a struct alias whose values are pointers. The first cut
  allowed null only for `pointer!`/`c-string!`/`function!` and broke the
  View backend on that line -- the suites are what found it.
- Earlier baseline: `build/self-hosting/merge-red64/hybrid-compiler107.exe`
  (102->106->107, output 6259712 bytes; 106 and its own rebuild differ in 5
  bytes -- PE checksum, PE timestamp and the output file name). It carries the
  System V argument classification for Linux-X86-64: `plan-storage` and the
  function prologue walk the parameters with separate integer and vector
  counters (6 GPR, 8 XMM) instead of Win64's single slot counter, and stack
  arguments sit at `rbp+16` and up rather than behind 32 bytes of shadow space.
  Verified with a pinned `SOURCE_DATE_EPOCH`: 98 and 99 differ in 24 bytes --
  the PE timestamp, the checksum, the output file name baked into the image,
  and the absolute addresses that the variable-length build date shifts.
  On top of that classification, it carries the fixes that kept *Red*
  (not just Red/System) from running on Linux:
  * `compile-module` published the module body as `***_start` before lowering,
    which froze its locals count at zero and left every local outside the
    published frame (`INVALID_IR site 70` on every Red program).
  * ELF emitted one `DT_NEEDED` per `#import` block instead of one per library.
  * A variadic `float!` was also copied into the integer register of the same
    slot, the Win64 rule; under System V that overwrote an earlier argument.
      (`sprintf buf "%.16g" 1.5` put 1.5 over the format string.) SysV variadic
      calls now also publish the vector-argument count in AL.
  * An imported *variable* is read through the same GOT slot a call uses, and
    nothing ever calls it, so the lazily bound slot still held its PLT
    trampoline: ELF now emits `DT_BIND_NOW`. `environ` was additionally
    declared `[integer!]`, which read only the low half of a 64-bit pointer.
    Both of those were workarounds for the real gap: the linker could not tell
    a variable import from a function import, so it used the call's slot for
    both. See the imported-variable bullet at the 160 baseline.
  * A CALL parks the located last argument in a scratch register while it loads
    the earlier ones. That was XMM4, which Win64 never spends on an argument
    but System V fills as its fifth vector one, so a call with five or more
    `float!` arguments handed the callee the fifth value in the last slot
    (`sprintf buf "%.1f ..." 1.5 ... 8.5` printed 5.5 eighth). The scratch now
    sits above both the argument registers and the allocator pool, and that
    pool itself had to move above XMM0-XMM7 for the same reason: a value it
    keeps alive for a call must survive that call's own argument loads. Both
    moves are cheap, but note that no unit in either suite allocates a vector
    register today, so the pool one is latent rather than an observed failure.
  * The hidden-return copy loaded the aggregate's address into RDI on System V
    instead of RCX. `copy-indirect` reads its source from RCX, so a function
    returning a 16-byte union copied out of whatever RDI held at the time
    (`union-by-value-3`).
  Windows regression at this baseline: 40/40 Red/System units compile and pass,
  and 57/57 Red units compile and pass. Linux x86-64 on WSL Ubuntu 24.04: the
  Red suite compiles 57/57 and 57/57 run clean, and 40/40 Red/System units
  compile and run with 39 byte-identical to Windows (`lib-test` `#switch`es a
  sixth test in only on Windows).
  * A variadic call on ARM64 gave its trailing arguments the Apple rule --
    on the stack, even with registers to spare -- while AAPCS64 carries on
    with the normal sequence. `prin-int` is `printf "%i"`, so every integer
    printed as whatever x1 held and every unit reported the wrong totals.
    `abi-parameter-location` now publishes the registers the fixed parameters
    took and the trailing ones continue from there (Apple is untouched).
  * **Fixed: an ARM64 stack argument was packed at its natural width.**
    AAPCS64 gives every stack argument a whole eight-byte slot, but
    `abi-parameter-location` advanced the stack offset by `width` -- 4 for an
    `integer!` or a `float32!` -- so the second and later ones landed short of
    where the callee reads them. `checkBigOverflow 1 2 3 4 5 6 7 s3 8 42` --
    seven integers fill x0-x6, so the 16-byte `big!` and both trailing ints go
    to the stack -- wrote `tail` at sp+16 and `marker` at sp+20, where gcc
    puts them at sp+16 and **sp+24**; the callee read `marker` from unwritten
    space and answered 0. Every stack branch now advances by `align size 8`
    and aligns to `max(alignment, 8)`, which is exactly what
    `abi-trailing-argument` already did -- its own comment said the rule, the
    fixed-parameter path just did not follow it. Only the *native* boundary
    can notice: both sides of a Red/System-to-Red/System call ask the same
    function, so internal calls were self-consistently wrong and stay correct.
    `struct-x64-test` goes from 627/628 to **628/628** on Linux-ARM64, its 40
    units still report 0 failed assertions, and the Windows Red/System suite
    still reports 12680 assertions / 12680 passed / 0 failed.
    `arm64-codegen.reds` is shared with Darwin-ARM64, and the Mac was down, so
    the change was checked against Red instead of left to trust: 184 and 185
    emit **different bytes** for `parse-test`, `object-test`, `series-test`
    and `function-test` on Linux-ARM64 -- a call with more than eight
    arguments now reserves a wider outgoing area, so frame offsets move --
    but the four run to identical totals with 0 failures on the armbian box
    (parse 1518, object 658, series 1119, function 147, the same numbers the
    Mac reported at 179). The change is behaviourally inert for Red, and only
    a native call that spills can tell the two apart.
    It does **not** leave Darwin-ARM64 codegen untouched, and the control is
    what shows it: cross-compiling `red-toolchain-darwin-hybrid.red` with 184
    and with 185 gives the same 6723488 bytes but **5911 differing bytes** in
    691 runs, all of them frame offsets and immediates, while the same pair on
    `red-toolchain-windows-hybrid.red` -- which the change cannot reach --
    differs by **16**, the build-clock noise floor. So Darwin gets the same
    narrow change Linux-ARM64 gets: any call with more than eight arguments
    reserves a wider outgoing area. Apple's ARM64 ABI follows AAPCS64 for
    non-variadic stack arguments, so the wider slots are right there too; what
    is missing is a run, not a reason.
- The two ABI changes are now checked against **Red** as well as Red/System,
  which is what actually exercises a native call from the runtime:
  `JOBS=4 bash build/linux-hybrid/red-suite-linux.sh
  build/self-hosting/merge-red64/hybrid-compiler185.exe Linux-X86-64 wsl`
  compiles **57/57** and runs **57/57 clean, 57 exit-0**, 16854 assertions
  with **0 failed** -- and every per-unit count is the one the Mac reported at
  179 (logic 95, integer 1760, float 1793, char 35, series 1119, append 327,
  path 60, object 658, map 86, function 147, loop 58, parse 1518, make 3,
  convert 451, mold 54, load 225, lexer 929, evaluation 294, binding 25,
  type 42, routine 22, recycle 39, comparison 558). That is the System V
  change's real regression gate, since every one of those units reaches the
  runtime through native calls. Allow ~16 minutes: the 57 units cross-compile
  in parallel and then run in one WSL session.
  The same driver on **Linux-ARM64** (`... Linux-ARM64 armbian`, ~20 minutes)
  compiles **57/57** and runs **57/57 clean, 57 exit-0** with the same 16854
  assertions and the same **0 failed** -- and a diff of the per-unit counts
  against the X86-64 run is empty, unit for unit. That is the strongest
  available evidence for Darwin-ARM64 short of running it: `arm64-codegen` is
  shared, the Red runtime reaches it through the same native calls, and both
  Linux targets agree on every count. Output dirs are target-specific
  (`red-<compiler>-x86-64` / `red-<compiler>-arm64`); without that the two runs
  overwrite each other's logs.
  Linux ARM64 on `armbian` and Linux-X86-64 on `wsl`, at 185: **41/41
  Red/System units compile, 41/41 run, 0 failed assertions on both**. Three
  units' output differs from the Windows reference, all source-gated and none
  failing (`int64-test` is `#if`'d to 32-bit and ARM targets, `pointer-test`
  keeps an x64-only group, `lib-test` takes a Windows-only include) -- and that
  reference only exists up to gen 98, so a unit without one now prints `NOREF`
  instead of a false `OK`. `atomic-test` and `queue-test` used to take a SIGILL
  here: `atomic-rmw` and `atomic-compare-exchange` emitted `ldaddal`/`casal`,
  the ARMv8.1 LSE atomics, and this board's CPU is ARMv8.0. Both emit the
  load-exclusive/store-exclusive pair now (`ldaxr`/`stlxr`, see the Linux ARM64
  at 159 bullet below) and both pass.
  Closed on ARM64: the ELF writer used to patch *every* import to
  `plt + 16*(index+1)`, a branch target, which is wrong for a data reference
  (see the imported-variable bullet below). A data import now gets its own
  `.data.rel.ro` slot and an `R_*_GLOB_DAT` instead of riding on the
  `.got.plt` slot a call uses.
  Run the Linux suites with `HOST=wsl`: `wsl.exe` needs no sshd and both
  `build/linux-hybrid/{red,rs}-suite-linux.sh` accept it. `SKIP_COMPILE=1`
  reuses binaries an earlier host already cross-compiled. Prefer WSL over the
  2 GB `vps` box: `recycle-test` peaks at 1.5 GB and is OOM-killed there.
- `-d` now works for Red programs too, not just Red/System: `??` is lowered to
  `print-line`, and statements without a source location (no file, or line zero
  from synthesized code) simply contribute no line record.
- `-d` stack traces walk the whole frame chain on ARM64 as well. The code generator
  pushes the AAPCS64 `[parent frame][return address]` record, so both links are read
  through `ptr-ptr!` (pointer-sized loads): a word-wide read keeps only half of an
  address that lives above 4GB. The x86/x64 path is unchanged apart from the report
  now stopping after 40 frames.
- Earlier baseline (pre line-record): `hybrid-compiler48/49/50.exe`, output
  5947904 bytes.
- NEVER use `hybrid-compiler46.exe.stale-inconsistent` / `hybrid-compiler47.exe.stale-inconsistent`
  as a bootstrap. They were built from a mid-stage-1 working state whose frontend
  emitted the `***-on-quit` runtime-error call IR while their embedded codegen
  still rejected it (INVALID_IR site 219/246, op=16/11: FAIL terminator replaced
  by LITERAL/NATIVE system/pc/CALL sequence breaks stack-depth join validation).
- After building a new compiler from any bootstrap, always verify it by
  self-compiling the bootstrap source before adopting it as the new baseline.

# Red/System Idiomatic Patterns - Key Insights

## Reference
https://static.red-lang.org/red-system-specs.html

## ⚠️ CRITICAL UNUSUAL FEATURES (Different from C-like languages!)

### NO OPERATOR PRECEDENCE!
- `1 + 2 * 3` = `(1 + 2) * 3` = 9, NOT `1 + (2 * 3)` = 7
- ALWAYS use parentheses for intended grouping: `a < b and (c > d)`
- Exception: infix functions have precedence over prefix calls

**Key Gotchas:**
- `case` requires a `true` catch-all or **runtime error** if no match
- `switch` values must be **literal** integer!/byte! (not expressions)
- Neither has fall-through between cases
- Both can return values if all branches return same type
- No `else` keyword, use `either`
- (expr)/index, array/(idx) are invalid

## Critical Language Semantics

### 1. Integer Type (Only Signed!)
- **Only one integer type**: `integer!` is 32-bit signed (-2147483648 to 2147483647)
- **NO unsigned integer types exist** in Red/System
- **Hexadecimal literals use SUFFIX 'h', NOT 0x prefix!**
  - Correct: `9E3779B1h` or `04D2h`
  - WRONG: `0x9E3779B1` (this syntax does NOT exist!)
- Hex letters MUST be uppercase
- Only 2, 4, or 8 hex characters allowed
- `9E3779B1h` = -1640531535 in signed representation

### 2. Pointer Arithmetic
- **Pointer + integer** scales by the pointed type size
  - `int-ptr! + 1` adds 4 bytes (sizeof integer)
  - `byte-ptr! + 1` adds 1 byte
- **Array indexing is 1-based** (not 0-based like C)
- Pointer/pointer arithmetic treats both as byte pointers

### 3. Struct Layout
- Members are **automatically padded for alignment**
- Padding is target-dependent (4-byte for IA-32)
- `size?` returns size including padding

### 4. Type Conversions
- `as` keyword for compatible type conversions
- Integer to byte! truncates values above 255
- No sign extension on truncation
