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
- The hybrid compiler builds only Windows X86-64, Darwin-ARM64 and Linux X86-64/ARM64 - `-t MSDOS` and any IA-32/ARM name is refused as "unknown compilation target", so a 32-bit layout can never be observed here
- Toolchain resources are generated at build time in `build/generated/red-toolchain-resources.generated.red` - always regenerate before building toolchain
- That archive is the only route a `runtime/` edit takes into an artifact: a program compiled by binary N runs *N's* archive, while N's own GC came from N-1's. So one fresh toolchain tests a runtime change in a program, and a second generation tests it in a compiler's own GC. Discriminator that an artifact carries the edit: a new `print-line` in `collector/dump-stats`, run with `RED_GC_STATS=1`
- Because that generated file is shared, a toolchain build changes what every *other* compile embeds mid-flight: per-attempt output sizes are only comparable within one generated-file state
- Use `build-red-toolchain.red` which regenerates automatically
- Delete entire output directory (not just libRedRT.dll) to force runtime rebuild

## Current Baselines

- **hybrid-compiler293.exe** (292->293, 6577664 bytes, fixed point): the pairs the stack scan sorts are counted off the write cursor, so the sorted span and the relocated span cannot drift apart
- **hybrid-compiler291.exe** (290->291, 6571008 bytes, fixed point): a bitmap record publishes, in a tagged trailing word, how far its frame reaches below the slots it counts
- **hybrid-compiler282.exe** (281->282, 6549504 bytes, fixed point): the frame bitmap carries a handle stream beside the pointer one
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
- The stack scan's sort span and stored span are one span: `nb` is read off the write cursor, because qsort permutes every pair it covers while the relocation sweep stops at `stk-tail`. Counting "stored or pinned" instead sorts past that bound and orphans a live `(value, slot)` pair, whose slot then keeps a raw pointer into reclaimed memory
- `stack refs : N pairs sorted, M relocated` (RED_GC_STATS) witnesses that bound: a toolchain self-compile relocates ~10% of its recorded pairs, so an orphan shows up there, while a small stress unit relocates ~0.02% and shows nothing
- `RED_GC_STRESS=N` forces collection every N allocations for testing
- The GC instruments are three independent switches: `RED_GC_STATS` (counters + the throttled `dump-stats`), `RED_GC_AGE` (`age-series-frames`, and the nursery ratios it feeds), `RED_GC_TIME` (one cumulative `gct <cycles> <mark> <root> <tables> <value-stk> <other-roots> <rebuild> <scan> <sweep> <total> <cells> <walks> <series-walks>` line per cycle - 13 values: the five mark parts in envelope order summing to mark, then the three run counters, printed *after* the stamps so the write is off the clock). Sharing one flag was the bug: the age walk is a second full pass over every live header, so it landed inside the "mark" number the same dump reported, and `RED_GC_TIME` alone times the production cycle with no counter traffic in it
- The three run counters (`stats/cells`, `memory/handle-hits`, `memory/series-walks`) ride `count? = any [stats? time?]`, set in `collector/init`, not `time?` alone: a counter that only one gate turns on reads zero in the report that shows it. They are `float!` because a cumulative `integer!` wraps at 2^31 and a run does 1.59e8 walks
- Timing rows never run with `RED_GC_STATS` on: the dump puts 30 lines of I/O inside the measured window. A counter is ~20ns (the scan phase does ~10,340 header reads *and* increments in 0.22 ms/cycle), so the instrument is not the cost - the I/O is
- The residual against the 266 era is **not** the collector: with cycles (219 vs 225) and committed capacity (2.51..5.06 vs 2.44..5.19 MB) at parity, `do-mark-sweep` costs 515 ms/run against 607 one round and 652 against 614 the next - inside the era's own round-to-round spread - while the wall gap holds at 480 ms/run. So the whole gap is mutator-side. Within the cycle the work redistributed (mark +62%, scan -70%, sweep -37%), and the `gct` line's mark split (six of its 13 columns: mark, then root block / tables / value stack / other roots / inventory rebuild, which sum to mark) says all of the growth is `mark-block root`: 1.46 to 1.90-2.38 ms/cycle, every other sub-envelope at or below 0.008. That falsifies the eager-run-publishing guess and prices Branch A's items at or under 77 ms/run each. The shared cost this bullet used to name - `resolve-node`'s two dependent loads against the 266 era's one - is **false**: both eras read three dependent words through a two-level table (HEAD `chunks` -> `chunk/slots` -> `slot/value`; 266 `entries` -> `entry/value` -> the caller's `node/value`) with the range check verbatim identical, so registry depth is off the era bill entirely. Reproduce with `build/gc-speed/step0-build.sh` + `step0-run.sh 6`
- Counted, not timed (`gct`'s last three columns, instrumented at the same source sites in both eras): cells examined per cycle are **equal** (4.16e4 in both, at 219 vs 225 cycles) while `mark-block root` costs 1.36 -> 2.08 ms/cycle, so the mark growth is +10 ns *per cell* - price, not work - and the structural candidate left inside that envelope is P5's mark queue versus the 266 recursion (`630c5a927` is not an ancestor of `dc23247ba`). On the mutator side the runtime resolves **1.59e8** handles per run against the 266 era's **1.00e8** (+59%) at equal allocation and equal cadence, ~80% of the walks from series-buffer access in both eras, which is the whole 470 ms gap at ~8 ns a walk. The cause of the +59% is unattributed, and "resolve 59% less" is a larger prize than "resolve one load faster"
- The walk counter is itself on the measured path: ~1.5 ns per walk, read by running the same binaries with `STEP0_GATE=` (every gate off) - p25 went 0.418 -> 0.401 in HEAD and 0.370 -> 0.354 in 266. So read *counts* from a counter-on run, quote *counter-off* p25 for the size of a gap (470 ms, not 550 ms), and run ablation arms with the counters off
- The pin harness snapshots the working tree before pinning and restores from that snapshot, and pins with `git restore --source=<sha> --worktree`, never `git checkout <sha> -- <paths>` - the latter also writes the index, and 15 runtime files then look staged to whatever commits next. Because a `-r` program takes `runtime/` from disk at *program* build time, every path a pin touches has to be put back, not just the one the arm varies on
- The era arms hold **codegen fixed**: every arm is compiled by the same compiler binary and only `runtime/` is pinned, so what the backends emit for the probe is a constant across arms and cannot explain an era gap - per-call bitmap records and handle streams stay live only against compiler266, where the binaries differ (and that gap is ~3.6%, not 13%)
- Before believing a small delta, read the null pair: three builds of *one source* through `STEP0_BINS="fix|...;null|...;null2|..." step0-run.sh 8` give cycles 219 in all three, p25 within 0.002s, wall within 1.1%, GC ms/run within 13 - while the same binary's median GC total moved 137 ms between two sessions. So score candidates in p25 wall, and treat any GC-ms difference under ~140 ms as no finding
- `stk-refs` pairs are written by the stack scan (`collector.reds:2190`, `:2239`), not at call time - the cost is inside the scan envelope (0.17-0.22 ms/cycle), which is why a call-heavy probe is the only thing that can see it
- Cadence is bought with capacity: `alloc-series-buffer` grows the frame inventory once the free space across *all* series frames falls under half the live volume (`runway-short?`). Reading the slack of the one frame `find-space` hands back instead (compaction fills frames top-down, so that is the most packed one) made whether a program acquires a frame an accident of live layout - one probe ran 669 cycles on 3MB of frames where the same demand cost 225 cycles on 5MB
- Dev mode bitmap selection: check if return address is in runtime image
- Frame bitmaps are two streams over one slot numbering: pointers, then node-handle! flags
- A handle sharing a slot's high half (member at offset 4) is not bitmap-visible, and the probe now rejects it - only naming the slot in the handle bitmap roots it
- Probe candidates must fill their whole word (a 64-bit address's low half can land inside the registry span); `stats/probe-alias` counts the rejections
- Dev-mode unit binaries run `libRedRT.dll` beside them - delete it or the output dir, or they measure the old runtime
- `hashtable!` names its five buffers by `node-handle!`: marking a table reads the header and never rewrites it (`collector/keep-handle` takes a handle, `keep` the slot holding one)
- `hashtable!/stride` is CELLS per node-key entry; `put-key`'s `alloc-tail-unit` wants bytes - redbin-codec/money/reactivity only catch a wrong size, and only at `RED_GC_STRESS=500`
- The registry entry *is* the node record: `node!` is a slot address, so a reference is handle -> buffer, not handle -> node -> buffer. Chunks of `registry-chunk-slots` (8192) slots are `allocate-virtual` and never move, merge or compact; only the chunk table reallocs
- Node frames are gone (`node-frame!`, `alloc-node-frame`, `compact-node`, `do-node-cycle`, `collect-node-frames`, the `refs` relocation map, `stats/nodes-cycles`) - a raw `node!` stays valid across any number of cycles, so nothing needs rewriting
- `node-registry/used` is the O(1) live-entry count `memory-info` reads at verbose 1; `debug-tools/chunk-bound` and `collector/check-registry` are the per-chunk / free-list walks
- A `-d` build of a Red program reaches only the symbols listed in `system/utils/libRedRT-exports.red`; a test of runtime internals (`registry-slot`, `node-registry`, ...) must be built `-r`, which embeds the runtime
- A callback written in user code and stored via `externals/register`/`register-node` never runs when the *runtime* dispatches it in a release build of a Red program (both the native and node path) - don't gate on observing it
- An interior pointer is answered from the run the frame publishes for that cycle (`frames-list/runs`): a run only extends, is resumable, and a candidate is answered once the frontier passes it - so no header is read twice in a cycle. Every block address dies at the next `rebuild`
- GC run counters are per-cycle and printed in the last dump: a cumulative `integer!` overflows at 2^31 (redbin-codec passed a billion header reads)
- `Red/System` `if` has no else block - `if c [..][..]` is "unsupported expression"; use `either`
- `declare context!` does not zero a pointer member - use `alias struct!` + `declare`, whose members start at zero
- Series flags bits 5-7 are free: `flag-unit-mask` (FFFFFFE0h) preserves them, `get-unit-mask` (1Fh) never reads them, and `alloc-series-buffer` assigns the whole word - so a buffer starts at age 0 with nothing in the allocator knowing the field
- The age pass counts age in *cycles*, so the period is what makes a 3-cycle window mean 600 allocations or 300000 - and `RED_GC_STRESS` at 20000+ does not move these units off their own trigger, so a period sweep is a repeat sweep. There is no cadence where the window both skips old live data and absorbs the churn: the nursery is measured out (proposal P4 result)
- Fixed buffers never appear in that walk: `alloc-fixed-series` builds its buffer with raw `allocate`, not from a series frame, so `gen/immune` is always 0
- `gen/*` sums are `float!` on purpose - a cumulative `integer!` wraps (recycle-test passed a billion live buffer-bytes in 400 cycles) and the ratios printed from it become lies
- Cumulative GC counters are NOT comparable across builds: three builds of one source put recycle-test's gap-pin total at 2, 0 and 1, because the unit's own code addresses feed the conservative scan. Only per-cycle decisions (`pin causes`/`pin evidence`) and assertion counts survive a rebuild; within one binary the counters are stable across runs
- Only the main thread allocates: the camera capture callbacks run on a foreign thread and touch no Red heap - Windows copies the sample into a `RedGrabberCB/stg` buffer the main thread `allocate`d and handshakes on an atomic `state`, macOS parks the JPEG `NSData` in an associated object for `snap-camera` to build the cell from. `collector/running?` was a TOCTOU over an unsynchronised two-writer bump pointer, not a guard (proposal P6)
- Red/System cannot state a compile-time size assertion: `#if`/`#either` see preprocessor symbols only, so `#either size? cell! = 16 [...]` is "unsupported issue literal". `collector/check-abi` asserts the layout at startup instead (cell! and its seven aliases, node-handle!, node! against the pointer width, the series-buffer! field shape, the registry-chunk `#define`s, the age stamp against the unit field) - it runs before any Red evaluation, so a broken layout aborts the first run on that target naming the number (proposal P8)

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
- `objc_setAssociatedObject` is thread-safe - it is how the AVFoundation capture queue hands a `NSData` to the main thread without the foreign thread touching the Red heap
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
