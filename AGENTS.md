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
- A `runtime/` edit reaches a `-r` *program* from **disk**, at program-build time: measured by adding a `print-line` to `collector/dump-stats`, building with the existing `hybrid-compiler293.exe`, and seeing the marker print -- which is why the pin harnesses need no toolchain rebuild. The generated archive is what the *toolchain binary itself* carries: N's own GC came from the archive built into N-1, so a second generation is what tests a runtime change inside a compiler. Discriminator either way: that `print-line`, run with `RED_GC_STATS=1`
- Because that generated file is shared, a toolchain build changes what every *other* compile embeds mid-flight: per-attempt output sizes are only comparable within one generated-file state
- Use `build-red-toolchain.red` which regenerates automatically
- A `test-linux-arm64` suite failure reproduces without a CI round trip: cross-build just that unit here (`build/self-hosting/merge-red64/hybrid-compiler293.exe -r -t Linux-ARM64 -o <name> <unit>`), `scp` it to `ssh armbian` and run it on native aarch64. Build it `-r`: a dev-mode unit runs the `libRedRT.so` beside it, so shipping only the executable measures a stale or missing runtime - one such run died as `*** Runtime Error 1: access violation` where CI had reported a failed assertion
- Windows CLI Red units need `-t MSDOS-X86-64`; `-t Windows-X86-64` is the GUI target and refuses a unit without `Needs: View`
- Delete entire output directory (not just libRedRT.dll) to force runtime rebuild
- Run `hybrid-compiler*.exe` from the repo root: from any other cwd it cannot read its own relative sources and dies as `*** Where: read / *** Near : unset`, which looks exactly like a codegen failure
- A `*** Warning: type casting from pointer! to pointer!` whose payload decodes to `red>collector>mark-stack-handle` is the pre-existing one at `runtime/collector.reds:1138`, not leftover debug output from the arm under test

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
- `*/source/units/auto-tests/` holds generated sources and is gitignored: `run-red-system-tests.red` writes the dylib unit, `tests/source/units/make-run-all.red` the three batch drivers and their stripped copies
- Windows Core-Release runs `run-red-run-all-tests.red` - three driver compiles plus `runtime/unicode-test.red` rather than sixty unit compiles: 18598 tests / 36000 assertions / 0 failed, ~9 min of which is `run-all-interp`'s interpreted pass - and that pass is 447 s of collector time, not interpreted work

## Key Technical Facts

### ARM64 Specific
- Deep expression stack (past slot 7) uses X8 for division quotient
- Register-homed pointer locals need shadow frame slots for GC
- Stack arguments: AAPCS64 rounds to 8-byte slots, Apple packs at natural alignment
- Variadic imports need `[[variadic]` declaration
- Linux-ARM64 stack addresses have the sign bit set in their low 32 bits (`0x...F83DB8C0`), so `as integer!` of a frame pointer reads **negative** there and positive on Windows - a test that compares slot contents compares `int-ptr!`, never a truncation
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
- Splitting a walk count by *which side of the collector* made it is one flag, not a redesign: `memory/in-cycle?` set before the cycle's first stamp and cleared after `stats/cycles` increments, plus a `memory/cycle-walks` counter printed as a 14th `gct` column (`build/gc-speed/side-build.sh`). `handle-hits - cycle-walks` is the mutator's own traffic and is **cadence-free**, which is the only way to compare arms whose cycle counts differ. Bucketing that same quantity *by file* (`build/gc-speed/gcf-build.sh` + `gcf-patch.py` + `gcf-analyze.py`) renames every resolver call site to a generated per-file wrapper bumping one of 76 floats off-cycle, and prints `gcf <id> <count>` every 16 cycles: the ids come from a sorted union of both eras' file lists so the two tables line up, and the resolvers' *bodies* in `allocator.reds` must be excluded from the rename or the instrument counts itself
- Only cadence-free quantities survive an era comparison: the pinned 266 allocator acquires its second series frame on a layout accident, so builds of *one source* run 225 cycles (Step 13.1's log) or 669 (every build since) while HEAD holds 219 in all of them. Aggregate walks, GC ms and cycle totals are then incomparable across arms - and a decomposition is not a cross-check, since any split reproduces its own total; check instruments against *each other* instead (the side arm and the bucketed arm agree to 4e-6)
- The residual against the 266 era is **not** the collector: with cycles (219 vs 225) and committed capacity (2.51..5.06 vs 2.44..5.19 MB) at parity, `do-mark-sweep` costs 515 ms/run against 607 one round and 652 against 614 the next - inside the era's own round-to-round spread - while the wall gap holds at 480 ms/run. So the whole gap is mutator-side. Within the cycle the work redistributed (mark +62%, scan -70%, sweep -37%), and the `gct` line's mark split (six of its 13 columns: mark, then root block / tables / value stack / other roots / inventory rebuild, which sum to mark) says all of the growth is `mark-block root`: 1.46 to 1.90-2.38 ms/cycle, every other sub-envelope at or below 0.008. That falsifies the eager-run-publishing guess and prices Branch A's items at or under 77 ms/run each. The shared cost this bullet used to name - `resolve-node`'s two dependent loads against the 266 era's one - is **false**: both eras read three dependent words through a two-level table (HEAD `chunks` -> `chunk/slots` -> `slot/value`; 266 `entries` -> `entry/value` -> the caller's `node/value`) with the range check verbatim identical, so registry depth is off the era bill entirely. Reproduce with `build/gc-speed/step0-build.sh` + `step0-run.sh 6`
- Counted, not timed (`gct`'s last three columns, instrumented at the same source sites in both eras): cells examined per cycle are **equal** (4.16e4 in both, at 219 vs 225 cycles) while `mark-block root` costs 1.36 -> 2.08 ms/cycle, so the mark growth is +10 ns *per cell* - price, not work - and the structural candidate that looked left inside that envelope, P5's mark queue versus the 266 recursion (`630c5a927` is not an ancestor of `dc23247ba`), was **priced out by arm A3** (see below). On the mutator side the runtime resolves **1.59e8** handles per run against the 266 era's **1.00e8** (+59% aggregate, +71% once the walks made inside a cycle are subtracted: 1.419e8 vs 8.279e7), which is the whole 470 ms gap at a walk price arm A5 then measured instead of inferring. **The cause is named**: `e3678c897` handle-ified `ownership/table` and `hashtable!`'s five buffers, so one `ownership/check` now costs 4 registry walks (its own `resolve-node table` plus `get-value`'s three `resolve-series`) where the 266 era stored the registry *slot* and walked nothing - 1.478e7 + 4.436e7 = 5.907e7, the entire delta, in those two files, with `macros.reds` (half of HEAD's mutator walks) at parity. So the mutator did not start doing work; the same work was re-routed through the registry, and the fix (P14: cache the slot beside the handle, which is sound because slots never move) is **landed in both files**
- A walk is priced at **7.0 ns**, measured by removing one (`build/gc-speed/a5-build.sh`): `ownership` now caches the registry *slot* its handle names (`table-slot`, written once at `init` beside the handle, six read sites pass it), which deleted exactly the 1.478e7 walks 13.2b attributed there - `handle-hits` 1.58953e8 -> 1.44174e8 with cycles (219), cells (9.11824e6) and `series-walks` (1.25994e8) unchanged - and bought **-2.55% of a rep in 8/8 paired counters-off rounds** (worst round -1.52%, floor 0.03%). Two lessons: an arm that deletes exactly the count it was attributed is its own cross-check, and a fix's *mechanism* is what makes it cheap - `hashtable!`'s 4.436e7 walks are the identical call, so they are priced at 7.8% of a rep before the arm runs
- The price **transferred**, which is what made it a measurement rather than a coincidence (`build/gc-speed/a6-build.sh`): `hashtable!`'s three hot buffers now carry the same cache (`blk-slot`/`keys-slot`/`flags-slot`), 63 reads went back to the 266-era one-load shape, `handle-hits` fell 1.44174e8 -> 1.00103e8 (4.4071e7 of the 4.436e7 attributed, and `series-walks` dropped by the same 4.4231e7 - the two counters agreeing is the per-field check) - for **-7.60% of a rep, t=8.98** in 14 of 15 paired counters-off rounds (the one dissenting round was +1.93% slower). 300 ms/run against the 309 the 7.0 ns predicted. Both arms together put HEAD's registry traffic *at* the 266 era's - and P15 re-measured the pair: the era gap is **+13.4% -> +1.99% of a rep** (t=2.72, 14/16 rounds, both HEAD builds; `handle-hits` 100103379 vs 100103337, 42 walks = 4e-7 apart), while two builds of *one source* differ by 0.85% at t=0.71, so the residue is a real direction at a magnitude only 2.5x past the layout floor
- Score a paired arm over **two batches of rounds and screen the samples, not the differences** (`build/gc-speed/paired.py <raw-log>... --arm=base --arm=test`): one round of 16 had a 0.693s spike against that arm's own 0.393s median, which turned a t=8.98 result into t=2.58. The rule has to be stated before looking at the deltas - drop a round if *either* arm's p25 exceeds 1.5x that arm's median across the set - and report both the screened and unscreened numbers, because the difference between them is itself a finding about the instrument. Two traps this script exists to make impossible: two batches of the same `step0-run.sh` invocation both label their rounds `1..8`, so the log name must be prefixed onto the round key or the second batch silently replaces the first; and the round list must be deduplicated, or every pair is counted twice and t inflates by sqrt(2)
- The walk counter is itself on the measured path: ~1.5 ns per walk, read by running the same binaries with `STEP0_GATE=` (every gate off) - p25 went 0.418 -> 0.401 in HEAD and 0.370 -> 0.354 in 266. So read *counts* from a counter-on run, quote *counter-off* p25 for the size of a gap (470 ms, not 550 ms), and run ablation arms with the counters off. P15 says how much that matters: the same era pair that reads **+1.99%** counters-off reads **+0.05%** through the gate, because off -> on costs the 266 era 0.0146 s/rep against HEAD's 0.0097 - the counter branch rides the header-read loops, and the older era does ~10,340 of them per cycle where the bitmaps do far fewer. A gated p25 is a count instrument and never a comparison instrument
- Ablation arms A3 and A2 both came in **priced out**, and both kill a hypothesis: replacing the `mark-queue` with the 266 era's recursion (A3) made HEAD *faster* (+0.55% of p25, cells and walks byte-identical), so the mark growth is not P5's queue; and memoising the chunk base `registry-slot` reloads (A2) bought +0.37% while firing on 80% of the 1.59e8 walks (hit rate read from a 14th `gct` column in `build/gc-speed/a2h-build.sh`). P12's flat registry removes that load on 100% of walks, so its ceiling is ~0.5% of a rep - 4% of the era gap - and it is **deleted, not deferred**. The mechanism: the chunk table is a few dozen hot words in L1, the *entries* are scattered across 2MB chunks, and a walk's latency lives in the entry - **and A5 killed that last clause**: the walks on this probe name four fixed handles, hot in L1 for the whole run, and still cost 7.0 ns each, so a walk's latency is the apparatus in front of the load (a call, the range check, the chunk hop, two null tests, the counter branch), not a miss
- Score an ablation arm with **paired per-round p25**, not medians: mean(fix-arm) over the rounds with its standard error gives t=2.2 (a2) / t=2.97 (a3) / t=0.17 (same-source null) in one 12-round session, which resolves 0.03% - far tighter than the +-0.25% median floor. Run arms with counters off (`STEP0_GATE=`), keep a same-source build in the set, and read counts only to the 6th digit: two builds of one source differed by 823 walks (5e-6 relative) because the conservative scan feeds on code addresses
- Because a patcher writes the file list its restore loop reads, open it with `newline=''`: python's text-mode write translates `\n` to `\r\n` on Windows, `read -r` keeps the `\r`, and the loop then restores `runtime/allocator.reds^M` - which creates 38 stray files, leaves `runtime/` still patched, and silently changes what every later build in the tree embeds. `tr -d '\r'` on the read side and a `git status --porcelain runtime/` check after the restore are the guards
- The pin harness snapshots the working tree before pinning and restores from that snapshot, and pins with `git restore --source=<sha> --worktree`, never `git checkout <sha> -- <paths>` - the latter also writes the index, and 15 runtime files then look staged to whatever commits next. Because a `-r` program takes `runtime/` from disk at *program* build time, every path a pin touches has to be put back, not just the one the arm varies on
- The era arms hold **codegen fixed**: every arm is compiled by the same compiler binary and only `runtime/` is pinned, so what the backends emit for the probe is a constant across arms and cannot explain an era gap - per-call bitmap records and handle streams stay live only against compiler266, where the binaries differ (and that gap is ~3.6%, not 13%)
- The interpreted batch leg is collector-bound, and the collector's cost is the *batch shape* (`build/interp-compare/time-driver.ps1` + `run-sequential.sh`, exclusive legs, `RED_GC_TIME=1`): ours x64 release 506.5 s / 17817 assertions, upstream 32-bit (`red/red e5af90a32`, which has no x86-64 target at all - `system/targets/` holds only `ARM.r` and `IA-32.r`) 308 s / 17807, and the July x86-64 bring-up era (`5a80ff6f8`, an ancestor of this branch) 415.8 s / 16794. Of our 506 s, **447.3 s are the collector** - read off the *last* `gct` line, since a mid-run snapshot is a fraction of it (the first reading of this leg quoted mark 257.6 s from the 2903rd cycle against the run's 347.2 s). Final line, 3766 cycles: mark 347.2 s, of which `mark root` 331.5 s and `mark tables` 15.5 s, scan 7.2 s, sweep 92.8 s; the five mark parts sum to mark and the three phases sum to the total, so that line is self-checking. Leaving ~60 s of mutator. Its traffic columns are 2.0116e10 cells and 1.0613e10 walks over the run: 0.53 walks per marked cell, which at the 7.0 ns an A5-measured walk costs is 3.7 ns of the 16.5 ns a marked cell takes -- so removing *every* registry hop from the mark is a 74 s ceiling, a fifth of `mark root`, not a fifth of the leg. The cause is three tests in `recycle-test.red` - `loop 2000 [copy bb recycle]` and the 1000 and 500 versions - 3497 forced full cycles, each re-marking the *whole batch driver's* live set: 1999 cycles at a byte-constant 5,173,103 cells at 119 ms, 998 at 5,176,426 and 499 at 5,176,430 (237.8 + 116.4 + 57.9 s). That same loop alone (`build/interp-compare/bench-recycle-loop.red`) is 2001 cycles over 123,078 cells at 2.4 ms/cycle, 6.0 s against upstream's 2.6 s. Price per marked cell is the same in both arms (16.9 vs 19.4 ns), so the multiplier is x42 inventory, not a dearer mark. The batch-shape lever (giving `recycle-test.red` its own driver process, or splitting `file-list-interp`) is ruled out for this work: the task is to make 64-bit Red itself faster, so the only levers are the mark's price per cell and the sweep. Cadence is not one -- the cycle count is what the tests force
- A young generation cannot serve this leg, and the reason is structural rather than a ratio: the `recycle` native (`runtime/natives.reds`, `recycle*`) calls `collector/do-mark-sweep` directly, so 3497 of the leg's 3766 cycles are *requested* full collections -- a minor pass would not honour the call. The age pass over the batch (`RED_GC_STATS=1 RED_GC_AGE=1`, dump at 3501 cycles) shows the usual necessary condition holds with a huge margin and still does not make it work: young is 0.0 per hundred of live buffers and 0.9 of live bytes, yet only 21.8 per hundred of productive cycles were *adequate* (nothing older than the nursery died), and the minor reach is 62.9 of dying buffers against 58.8 of their bytes. On the isolated `copy`/`recycle` probe the same ratios read 0.1/0.1, so [[project-gc-cycle-cadence-cost]]'s "the nursery is measured out" transfers to this workload; the decisive fact is that the expensive cycles are the ones the program names
- "64-bit doubles memory" is measured false: peak RSS 2152 vs 2106 MB (+2.2%), steady working set 622 vs 572 MB (+8.7%), micro-bench peaks 17.7 vs 16.2 MB - and upstream's `cell!` is the same four-`integer!` 16-byte struct (`runtime/allocator.reds:42` in both trees), so nothing doubled. The 2.1 GB is a <15 s transient inside `recycle-issue-5325` (`recycle/off` plus 490 appends of 100k-cell blocks); its `block2` stays reachable from a global word afterwards, which is why the batch inventory jumps 5.17M -> 54.7M cells and every later cycle costs 500-1011 ms. A 15 s sampler sees only the 622 MB plateau, so a peak needs 100 ms sampling
- Interpreter dispatch *is* dearer on matched source, but it is a small term of the leg: a 2e6-step interpreted loop with **zero GC cycles** (`bench-eval.red`, 15 MB RSS) is 5.0 s against upstream's 3.0 s, while the same loop compiled (`bench-compiled.red`) is 1.8 s against 1.7 s - so the 1.64x suite ratio cannot be dispatch, and inside the suite ours is *faster* on the allocation-heavy rows (25.3 vs 29.7 ms per `block2 copy append/dup` clock row)
- Measuring a driver needs two things that both bit first (`build/interp-compare/time-driver.ps1`): the child's stdout must go to a *file*, because an undrained pipe blocked the run and a 506 s leg read as 832 s; and the peak must come from a fresh `Get-Process -Id` sample per tick, because `WorkingSet64` on the handle the parent owns reported 5.1 MB for a process sitting at 600 MB. Legs also have to run one at a time - two concurrent drivers inflated each other's wall by ~60%
- Before believing a small delta, read the null pair: three builds of *one source* through `STEP0_BINS="fix|...;null|...;null2|..." step0-run.sh 8` give cycles 219 in all three, p25 within 0.002s, wall within 1.1%, GC ms/run within 13 - while the same binary's median GC total moved 137 ms between two sessions. So score candidates in p25 wall, and treat any GC-ms difference under ~140 ms as no finding
- `stk-refs` pairs are written by the stack scan (`collector.reds:2190`, `:2239`), not at call time - the cost is inside the scan envelope (0.17-0.22 ms/cycle), which is why a call-heavy probe is the only thing that can see it
- Cadence is bought with capacity: `alloc-series-buffer` grows the frame inventory once the free space across *all* series frames falls under half the live volume (`runway-short?`). Reading the slack of the one frame `find-space` hands back instead (compaction fills frames top-down, so that is the most packed one) made whether a program acquires a frame an accident of live layout - one probe ran 669 cycles on 3MB of frames where the same demand cost 225 cycles on 5MB
- Dev mode bitmap selection: check if return address is in runtime image
- Frame bitmaps are two streams over one slot numbering: pointers, then node-handle! flags
- A handle sharing a slot's high half (member at offset 4) is not bitmap-visible, and the probe now rejects it - only naming the slot in the handle bitmap roots it
- Probe candidates must fill their whole word (a 64-bit address's low half can land inside the registry span); `stats/probe-alias` counts the rejections
- What the probe's *unnamed* arm costs is now measured rather than argued (`ssh armbian`, 2026-10-02): ablating it - letting only bitmap-named slots root - takes `recycle-block-12`'s residue from 60 bytes to **0** on native aarch64 with the unit green, and under `RED_GC_STRESS`. So what keeps that series alive is a legitimate small integer in a scanned slot that happens to be a live index, not an address's low half (`probe-alias` counts 639 of those on the same run) and not a dead handle in a named slot, which no rule could reject. The arm is nearly redundant - 10631 acceptances for 2 sole-rootings there, 12 suite-wide - which is why `recycle-block-12` bounds the residue at 4 KB instead of asserting the upstream decrease: retiring the arm (proposal P16) is what buys the strict assert back, and its gate is `stats/probe-new` over both suites *and* a toolchain self-compile, not one unit
- Dev-mode unit binaries run `libRedRT.dll` beside them - delete it or the output dir, or they measure the old runtime
- `hashtable!` names its five buffers by `node-handle!`: marking a table reads the header and never rewrites it (`collector/keep-node` takes the resolved registry entry, `keep` the slot holding a handle)
- The mark walk resolves each handle **once**: `keep-node` is the mark, and `keep`/`keep-raw` are one-line wrappers over it, so a caller that already holds the entry hands it down instead of walking for it again (`keep-handle` is gone). Priced on a `copy`/`recycle` probe at **-15.70% of a rep, t=-9.77, faster in 16/16 paired counters-off rounds** against a same-source null floor of -0.40% at t=-0.11, with cycles and marked cells byte-identical and `handle-hits` -47.4% (`build/gc-speed/markh-build.sh`)
- Scale a hop arm to the leg by its own traffic, not by the probe: the same dedup removes only 6.9% of the *batch leg's* walks (1.0617e10 -> 9.881e9, cycles/cells/peak unchanged) because the leg's hop ceiling is 74 s of its 434 s GC - 3.7 ns of the 16.5 ns a marked cell costs
- A leg pair is void unless the machine is idle, and the tell is the **`sweep` column**: an arm that cannot touch compaction reading a sweep delta (+7.5% once, together with every other phase) has measured machine state, not the arm. Quote `wall` only after the sweep reads flat, and swap the run order (`build/gc-speed/markh-leg-pairs.sh`)
- `hashtable!/stride` is CELLS per node-key entry; `put-key`'s `alloc-tail-unit` wants bytes - redbin-codec/money/reactivity only catch a wrong size, and only at `RED_GC_STRESS=500`
- The registry entry *is* the node record: `node!` is a slot address, so a reference is handle -> buffer, not handle -> node -> buffer. Chunks of `registry-chunk-slots` (8192) slots are `allocate-virtual` and never move, merge or compact; only the chunk table reallocs
- Node frames are gone (`node-frame!`, `alloc-node-frame`, `compact-node`, `do-node-cycle`, `collect-node-frames`, the `refs` relocation map, `stats/nodes-cycles`) - a raw `node!` stays valid across any number of cycles, so nothing needs rewriting
- A resolved registry *slot* is cacheable beside the handle that names it, because the slot never moves; a resolved *buffer* never is, because compaction rewrites `slot/value` - which is why `hashtable.reds` comments its own re-resolve points (`:1488` `:1495`, "every pointer used by the re-bucketing loop must be re-resolved from its node handle, which a move keeps current"). The 266 era exploited the first rule; `e3678c897` traded it away for a markable handle, and that trade is the mutator's whole registry-walk gap
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
- x64 `switch` has two lowerings, both inside `emit-control-operation` (`system/codegen/x64-codegen.reds:11969`): the CMP/JNE chain over case records in source order, and - at `opt-level 2` and only for >= 4 records - a balanced three-way decision tree (`sort-switch-cases`/`emit-switch-tree`). Duplicate keys are legal and the chain's first match is the semantics, so the tree sorts by key with source position as the tie-break and keeps one leaf per *distinct* key holding the record the chain would have hit first
- Displacement convention differs per backend: x64 `instruction-offsets` are the layout's *predictions* (rewritten by `relax-branches`) and the emit cursor trails them by a per-function constant, so an edge aimed from the cursor must convert first - `anchor: instruction-offsets/index - instruction-start`, then `offsets/target - anchor - written - N`. ARM64 uses `offsets/target - written` with no `instruction-start` term; do not copy the anchor rule across backends
- The switch tree is measured on the interpreted batch leg at **-15.17% of a rep** against HEAD at the same `-O2` (t=-52.67, faster 5/5 rounds, worst round -14.44%) and **-12.73%** against the shipping `-O0` (t=-8.32, 5/5) - with cycles (3761), marked cells and walks identical to 5e-5, so the win is price per cell (17.2 -> 14.7 ns), and `mark` -50 s of it is `mark root` -41.5 s + `mark tables` -8.5 s. Cost: runtime `.text` +0.54%, image +0.49% (Red suite) / +0.85% (Red/System suite), compile time +2 s on a 61 s build
- `-O2` is the only opt flag the hybrid accepts (`-O1` is refused) and **no CI job passes it**, so the shipping runtime pays the chain. HEAD's own `-O2` also miscompiles `sort` (`series-test` `sort-str-3`/`sort-str-4`, 6 assertions; repro `build/gc-speed/b2probe/p-sort.red` - the `-r` build compiles `runtime/` from disk at program-build time, so the fault is in runtime sources built at `-O2`, not in this arm, which inherits the identical 6)
- Gate an opt-level arm on the *whole* suite (`build/gc-speed/b2probe/gate-redsys.sh`, `gate-red.sh`: compile+run every unit with a chosen compiler/opt, TSV of bytes/rc/tests/asserts/failed, then diff unit-by-unit against HEAD). The `switch`-named units are a vacuous gate - 1-2 value cases each, under the >= 4 threshold - while 118/144 Red/System and 66/66 Red images change size at `-O2`, which is what proves the tree fired. Inertness at `-O0` is shown by a normalized disassembly diff of the `-O0` image against HEAD's, not by green tests

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
- `sprintf` matches specifiers to varargs *positionally and never checks them*: one specifier and two args silently reads the first as the wrong type. A `%.0f` handed an `integer!` prints `0` with no error while any `> 0.0` guard around it stays accurate, so an entire table can print zeros that look like real zeros - when a generated format string prints nothing but zeros, count the specifiers against the args before doubting the counters
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
