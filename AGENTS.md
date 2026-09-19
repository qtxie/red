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
- Current baseline: `build/self-hosting/merge-red64/hybrid-compiler148.exe`
  (147->148, output 6359552 bytes; 148 self-compiles to 149 at the same size
  with `SOURCE_DATE_EPOCH` pinned -- 147 is the same size, the two changes
  happen to land in the same PE granularity).
  148 adds the dev-mode `#system-global` fix below to 147, which adds the
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
  the binary) drives the whole suite. Windows regression: 58/58 Red unit files
  (57 units plus unicode-test, now run in dev mode without `-r`) -- 8812 tests,
  16893 assertions, 16893 passed, 0 compile failures -- and 40/40 Red/System
  units, with the Red/System runner reporting 12680 assertions, 12680 passed,
  0 failures -- up from 12052 because dylib-auto-test finally loads and
  struct-x64-test finally links.
  All four suites are clean on 148: Red/System 12680/12680, Red units
  16893/16893, View headless 246/246. The Red compiler tests are 261 passed /
  2 failed (below), up from 251/12 on 145 -- three are the `#system-global`
  group, seven the syntax-error wording group; before those the twelve were
  the cast group, the twenty-two before them the conditional group and the
  last two a wrong path in output-test. The Red/System compiler tests are
  122 passed / 2 failed, up from 84/40 on 142 -- the last two gained are the
  callback spec check.
  Release mode now has a full-suite number: `RED_COMPILER_ARGUMENTS="-r"` on
  145 gives 8820 tests, 16921 assertions, 16921 passed, 0 failures, 0
  compile failures. It is *more* than dev mode's 16893 by 28 assertions and 8
  tests, not less: a handful of tests only run when the runtime is linked in.
  It costs ~35 minutes for 58 files, which is why nobody had run it. The
  earlier `-r` spot check of the seven collector-heavy units on 142 agrees:
  series 1119/1119, append 327, make 3, convert 451, redbin-codec 1762,
  recycle 39, unicode 67/67.
  Fixed point: with `SOURCE_DATE_EPOCH` pinned, 148 self-compiles to 149 at
  the same 6359552 bytes. Unpinned they differ in ~1600 bytes, which is the
  clock -- the build date is a variable-length string, so it shifts every
  absolute address by one and repaints a few thousand bytes. Pin it and two
  self-compilations of 142 differ in 4 bytes, so the chain genuinely
  converges. (140 vs 141 happened to differ by only 15 because that run's
  clock string kept the same length.)
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
  (next entry). What is left there: #4190 (`face!` needs the View backend)
  and the #4526 abort below.
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
- Still open in that suite: `regression-test-redc-5.red` stops at #4526. The
  test is `do bind [probe 1 ** 2] context [**: make op! func [x y][x + y]]`
  and it prints `1` and then fails with `** has no value`, so `qt/output` is
  not loadable and the bare `--assert 3 = load qt/output` on the next line
  raises -- which aborts the rest of the file. Everything after #4526 is
  therefore unmeasured, not failing. Two things are wrong: the compiler drops
  the binding `do` was given and treats `1 ** 2` as two expressions, and the
  harness has no way to survive an assertion whose expression raises.
  `system/tests/source/units/libs/structlib.dll` is a 32-bit image, so
  struct-x64-test.exe used to die with STATUS_INVALID_IMAGE_FORMAT before it
  ran; the runner now copies `libs/structlib-x64.dll` for X86-64 targets and
  that test runs 155 tests / 621 assertions with 0 failures, bringing the
  Red/System suite to 12680 assertions, 12680 passed, 0 failures. Build the
  64-bit library with `cl /LD /O2 /MT /Fe:structlib.dll structlib.c` from
  `system/tests/source/units/libs/`; the 32-bit dll is left alone so 32-bit
  targets keep working.
- The standalone toolchain builds and runs again:
  `hybrid-compiler140.exe -r -t Windows-X86-64 -o red-toolchain.exe
  red-toolchain-windows-hybrid.red` produces 7609344 bytes
  (`build/red-toolchain/windows-x64/red-toolchain-140.exe`; it needs
  `build/generated/red-toolchain-resources.generated.red`, which
  `generate-toolchain-resources.exe` regenerates). `--self-check` reports 276
  resources, and it compiles and runs a Red program both with `-r` and in dev
  mode -- dev mode builds a fresh libRedRT next to the output, so a stale one
  there is what makes it look broken. It also cross-compiles all four targets:
  Linux-X86-64 (ELF x86-64), Linux-ARM64 (ELF aarch64) and Darwin-ARM64
  (Mach-O arm64). The Phase E note in `handover-quick-test-red-port.md` saying
  `red-toolchain.exe` SEGFAULTs on every invocation is stale -- the checked-in
  binary answers `missing source file` and exits 1.
- `red-console.exe tools/self_hosting/run-red-compiler-tests.red` (the nine
  scripts under tests/source/compiler/) with 140: 262 assertions, 251 passed,
  12 failed, 27 compile-failures. It takes a filename argument to run one
  script. Two classes of failure:
  - The 27 compile-failures are bookkeeping, not breakage: those tests feed the
    compiler deliberately broken snippets, and the runner counts every expected
    compile error as a failure.
  - `preprocessor-test`'s "Macros & #do" used to lose all ten of its assertions
    because `maximum-of` does not exist in this environment at all -- not for
    macros, not for ordinary programs. `tests/source/units/preprocessor-test.red`
    already guarded against that with a `#do [unless value? 'maximum-of [...]]`
    (commit 4c4957b84, "to support expansion from interpreter"); the compiler
    copy was ported later and never got the guard. It has it now and the file
    is 43/43. What is left is #2671 (four assertions) plus seven singles.
  No earlier real-compiler number exists for this suite; 138 scores 240 passed
  / 23 failed on it, so the c-string literal fix also cleared issue #832.
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
- Still open, first measured this session: the Red/System **compiler** test
  suite (`run-red-system-compiler-tests.red`, never run before) reports 84/124
  on 142, 96/124 on 144, 120/124 on 145 and 122/124 on 147. The two left:
  * 1 wants `type mismatch on setting path: p/a` (enum-redec-8), dies at
    `INVALID_IR site 100 (emit-value-operation/compat#36)`. Its check lives
    upstream (`comp-set-path`) and was never ported. Note it is not the same
    *size* as the cast and condition checks: those are local predicates at one
    emission point, while this one needs assignment type compatibility, and
    the frontend still has no general compatibility predicate. That wants its
    own pass rather than being bolted on here.
  * 1 is an **ordering** difference, not a missing check:
    `foo: func [return: [integer!]][until [return true]]`. Upstream reports
    `wrong return type in function: foo` because `stack-return` leaves the
    *type of the returned value* behind, so the condition is a logic! and the
    condition check passes. Here `stack-return` clears `last-type` to 0, so
    the condition looks value-less and UNTIL's message wins. Making `return`
    publish its value's type would fix it and is probably right, but it
    changes what every caller sees after a RETURN, so it wants its own pass
    with the full suites behind it.
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
  Linux ARM64 on `armbian`: 40/40 Red/System units compile, 38 run and 3 of
  those differ -- all source-gated, none failing (`int64-test` is `#if`'d to
  32-bit and ARM targets, `pointer-test` keeps an x64-only group, `lib-test`
  takes a Windows-only include). `atomic-test` and `queue-test` take a SIGILL:
  `atomic-rmw` and `atomic-compare-exchange` emit `ldaddal`/`casal`, the
  ARMv8.1 LSE atomics, and this board's CPU is ARMv8.0. A baseline AArch64
  target needs the load-exclusive/store-exclusive loop, which additionally
  wants two scratch registers the call sites do not yet spare.
  Still open on ARM64: the ELF writer patches *every* import to
  `plt + 16*(index+1)`, a branch target, which is wrong for a data reference.
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
