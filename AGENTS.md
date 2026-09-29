- run/interpret Red script: `D:\EE\QTool\red-console.exe red-script-path.red` for quick testing
- Be careful with red-console.exe or tests - sometimes they don't exit properly and burn CPU
- dumpbin: C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\dumpbin.exe
- cdb: C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe
- Think carefully before writing code. Code should be idiomatic Red/Red/System: elegant, direct, fast, no unnecessary overhead
- Do a git commit when finishing a major task
- sudo password: toto

## Build System

- GUI console builds on all platforms: `-t Windows-X86-64` (GUI), `-t macOS-ARM64` (app bundle), Linux targets (plain executable)
- Windows has two targets: `MSDOS-X86-64` (CLI, subsystem 3) and `Windows-X86-64` (GUI, subsystem 2, needs `Needs: View`)
- Use `windows-target?` to check Windows family (not `find target "Windows"`)
- Target registry: `system/target-registry.red` is the only place targets are declared
- Toolchain resources are generated at build time in `build/generated/red-toolchain-resources.generated.red` - always regenerate before building toolchain
- Use `build-red-toolchain.red` which regenerates automatically
- Delete entire output directory (not just libRedRT.dll) to force runtime rebuild

## Current Baselines

- **hybrid-compiler291.exe** (290->291, 6571008 bytes, fixed point): a bitmap record publishes, in a tagged trailing word, how far its frame reaches below the slots it counts
- **hybrid-compiler282.exe** (281->282, 6549504 bytes, fixed point): the frame bitmap carries a handle stream beside the pointer one
- **hybrid-compiler279.exe** (278->279, 6532608 bytes, fixed point): node-handle! is a typed RSIR scalar, folded to integer! by both backends
- Compare generated output, not compiler image (build date shifts addresses)
- Use equal-length output names when comparing generations (embedded path affects size)

## Test Suites

- Red/System suite: 10601 tests / 12747 assertions / 0 failed (Windows x64)
- Red suite: 9305 tests / 18001 assertions / 0 failed (all platforms)
- View headless: 148 tests / 249 assertions / 0 failed
- Native View (Windows): 107 tests / 507 assertions / 0 failed
- Compiler tests exit 1 by design (compile-failures are expected); use claimed/unclaimed tracking
- CI uses `pwsh` (PowerShell 7), not Windows PowerShell 5.1
- Native View suite takes ~6 minutes with block-buffered output - don't attach debugger

## Key Technical Facts

### ARM64 Specific
- Deep expression stack (past slot 7) uses X8 for division quotient
- Register-homed pointer locals need shadow frame slots for GC
- Stack arguments: AAPCS64 rounds to 8-byte slots, Apple packs at natural alignment
- Variadic imports need `[[variadic]` declaration
- Frame displacement > 255 bytes needs destination register for address materialization
- ARM64 dev-mode binaries DO run under qemu-user; `undefined symbol: curl_easy_strerror` is a stale stub `~/qemu-stublibs/libcurl.so.4`, not a qemu limit

### Collector/GC
- Collector compacts series frames - raw buffer pointers die at allocations
- Use cell index (move-invariant) instead of raw pointers across allocations
- Conservative stack scanning: gap words cannot root series, only declared locals
- `RED_GC_STRESS=N` forces collection every N allocations for testing
- Dev mode bitmap selection: check if return address is in runtime image
- Frame bitmaps are two streams over one slot numbering: pointers, then node-handle! flags
- A handle sharing a slot's high half (member at offset 4) is not bitmap-visible, and the probe now rejects it - only naming the slot in the handle bitmap roots it
- Probe candidates must fill their whole word (a 64-bit address's low half can land inside the registry span); `stats/probe-alias` counts the rejections
- Dev-mode unit binaries run `libRedRT.dll` beside them - delete it or the output dir, or they measure the old runtime
- `hashtable!` names its five buffers by `node-handle!`: marking a table reads the header and never rewrites it (`collector/keep-handle` takes a handle, `keep` the slot holding one)
- `hashtable!/stride` is CELLS per node-key entry; `put-key`'s `alloc-tail-unit` wants bytes - redbin-codec/money/reactivity only catch a wrong size, and only at `RED_GC_STRESS=500`

### Codegen
- ARM64: X16/X17 are scratch, X19-X28 are callee-saved homes, X9-X15 are value temps
- x64: System V ABI (Linux) vs Win64 ABI - different register counts and stack rules
- Import variables vs functions: different relocation types (GLOB_DAT vs PLT)
- `#u16` literals must be interned as 16-bit units for alignment
- Aggregate ABI: System V classifies per eightbyte, Win64 by total size
- Frame bitmap records are written by both backends and read by the collector; only `system/tests/source/units/stack-bitmap-test.reds` (Red/System suite) covers the record itself

### macOS/Darwin
- `Face-handle!` is `int64!` on ARM64, `integer!` on x86-64
- GTK3 handles need externals registry (pointers don't fit in 32-bit `handle!`)
- `objc_msgSend` is not Apple-variadic - trailing args go in registers
- `NSScreen` objects are recreated - use `CGDirectDisplayID` for stable identity
- `__mod_term_func` doesn't work - use `atexit` instead
- Dev mode: `@loader_path/libRedRT.dylib`, release: embedded runtime

### Windows
- GDI+ startup: `DebugEventCallback` must be `int-ptr!` (pointer on x64, integer on IA-32)
- PowerShell extensionless paths resolve as documents, not programs
- `$LASTEXITCODE` unset = process didn't run, treat as failure

## Common Pitfalls

- `f x = y` parses as `f (x = y)` - parenthesize: `(f x) = y`
- `find` is case-insensitive - use `/case` for case-sensitive
- `case` needs `true` catch-all or runtime error
- `switch` values must be literal integer!/byte!, not expressions
- Missing call argument consumes next token - pass all arguments explicitly
- `trim` puts line feed back - use `trim/tail` or `trim/all`
- `lowercase` mutates in place
- `join` on two `file!` errors - use `rejoin`
- `FFFFFFFFh` is -1 (32-bit signed)
- GUI app over ssh: stdout is lost, use file output
- `halt` in console returns to prompt, doesn't exit - use `quit`
- `-o foo.app` yields `foo.app.app` (extension appended)

## Reference
https://static.red-lang.org/red-system-specs.html

## ⚠️ CRITICAL UNUSUAL FEATURES

### NO OPERATOR PRECEDENCE!
- `1 + 2 * 3` = `(1 + 2) * 3` = 9, NOT `1 + (2 * 3)` = 7
- ALWAYS use parentheses: `a < b and (c > d)`
- Exception: infix functions have precedence over prefix calls

## Critical Language Semantics

### 1. Integer Type (Only Signed!)
- `integer!` is 32-bit signed (-2147483648 to 2147483647)
- NO unsigned types
- Hex uses SUFFIX 'h', NOT 0x: `9E3779B1h` (correct), `0x9E3779B1` (wrong)
- Hex letters MUST be uppercase, only 2/4/8 characters

### 2. Pointer Arithmetic
- `int-ptr! + 1` adds 4 bytes, `byte-ptr! + 1` adds 1 byte
- Array indexing is 1-based
- Pointer/pointer arithmetic treats both as byte pointers

### 3. Struct Layout
- Members automatically padded for alignment
- Padding is target-dependent
- `size?` includes padding

### 4. Type Conversions
- `as` for compatible conversions
- Integer to byte! truncates (no sign extension)
