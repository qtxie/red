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
- Current baseline: `build/self-hosting/merge-red64/hybrid-compiler133.exe`
  (132->133, output 6338048 bytes; 134 is the same size). It also compiles the
  headless test View backend (`Config: [GUI-engine: 'test]`, e.g.
  tests/view-headless-interpreter.red, 7.3M IR instructions, 2490880 bytes) and
  the 16 unit files under tests/source/view/ run clean through it: 16/16 with
  246 assertions, 0 failures. `red-console.exe
  tools/self_hosting/run-red-view-headless-tests.red` (RED_COMPILER pointed at
  the binary) drives the whole suite. Windows regression: 57/57 Red units and
  40/40 Red/System units, with the Red/System runner reporting 12052 assertions
  and 12052 passed. Fixed point: 133 and 134 emit byte-identical output apart
  from 14 bytes -- PE timestamp, checksum, the output file name and the two
  `movabs rax` immediates that carry the compiler's build clock.
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
- Still open, unrelated to the above: an `#import` library spelled with an
  absolute path makes the PE writer prefix the *output directory* to every
  import name, so dylib-auto-test.exe ends up importing
  `E:\...\BUILD\SELF-HOSTING\E:\...\BUILD\SELF-HOSTING\KERNEL32.DLL` and dies
  with STATUS_DLL_NOT_FOUND. Reproduces on 132 as well; plain relative
  imports (lib-test) are clean.
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
