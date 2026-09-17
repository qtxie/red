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
- Current baseline: `build/self-hosting/merge-red64/hybrid-compiler102.exe`
  (98->102, output 6257152 bytes). It carries the
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
  Windows regression at this baseline: 40/40 Red/System units and 57/57 Red
  units compile and pass, and hello output is byte-identical to the previous
  compiler apart from the PE timestamp and checksum. Linux x86-64: the Red
  suite compiles 57/57 and 56/57 run clean (recycle-test is OOM-killed on the
  2 GB test box; it peaks at 1.5 GB on Windows), and 40/40 Red/System units
  compile and run, 37 of them byte-identical to Windows.
  Still open: `va-dbl-10` / `va-mixed-bank-spill` (doubles that spill past the
  eight vector registers) and `union-by-value-3`, both System V classification.
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
