# Red/System x64 O2 Machine IR Plan

## Objective

Make Red/System programs produced by the self-hosted compiler run faster on
Windows x64 and SysV x64. Runtime speed of the generated program is the primary
metric. Compiler time and output size remain measured secondary metrics.

Keep O0 and O1 on their current lowering and emission paths. Extend the existing
experimental O2 mode with a typed, per-function machine IR. During bring-up, an
O2 function that is not supported or does not pass IR verification must be
compiled by the current direct x64 emitter, including its existing O2 peepholes.

This plan applies to the Red-ported compiler. The retired Rebol Stage0 compiler
is not part of normal implementation or validation work.

## Decisions

1. Use a typed, non-SSA machine IR with basic blocks, virtual registers, symbolic
   labels, explicit side effects, explicit flag dependencies, and source
   locations.
2. Optimize one function at a time. Do not require whole-program analysis.
3. Preserve source semantics through dependency edges and effect information,
   not by pinning every instruction in source order.
4. Start with local and block-oriented optimizations. Do not begin with full SSA,
   global value numbering, or a wholesale port of the old system2 optimizer.
5. Model both Win64 and SysV ABI constraints before register allocation.
6. Split frame planning into an early requirements pass and a final layout pass
   after spills are known.
7. Encode instructions only after allocation and layout. Resolve relocations,
   relax branches, and produce debug offsets from the final byte layout.
8. Keep a per-function fallback until the supported feature matrix, correctness
   suite, GC stress tests, and runtime benchmarks all pass on both x64 ABIs.

## Semantic Contract

### Evaluation order

Red/System parses infix expressions without the usual operator precedence and
evaluates expressions from left to right. Parsing and evaluation order are
separate concerns, but both are part of the language contract.

Left-to-right evaluation does not forbid instruction scheduling. It constrains
the order of observable operations. The optimizer may reorder operations when
the dependency graph proves that the result and observable behavior are
unchanged. In particular:

- Independent pure arithmetic may be reordered.
- A load may move only when aliasing, volatility, calls, stores, and any relevant
  trapping behavior prove the move safe.
- Stores, calls, explicit stack operations, throws, GC safepoints, volatile or
  atomic accesses, and unknown effects retain their required order.
- An unknown pointer or unknown call aliases all memory until proven otherwise.
- Source sequence numbers remain attached to IR operations for diagnostics,
  verification, and conservative tie-breaking.

The IR therefore uses dependencies rather than one global source-order barrier.
Pure operations have only data dependencies. Loads consume a memory version for
their alias class. Stores produce a new version. Loads from an unchanged version
can be commoned, and independent alias classes can be scheduled independently.
Unknown effects consume and produce the universal memory version.

### Arithmetic flags

x64 flags are explicit IR values. Arithmetic, compare, and test operations define
a flag bundle; a conditional branch or a Red/System CPU flag query consumes the
specific flags it needs. A defining operation cannot be removed, replaced, or
moved across another flag definition while any of its flags are live.

Transformations are allowed only when all live result bits and live flags are
equivalent. For example, `ADD 1` may become `INC` only when the different carry
flag behavior is unobservable. Replacing multiplication by a shift is allowed
only when signed results and all live flags have equivalent semantics. When in
doubt, retain the original operation.

### Memory, stack, GC, and exceptions

- Keep source locals in explicit local objects until promotion is proven safe.
- Track address escapes and use conservative alias classes after an escape.
- Represent explicit stack operations as effects on a stack-state token.
- Initially fall back for functions that directly inspect or reshape the stack
  in ways the frame planner cannot represent.
- Tag pointer-bearing virtual registers and slots with their GC root kind.
- At every safepoint, every live managed pointer must be in a location described
  by the runtime's root metadata. The first allocator may conservatively spill
  live roots across allocating calls.
- Preserve the ordering and stack shape required by catch, throw, and unwind
  paths. Unsupported exception constructs use the direct-emitter fallback.
- Preserve volatile and atomic access width, count, and order exactly.

### Numeric details

- Keep integer width, byte truncation, sign extension, pointer scale, and cast
  operations explicit until instruction selection.
- Preserve 32-bit signed Red/System integer behavior. Do not infer C unsigned
  semantics from x64 instructions.
- Preserve floating-point NaN, unordered comparison, signed-zero, conversion,
  and precision behavior.
- Do not fold an operation that can raise a language-visible error unless the
  replacement raises the same error at the same observable point.

## IR Model

Each function owns:

- Function signature, calling convention, ABI, and return classification.
- Basic blocks with stable labels, predecessor lists, and successor lists.
- Typed virtual registers for integer, pointer, float, and vector register
  classes.
- Explicit local, argument, spill, outgoing-call, and temporary stack objects.
- Instructions with operands, result values, effects, flag definitions and uses,
  source sequence numbers, and debug source locations.
- Symbolic calls, data references, labels, relocations, and safepoints.
- Function properties such as leaf status, dynamic stack use, exception use,
  maximum outgoing arguments, and required alignment.

Initial scalar types are `i8`, `i32`, `i64`, `f32`, `f64`, native pointer, and
managed pointer. Pointee scale and GC root kind are metadata, not implicit host
language assumptions. Add aggregate and 128-bit cell values only after their ABI
and copy semantics are defined.

The first IR is deliberately not full SSA. Compiler-created temporaries should
normally have one definition, but source locals remain local objects and control
flow joins use explicit merge/copy pseudos or memory until a later promotion pass
can prove a stronger representation safe. No phi-placement algorithm is required
for the first implementation.

Core pseudo-instructions include:

- Typed constants, copies, casts, extensions, truncations, and address formation.
- Integer and floating arithmetic with explicit result and flag values.
- Loads and stores with width, alignment, alias class, and volatility.
- Compare, test, conditional branch, unconditional branch, switch, and return.
- Calls with typed arguments, ABI classification, clobber masks, safepoint and
  throw properties, and typed results.
- Frame-index, incoming-argument, outgoing-argument, and stack-state operations.
- Relocatable symbol address, source-position, and debug-value markers.

An IR verifier runs after construction and after every transforming pass. It
checks block structure, dominance of ordinary temporary definitions where
required, type and width consistency, flag ownership, effect dependencies, call
ABI metadata, stack-state balance, and safepoint root descriptions.

## O2 Pipeline

```text
typed Red/System lowering
        |
        v
per-function machine IR builder
        |
        v
IR verification and feature eligibility
        |
        v
CFG cleanup and local optimization
        |
        v
x64 instruction selection and ABI constraints
        |
        v
liveness and linear-scan register allocation
        |
        v
final frame layout and post-allocation legalization
        |
        v
late encoding, branch relaxation, relocations, debug offsets
```

ABI analysis and outgoing-area requirements begin before allocation. Spill slots,
callee-save slots, final alignment, and exact frame offsets are finalized after
allocation. This avoids making the allocator depend on guessed frame offsets.

## Work Plan

### Phase 0: Freeze the baseline

1. Record current O0, O1, and O2 correctness and performance results.
2. Add generated-program runtime measurement to the benchmark harness; do not use
   compiler throughput as a proxy for output-code speed.
3. Store disassembly fixtures for pointer arithmetic, calls, integer expressions,
   floating expressions, switches, flags, and 16-byte cell copies.
4. Add small semantic tests that expose left-to-right effects, aliasing, flag
   queries, pointer scaling, NaNs, explicit stack use, and GC safepoints.

Exit criterion: the existing backend has a reproducible correctness and runtime
baseline, and benchmark programs validate their results before reporting time.

### Phase 1: IR skeleton and safe fallback

1. Add the function, block, instruction, operand, type, effect, flag, stack-object,
   relocation, source-position, and safepoint data structures.
2. Add deterministic textual IR dumps and the verifier.
3. Route a small eligibility set of straight-line integer functions through the
   IR with optimizations disabled.
4. Make the O2 choice before committing bytes for a function. If construction or
   verification fails, discard the function IR and invoke the direct emitter.
5. Add an option for dumping IR and pass-by-pass IR without changing O0/O1.

Initial fallback cases include unmodelled explicit stack manipulation, inline
machine code, unsupported exception paths, incomplete variadic or aggregate ABI
classification, and any direct CPU state access not represented by the IR.

Exit criterion: eligible O2 functions pass differential tests with optimization
disabled; ineligible functions reliably use the existing emitter.

### Phase 2: Control flow, effects, and flags

1. Build basic blocks for branches, loops, returns, and switches.
2. Add explicit data, memory-version, stack-state, flag, call, safepoint, and throw
   dependencies.
3. Implement conservative alias classes for locals, non-escaping objects,
   globals, managed series data, and unknown memory.
4. Model x64 condition codes without first materializing booleans.
5. Preserve source sequence and debug positions through block construction.

Exit criterion: the verifier rejects missing dependencies, and targeted tests
show that effectful expressions retain their required left-to-right behavior
while independent pure operations are not artificially serialized.

### Phase 3: Correctness-first optimization passes

Implement these passes independently, with verification after each pass:

1. Typed constant propagation and constant folding.
2. Copy propagation and redundant extension/truncation elimination.
3. Block-local value numbering for pure operations.
4. Store-to-load forwarding and redundant-load elimination only when alias and
   memory-version checks prove safety.
5. Dead-code elimination for operations with no effects, traps, live flags, or
   debug obligations.
6. Branch folding, unreachable-block removal, and trivial jump threading.
7. Local compare/branch fusion and removal of dead boolean materialization.

Do not add speculative scheduling, loop transforms, global code motion, or source
local promotion in this phase.

Exit criterion: every pass can be enabled separately, pass-order permutations
used by tests remain correct, and O2 removes reload/copy patterns without changing
observable evaluation order.

### Phase 4: x64 instruction selection

1. Select register-memory forms directly for legal `add`, `sub`, `cmp`, `test`,
   `and`, `or`, `xor`, and `imul` cases.
2. Select LEA for address formation and arithmetic only when live result and flag
   semantics allow it.
3. Sign-extend a 32-bit pointer index before 64-bit scaled address formation so a
   large signed offset cannot wrap in a 32-bit temporary.
4. Use direct XMM memory operands or XMM temporaries instead of fixed 16-byte
   expression spill sequences.
5. Select compare-and-branch directly when no value form of the boolean is used.
6. Select dense switches as range-check plus jump table and sparse switches as a
   balanced comparison tree when profiling or cost rules justify them.
7. Select a 128-bit load/store for a 16-byte cell copy when alignment, overlap,
   GC barriers, and atomicity requirements permit it.
8. Retain symbolic frame indices, labels, and relocations at this stage.

Exit criterion: instruction-selection tests assert semantic output and normalized
instruction shapes, not fragile raw byte offsets.

### Phase 5: ABI calls and preliminary frame planning

1. Classify arguments and returns for Win64 and SysV x64, including integer,
   floating, pointer, variadic, and supported aggregate cases.
2. Represent fixed argument and result registers as precolored virtual registers.
3. Attach caller-save, callee-save, and flag clobbers to calls.
4. Compute each function's maximum outgoing stack argument requirement.
5. On Win64, reserve reusable shadow/outgoing space once in the function frame
   instead of surrounding ordinary calls with repeated `sub rsp` and `add rsp`.
6. Lower register arguments as parallel copies so `push rax; pop rcx` naturally
   becomes a register move and copy cycles are resolved correctly.
7. Preserve required stack alignment at every call and safepoint.

Exit criterion: ABI conformance tests pass for native calls, imported calls,
callbacks, mixed integer/float signatures, variadics, and supported aggregates on
both x64 ABIs.

### Phase 6: Liveness and linear-scan allocation

1. Number positions in layout order and calculate live intervals across blocks.
2. Allocate GPR and XMM classes separately.
3. Honor precolored ABI operands, two-address constraints, fixed-register
   instructions, call clobbers, and reserved runtime registers.
4. Split intervals around calls and constrained instructions when profitable.
5. Insert typed spills and reloads; coalesce copies when intervals permit.
6. Keep flag values in the flags resource and prevent overlapping flag-producing
   instructions while flags are live.
7. Track managed roots at safepoints. Begin with conservative root spilling, then
   permit register roots only when runtime metadata describes them correctly.

Exit criterion: allocation stress tests cover high register pressure, loops,
calls, mixed GPR/XMM code, fixed-register instructions, and forced GC.

### Phase 7: Final frame layout and late encoding

1. Assign offsets to locals, spills, saved registers, outgoing arguments, shadow
   space, and alignment padding.
2. Emit one prologue and epilogue scheme consistent with unwind, exception, GC,
   and debug requirements.
3. Legalize instructions that cannot encode their allocated operand combination,
   using a reserved scratch policy or a local repair allocation.
4. Encode from symbolic instructions only after final allocation and layout.
5. Emit relocation records through the existing image/linker interfaces.
6. Relax branches iteratively from conservative encodings to short encodings
   without invalidating labels or metadata.
7. Generate source/debug offsets, safepoint locations, and unwind data from final
   byte offsets.

Exit criterion: PE/COFF and ELF output has valid relocations, debug/source maps,
unwind information, branches, stack alignment, and safepoint metadata.

### Phase 8: Coverage and profile-driven specialization

1. Expand eligibility one feature at a time, with a focused semantic and ABI test
   before removing each fallback.
2. Profile emitted programs, not only the compiler process.
3. Specialize or inline `resolve-node`, `resolve-series`, and `copy-cell` only at
   call sites whose types, GC behavior, and alias conditions are known.
4. Keep a normal call path for uncommon or unproven cases.
5. Add further scheduling, local promotion, or loop optimization only when
   profiles identify a runtime bottleneck and the effect model can prove safety.

Exit criterion: the full intended Red/System feature matrix can use O2, or every
remaining fallback is documented with its semantic reason and measured impact.

## Mapping of the Earlier Six Optimization Items

| Earlier item | Owning part of this plan |
| --- | --- |
| Correct pointer scaling | Explicit typed extensions plus x64 LEA selection in Phase 4 |
| Redesign Win64 calls | Parallel ABI copies and function-level outgoing area in Phase 5 |
| Stop redundant reloads | Copy propagation, value numbering, forwarding, and allocation in Phases 3 and 6 |
| Select memory operands | x64 instruction selection in Phase 4 |
| Remove floating spills | XMM-aware selection and linear-scan allocation in Phases 4 and 6 |
| Improve switches, flags, and hot helpers | CFG/flag IR, switch selection, and profile-driven specialization in Phases 2, 4, and 8 |

The existing peephole implementations remain useful while these phases are under
construction. They are not the completion criterion for the six items; the new
pipeline must handle the patterns systematically across basic blocks and register
pressure.

## Integration Boundaries

Expected integration points are:

- `system/compiler-core.red`: choose the O2 per-function IR path and preserve the
  existing direct-lowering path.
- `system/targets/X86-64.red`: expose x64 ABI and encoding definitions, retain the
  fallback emitter, and progressively route O2 through selected instructions.
- `system/targets/target-class-body.red`: hold target-independent hooks only where
  both x64 ABIs need a common contract.
- `system/emitter.red`: accept final relocations, debug offsets, unwind data, and
  GC/safepoint metadata.
- New Red modules: IR data model, verifier, passes, x64 selection, liveness,
  allocation, frame layout, and late encoding. Keep these separate enough that
  each stage can be dumped and tested independently.
- `tools/self_hosting/benchmark-compiler.ps1`: retain compiler-throughput results
  and add emitted-program runtime orchestration and paired analysis.
- `system/tests`: add semantic, pass, ABI, allocation, encoding, GC, and
  differential coverage.

Avoid a second copy of ABI facts. Register classes, argument registers, clobber
masks, stack alignment, relocation forms, and instruction constraints must have
one authoritative x64 target description consumed by selection, allocation, and
encoding.

## Test Strategy

### Semantic and differential tests

- Compile and run the Red/System suite at O0, O1, and O2; compare exit status and
  program output, not generated bytes.
- Add targeted left-to-right tests containing calls, stores, aliased reads,
  pointer updates, and short-circuit control flow.
- Exhaust integer boundary cases for add, subtract, multiply, divide, shifts,
  casts, pointer scaling, and every observable arithmetic flag.
- Test floating NaNs, unordered comparisons, infinities, signed zero, conversions,
  and mixed precision.
- Test switch density extremes, nested control flow, loops, unreachable blocks,
  and fall-through-free case semantics.
- Test imported and native calls, callbacks, variadics, aggregates, recursion, and
  mixed integer/floating arguments on Win64 and SysV.
- Force collection at frequent safepoints with live roots in locals, temporaries,
  spills, arguments, and returns.
- Test catch/throw, unwind, debug stepping, source positions, and every supported
  explicit stack operation before enabling those functions for O2.

### IR and backend tests

- Round-trip deterministic IR dumps for small functions.
- Negative verifier tests for malformed CFG, types, flags, effects, stack states,
  ABI constraints, and root maps.
- One test suite per optimization pass with that pass isolated.
- Instruction-selection shape tests using symbolic operands.
- Allocator tests with artificial intervals and constrained registers.
- Encoder tests for immediate boundaries, ModRM/SIB forms, REX prefixes, short and
  near branches, relocations, and frame offsets.
- Disassemble representative release outputs and check stack balance and ABI
  invariants independently of IR tests.

On Windows x64, release validation uses the self-hosted Stage1 compiler:

```powershell
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d -t Windows-X86-64 -o <output> <input>
```

Do not use the retired Stage0 path for normal validation.

The `StageNN` names recorded below are build-lineage and evidence labels, not
toolchain pins. Normal development bootstraps from the newest compatible,
verified self-hosted stage. Use development mode and retain its matching
`libRedRT.dll` when runtime sources have not changed; regenerate the runtime only
when runtime code changes or a runtime-specific validation requires it.

## Runtime Benchmark Method

1. Benchmark the emitted executable separately from compilation.
2. Validate a checksum or exact result before accepting a timing sample.
3. Measure both cold-start programs and steady-state kernels; do not mix their
   results into one number.
4. Warm steady-state workloads, then run O0/O1/O2 in a balanced interleaved order
   to reduce thermal, frequency, and background-load bias.
5. Collect at least 15 paired samples for normal benchmarks and more when the
   confidence interval is unstable. Report median paired ratios and dispersion.
6. Use representative integer, pointer/series, branch/switch, call-heavy,
   floating-point, allocation/GC, cell-copy, and compiler workloads.
7. Record CPU, OS, target ABI, compiler commit, build mode, command line, sample
   count, and benchmark revision with every result.
8. Report generated code size and O2 compiler time, but do not trade a repeatable
   runtime gain for smaller output unless size itself is the workload bottleneck.

`tools/self_hosting/benchmark-generated-code-suite.ps1` applies this method to a
manifest of emitted-program workloads. It records paired candidate/baseline
ratios, deterministic bootstrap 95% intervals, source and tool hashes, CPU and
OS metadata, and fails the gate for a credible regression above two percent or
for a core-suite geometric-mean improvement below three percent. Use the
single-program runner for focused investigations and the suite runner for
cross-ABI aggregate evidence.

Provisional performance gate before proposing O2 as the default:

- No statistically credible regression above 2 percent on a designated critical
  workload without an explicit, evidence-backed exception.
- At least a 3 percent geometric-mean runtime improvement across the agreed core
  suite on both Win64 and SysV x64.
- Clear gains on at least one compiler-sized workload and on the focused workload
  for every optimization used to justify enabling O2.
- No correctness, ABI, GC, exception, unwind, relocation, or debug regression.

These thresholds are decision gates, not pass heuristics. Individual
transformations should use measured target costs and may increase code size when
that produces a reliable runtime win.

## Current Implementation Evidence

As of Stage137, the experimental O2 path supports scalar Win64 and SysV direct
calls with ABI register arguments, stack arguments, parallel register copies,
and one function-level outgoing argument area. Scalar C `cdecl [variadic]`
native and imported calls use the same machine-IR call operation with explicit
variadic metadata. Win64 duplicates floating arguments in the first four slots
from XMM registers into their paired integer registers and calls imports through
the IAT. SysV writes the number of used XMM argument registers to `AL`, places
overflow arguments in its outgoing area, and aligns `RSP` once per selected
calling function. Typed/custom varargs, aggregate arguments, and unsupported
promotion casts retain per-function fallback.

Stages134 and 135 change scalar GPR overflow-argument stores to `REX.W` qword
stores on both ABIs. Every ABI stack slot is eight bytes, and the direct callee
copies those slots with qword loads; the previous four-byte O2 stores created a
partial-width store-to-load forwarding hazard. Floating stack arguments retain
their typed `f32`/`f64` stores. The machine-IR smoke fixture requires the full
width encodings for Win64 and SysV, so this is an ABI-width invariant rather
than a size-only peephole.

Managed pointers and XMM values live at safepoints use typed spill slots;
managed roots are added to the runtime frame bitmap. Stage101 assigns ordinary
non-GC GPR intervals that cross calls to ABI callee-save registers instead of
spilling around every call. It plans one save slot per used register, saves them
after the function-level frame reservation, and restores them at the common
return label. Calling functions also promote loaded scalar loop locals into
callee-save registers, while write-only locals are excluded from promotion.
This removed the repeated flush/call/reload sequences from the focused date
loop. Fixed volatile values and GC roots retain conservative call spilling. An
ABI argument register is now treated as a call-site hint rather than a
whole-interval constraint when the value crosses an earlier call. Ordinary
non-GC GPR values can remain in a callee-save register and move to the ABI
register immediately before the consuming call; managed roots and XMM values
retain typed spills.

Generic call and data relocation records are consumed after final layout,
including RIP-relative scalar, pointer, `f32`, and `f64` global loads and stores.
Relocations are matched to unused direct-emitter references by symbol identity
within the selected body. The original IR ordinal remains a positive, unique
source-validation key, but is no longer assumed to equal direct registration
order: the direct emitter can register an outer call or assignment destination
before recursively compiling nested arguments, while machine IR records the
observable evaluation order.
Final encoding also performs iterative branch relaxation and rewrites
source/debug offsets from the selected byte layout. Exception unwind metadata
for the new callee-save layout remains part of the experimental O2 completion
work.

Stages112 and 113 add a narrowly guarded frameless path for dense switches. A
leaf function with one shared return block, no calls, local stores, escaped
locals, shift-count requirements, or division-register requirements can keep
its ABI argument in a register across the CFG. Dense dispatch copies a dead
selector to `EAX` only when needed, then uses the existing range-check and
relocatable jump-table encoding. Multiple exits and sparse switches retain the
framed or direct fallback. This removes the stack reload and frame overhead that
made the five-case SysV jump-table lowering slower than its fallback.

Stage82 distinguishes namespace-qualified source symbols from unresolved
pointer/member paths. The early source scan no longer rejects paths that the
normal compiler resolves to decorated function or global words before IR
recording; the normalized expression lowerer remains responsible for rejecting
real pointer/member accesses it cannot model. This removes 45 false
`path-access` blockers. Thirty-two of those functions select, while the other
thirteen expose independent selector constraints and retain fallback. The
focused fixture selects a qualified call and global load on Win64 and SysV while
an actual pointer dereference remains in the direct backend.

Stage85 carries typed pointer arithmetic through machine IR. Pointer types now
record the pointed element width, including complete `struct!` and `union!`
sizes, so a 16-byte Red cell is represented as `ptr8x16` rather than `ptr8x1`.
For a signed 32-bit variable index, the x64 selector emits `MOVSXD` before any
scaling. Scales 1, 2, 4, and 8 use indexed LEA addressing; larger powers of two
use a 64-bit shift followed by LEA, and other legal scales use 64-bit `IMUL`.
Subtraction also operates on the widened scaled offset. Scaled constants use a
displacement only when the result fits signed `disp32`; other cases retain
per-function fallback. Pointer arithmetic whose flags are observable is not
selected, preserving `overflow?` behavior.

Stage119 extends that selection to a signed `i32` index whose single-use local
load was folded out of the register-allocation intervals. The encoder emits
`MOVSXD r11, dword [rbp+disp]` directly from the frame and then uses the same
64-bit scale/LEA path as a register index. It does not reintroduce a 32-bit
temporary that could wrap before sign extension. This clears all thirteen
`x64-missing-allocation` fallbacks found in the Stage117 fixed-point audit. The
Stage119 dump contains 3,852 functions, 3,840 verified functions, 180 initially
eligible functions, and 173 selected functions, up from 160 selected in
Stage117. The only real x64 selector fallbacks left in that configuration are
five unsupported relocation symbols and two unsupported comparison types.

Stages122 and 123 select same-typed pointer comparisons. Pointer operands use a
64-bit `CMP`; equality remains width-independent, while `<`, `>`, `<=`, and `>=`
use the unsigned x64 conditions `B`, `A`, `BE`, and `AE`, matching the direct
backend's pointer semantics. Materialized logic results and branches consume the
same typed condition mapping, and frame-memory comparisons also receive `REX.W`.
This selects `red>cycles>pop` and `red>vector>append-values`, clearing both
`x64-comparison-type` fallbacks. The Stage123 fixed-point dump contains 3,854
functions, 3,842 verified functions, 180 eligible functions, and 175 selected
functions. The five remaining real selector fallbacks are all
`x64-relocation-symbol`: `red>externals>init`, `red>references>init`,
`red>object>fire-on-set*`, `red>image>resize`, and `red>actions>poke*`.

Stages126 and 127 remove those five relocation fallbacks. A focused smoke case
records globals in one IR order and supplies direct references in the opposite
order, then checks both selected bytes and patched reference positions. The
Stage127 fixed-point dump selects all five functions and has no x64 selector
fallback.

Stages128 through 130 make call-live allocation explicitly performance-gated.
For Win64 functions whose direct prologue already reserves 32 bytes of shadow
space, O2 places save/spill slots in the old high shadow slots exposed when RSP
moves down. When the direct prefix ends in the validated `sub rsp,20h` form, the
additional aligned frame is merged into that instruction instead of emitting a
second subtraction. A straight-line function whose call-live ABI hint was
released is retained as direct code when the selected body is larger; shorter
selected bodies still proceed. This check is limited to non-GC GPR scalars and
does not bypass managed-root or XMM spill planning.

That policy is based on emitted-program runtime, not size as an end in itself.
The initial nested-relocation selected helper measured `0.928x` paired wall
speed versus fallback. Callee-save allocation and compact slots improved it to
`0.942x`; merging the frame adjustment reached `0.981x`, with a repeat at
`0.982x`, but it was still slower. Stage130 therefore records
`x64-call-live-expansion` for that shape and retains the direct body. Fifty-one
paired runs of the guarded result are runtime-neutral: `0.998x` paired wall and
`1.000x` paired CPU ratio. Reports are under
`build/generated-code-benchmarks/nested-relocation-direct-stage127/`,
`nested-relocation-direct-stage128/`, `nested-relocation-direct-stage129/`, and
`nested-relocation-direct-stage130/`.

No-call, no-safepoint functions may keep managed pointer locals in registers.
Functions with calls still use the existing frame/root handling, so the GC does
not lose a register-only pointer at a safepoint. This promotion turns the focused
cell-pointer loop body into `LEA`, `ADD`, `CMP`, and a conditional branch on both
Win64 and SysV. Focused encoder cases cover byte, four-byte, and 16-byte scales,
signed negative indexes, subtraction, and constant-range fallback.

Stage88 extends `bitcast` selection to representation-preserving scalar casts.
Pointer-to-pointer casts select when both sides are eight-byte GPR values, even
when their pointee scales differ. Same-width `i32` and `i64` representation casts
also select, as does the established `logic!` to `integer!` cast. Width-changing,
pointer/integer, floating-point, and `i32` to `logic!` casts still fall back. This
removed the sole `type-cast` blocker from 132 compiler functions: Stage88's dump
contains 3,794 functions, 3,782 verified functions, 364 initially eligible
functions, and 328 selected functions, with no ineligible selected function. The
focused pointer-cast fixture exercises byte pointer, 16-byte cell pointer, and
same-width struct-alias casts; O0 and O2 both print four successful checks, and
each selected wrapper is a move plus return.

Stage97 selects both constant-count and variable-count `integer!` shifts. The x64
encoder emits `C1 /4` for `<<`, `C1 /7` for signed `>>`, and `C1 /5` for `-**` or
an unsigned right operand when the count is constant. A function containing a
variable shift reserves `ECX`, does not let call-argument precoloring claim that
fixed register, and uses a frame so the constrained sequence can materialize the
right operand, move it to `ECX`, and then materialize the left operand without
losing either value. The encoder then emits `D3 /4`, `D3 /7`, or `D3 /5` using
`CL`. Functions with observable arithmetic flags remain excluded by the existing
flag-liveness check. In addition to the constant-shift users selected at Stage90,
this makes `deflate>npow2` selectable instead of stopping at its variable shift.

Stage97 also represents the `log-b` native as a typed pure unary operation and
selects `BSR`. The direct backend had always inlined this native, so treating it
as an ordinary IR call incorrectly created a relocation with no matching direct
reference. The intrinsic removes that mismatch. Selection emits an explicit move
before `BSR`, preserving the direct backend's destination behavior when the input
is zero rather than assuming a value for x64's undefined zero-input result.

Stage103 adds typed signed integer division, remainder (`%`), and non-negative
modulus (`//`). Variable and unsupported constant divisors use the constrained
`CDQ`/`IDIV` sequence with explicit EAX, ECX, and EDX allocation checks. Positive
constant divisors in the audited 3, 5, 9, and 25 families, including their
powers-of-two multiples such as 10, 100, 400, and 800, use signed multiply-high
strength reduction. Remainder reconstructs `left - quotient * divisor`, and
modulus applies a branchless correction for negative remainders. Boundary and
randomized host-side validation covered 200,000 signed dividends per audited
divisor; constants outside the table deliberately retain `IDIV`. Exact encoder
fixtures cover quotient, remainder, modulus, register preservation, and fallback.

Stage107 legalizes the remaining noncommutative x64 two-address conflict when
the left operand is already in the reserved spill scratch and the result is
allocated to the right operand's register. It computes the operation in the
spill scratch and then moves the result to its allocation; the final `MOV` does
not alter the arithmetic flags. Other conflicts retain atomic per-function
fallback. This selects both `red>date>date-to-days` and
`red>date>get-yearday`. Their emitted sequences include `SUB R11D,R8D; MOV
R8D,R11D` and `SUB R11D,EAX; MOV EAX,R11D`, respectively.

The first `log-b` runtime benchmark exposed a separate integer selector bug. A
constant that was legal as an immediate could still receive a spill allocation,
whose slot was deliberately never initialized; binary and comparison selection
consulted that spill before the known constant and could read uninitialized stack
memory. Both selectors now prefer a known immediate before a spill-memory form.
The expanded checksum fixture covers this path, and its O0 and O2 results agree.

Stage48 prevents by-value structures and aliases of by-value structures from
entering the scalar machine-IR path. Those functions currently fall back to the
direct backend, preserving the Win64 aggregate calling convention until typed
aggregate IR lowering is implemented. The focused 16-byte aggregate fixture
prints `100` at both O0 and O2 with exit status zero.

Stage49 selects unaligned 128-bit loads and stores for exact 16-byte copies at
O2. Calls to the hot `red>copy-cell` helper are specialized after normal argument
evaluation and ABI register placement, eliminating the call while retaining O0
and O1 behavior. Stage54 represents this specialization as an explicit typed
machine-IR operation with a universal-memory write dependency and load-before-
store overlap semantics. The selector reserves `xmm5` on Win64 or `xmm15` on
SysV for the 16-byte transfer, while the allocator places source, destination,
and result through the normal ABI parallel-copy constraints. A non-escaping
managed-pointer argument no longer forces a frame in functions with no calls or
safepoints.

Stage64 represents `red>resolve-node` and `red>resolve-series` as explicit typed
machine-IR operations. Both carry a universal-memory dependency and a relocatable
reference to `red>node-registry`, validate the positive handle against
`node-registry/next`, and resolve the physical node. `resolve-series` additionally
checks for a freed null entry and carries a second relocation to the normal helper
slow path. The allocator precolors the handle and result to ABI registers, treats
the series operation as a possible call, spills values live across it, and emits
a safepoint root map. Focused Win64 and SysV encoder cases cover both instruction
shapes, two relocations on one IR instruction, and a managed pointer live across
the slow-call edge. Zero, negative, out-of-range, and freed handles retain their
established behavior. A focused Linux-x64 compiler now uses the ELF compiler
closure rather than the PE-only bootstrap closure. It emits both O0 and O2 ELF
binaries for the resolver fixture; both execute under Ubuntu WSL, print `8`, and
exit successfully. The O2 dump selects both wrappers with SysV `EDI` handle and
`EAX` result allocation, the registry relocation, the series slow-call
relocation, and a series safepoint.

Stage67 fixes a Win64 allocator collision between promoted locals and ABI call
arguments. An argument is no longer precolored to a register owned by a promoted
local; the late parallel-copy step moves it into the ABI register after promoted
locals have been flushed. The focused three-argument fixture covers the original
`R8D` collision and prints `17` and `8` at both O0 and O2.

Stage69 makes selection failure atomic. Every fallible integer emitter propagates
failure, jump-table patching is checked, and the function finalizer refuses a
selected chunk if selection made the function ineligible. The smoke fixture
reproduces the two-call noncommutative two-address conflict that previously left
truncated selected code and now verifies direct-code fallback. Its dump also
rejects every `eligible=false selected=true` state.

Stage71 represents comparison-only Red/System `any` and `all` expressions as
explicit short-circuit CFGs with true, false, continuation, and merge blocks.
Each comparison feeds a branch directly from its flags, so the intermediate
logic values are not materialized. Stage75 extends the same CFG to materialized
`logic!` values, including call and phi results; late selection emits
`TEST reg,reg` without inventing a source-level comparison. Constant logic
branches fold before allocation. Unreachable-block cleanup removes dead phi
inputs, and stable relocation ordinals let selection discard references owned by
deleted calls without disturbing retained symbol references. The focused fixture
verifies returned values, executed tail calls, and skipped side effects at O0 and
O2. The Red-level
`collect [keep 1 keep 2]` reproducer prints `[1 2]`; `red>word>any-word?` now
selects its complete six-comparison short-circuit CFG.

Stage72 adds short-circuit-aware block layout. The comparison continuation chain
is emitted first, followed by the false, true, and merge blocks. Successful
branches converge on one true-value block that falls directly into the merge and
return path; the false block jumps over it. This removed an extra taken branch
on every successful `any` result that made the first Stage71 layout slower than
the direct backend.

Stage63 models simple value-producing switches in machine IR, including explicit
CFG edges and merge values with planned predecessor-edge copies. Sparse switches
with at least twelve distinct cases select balanced signed comparison trees;
dense non-negative switches with at least 32 cases select a range check and a
relative-offset jump table whose holes target the explicit default block. The
dense selector uses a dead `EAX` index and reserved volatile `r11` table base,
while unsupported selector liveness, nested switches, switches without a
default, duplicate values, and small switches retain per-function fallback.
Switch dispatch branches remain in stable near form and hot loop headers are
32-byte aligned because paired generated-runtime measurements showed that this
layout avoided a regression from late branch shortening and target movement.

The Stage46 selector handles `f32` and `f64` equality and ordered relational
comparisons with `UCOMISS`/`UCOMISD`. It preserves Red/System unordered semantics:
NaN is false for `=`, `<`, `>`, `<=`, and `>=`, and true for `<>`. Branch-only
uses consume flags directly, including the required parity branch, without
materializing a logic value. Stage47 adds an explicit same-width `bitcast` IR
operation, initially used for representation-preserving `logic!` to `integer!`
casts. The allocator coalesces comparison results and their cast results, so
`as integer! a < b` does not add a machine instruction.

The machine-IR smoke fixture has 67 functions, 66 initially eligible functions,
63 selected functions, and four intentional fallback cases. It checks Win64
variadic XMM-to-GPR duplication and IAT calls, SysV `AL` counts and stack
overflow arguments, the one-time SysV stack-alignment prefix, and exact pointer
arithmetic, constant-shift, variable-shift, and `log-b` encodings. Its variable
shift case verifies the fixed-`CL` sequence exactly. The executable
float comparison fixture selects all twelve scalar logic-value functions, all
six direct-branch functions, and all six integer-cast functions. It checks every
condition with ordered and NaN operands; its O0 and O2 outputs are both `48` with
exit status zero. The existing `float-test.reds` integer-cast comparison wrappers
also select and its 1,950 assertions pass.

Recorded emitted-program performance results include:

- Stage38 Win64 register arguments across calls: O0 median 0.25 seconds and O2
  median 0.14 seconds over 15 interleaved samples, with a 1.85x median paired
  speedup. Report:
  `build/generated-code-benchmarks/stage38-register-argument/20260806-004522/report.json`.
- Stage46 Win64 floating comparison call loop: O0 median 0.48 seconds and O2
  median 0.20 seconds over 31 interleaved samples, with a 2.39x median paired
  speedup and identical output. Report:
  `build/generated-code-benchmarks/stage46-float-compare/20260806-051734/report.json`.
- Stage47 Win64 floating comparison integer-cast call loop: O0 median 0.47
  seconds and O2 median 0.20 seconds over 31 interleaved samples, with a 2.34x
  median paired speedup and identical output. Report:
  `build/generated-code-benchmarks/stage47-float-compare-int/20260806-054410/report.json`.
- Stage49 Win64 `copy-cell` call loop: O0 median 0.29 seconds and O2 median
  0.12 seconds over 15 interleaved samples, with a 2.43x median paired speedup
  and identical output. The O2 fixture contains two expected 128-bit copy
  sequences and the O0 fixture contains none. Report:
  `build/generated-code-benchmarks/stage49-copy-cell/20260806-062550/report.json`.
- Stage51 Win64 resolver call loop: O0 and O1 median 0.66 seconds and O2 median
  0.24 seconds over 15 interleaved samples, with a 2.77x median paired speedup
  and identical output. Disassembly confirms that valid handles take the inline
  lookup while exceptional `resolve-series` handles retain the helper call.
  Report:
  `build/generated-code-benchmarks/stage51-resolvers/20260806-065744/report.json`.
- Stage52 Win64 sparse-switch loop: O0 median 0.23 seconds, O1 median 0.22
  seconds, and O2 median 0.14 seconds over 15 interleaved samples, with a 1.68x
  median paired O2 speedup and identical output. Report:
  `build/generated-code-benchmarks/stage52-sparse-switch/20260806-071807/report.json`.
- Stage54 Win64 machine-IR `copy-cell` wrapper loop: O0 and O1 median 0.44
  seconds and O2 median 0.10 seconds over 15 interleaved samples, with a 4.48x
  median paired speedup and identical output. The selected wrapper is frameless
  and consists only of the 128-bit load, 128-bit store, result move, and return.
  Report:
  `build/generated-code-benchmarks/stage54-copy-cell-ir/20260806-082058/report.json`.
- Stage63 Win64 machine-IR sparse-switch loop: O0 median 0.23 seconds, O1
  median 0.22 seconds, and O2 median 0.14 seconds over 15 interleaved samples,
  with a 1.69x median paired O2 speedup and identical output. Report:
  `build/generated-code-benchmarks/stage63-sparse-switch-ir/20260806-114225/report.json`.
- Stage63 Win64 machine-IR dense-switch loop: O0 and O1 median 0.22 seconds and
  O2 median 0.12 seconds over 15 interleaved samples, with a 1.80x median paired
  O2 speedup and identical output. Report:
  `build/generated-code-benchmarks/stage63-dense-switch-ir/20260806-114259/report.json`.
- Stage64 Win64 machine-IR resolver wrapper loop: O0 median 1.01 seconds, O1
  median 1.03 seconds, and O2 median 0.29 seconds over 15 interleaved samples,
  with a 3.48x median paired O2 speedup and identical output. Report:
  `build/generated-code-benchmarks/stage64-resolvers-ir/20260806-124039/report.json`.
- Stage72 Win64 comparison-only short-circuit loop: O0 median 0.25 seconds, O1
  median 0.23 seconds, and O2 median 0.21 seconds over 31 interleaved samples,
  with a 1.17x median paired O2 speedup versus O0 and identical output. Report:
  `build/generated-code-benchmarks/stage72-short-circuit-isolated-31/20260806-173135/report.json`.
- Stage75 Win64 materialized short-circuit call loop: O0 and O1 median 0.35
  seconds and O2 median 0.24 seconds over 31 interleaved samples, with a 1.47x
  median paired O2 speedup versus O0 and identical output. Report:
  `build/generated-code-benchmarks/stage75-short-circuit-call-31/20260806-185523/report.json`.
- Stage77 SysV comparison-only short-circuit loop under Ubuntu WSL: O0 median
  0.206726 seconds and O2 median 0.196866 seconds over 31 interleaved samples,
  with a 1.048748x median paired O2 speedup and identical `60000000` output.
  Median CPU time decreased from 0.199264 to 0.188480 seconds. Report:
  `build/generated-code-benchmarks/stage77-sysv-short-circuit-31/20260806-201621/report.json`.
- Stage77 SysV materialized short-circuit call loop under Ubuntu WSL: O0 median
  0.303733 seconds and O2 median 0.223684 seconds over 31 interleaved samples,
  with a 1.353601x median paired O2 speedup and identical `60000000` output.
  Median CPU time decreased from 0.294043 to 0.214450 seconds. Report:
  `build/generated-code-benchmarks/stage77-sysv-short-circuit-call-31/20260806-201541/report.json`.
- Stage78 Win64 scalar C-variadic call loop: O0 median 0.1136303 seconds, O1
  median 0.1134085 seconds, and O2 median 0.044385 seconds over 31 interleaved
  samples, with a 2.553907x median paired O2 speedup and identical `20000000`
  output. Median CPU time decreased from 0.109375 to 0.03125 seconds. Report:
  `build/generated-code-benchmarks/stage78-variadic-call-31/20260806-212856/report.json`.
- Stage79 SysV scalar C-variadic call loop under Ubuntu WSL: O0 median
  0.090845072 seconds, O1 median 0.090246777 seconds, and O2 median
  0.046787565 seconds over 31 interleaved samples, with a 1.934446x median
  paired O2 speedup and identical `20000000` output. Median CPU time decreased
  from 0.083327 to 0.039747 seconds. Report:
  `build/generated-code-benchmarks/stage79-sysv-variadic-call-31/20260806-212924/report.json`.
- Stage80/Stage82 qualified-symbol call loop: Stage80's path-scan fallback O2
  median was 0.0734738 seconds and Stage82's selected O2 median was 0.0726586
  seconds over separate 31-run interleaved O0/O2 reports. Both produce
  `20000000` and remain approximately 1.84x faster than O0. Reports:
  `build/generated-code-benchmarks/stage80-qualified-call-31/20260806-222557/report.json`
  and
  `build/generated-code-benchmarks/stage82-qualified-call-31/20260806-222627/report.json`.
- Stage84 Win64 16-byte pointer-arithmetic loop: O0 median 0.0500008 seconds,
  O1 median 0.0504417 seconds, and O2 median 0.0295128 seconds over 31
  interleaved samples, with a 1.66005x median paired O2 speedup and identical
  `320004096` output. Median CPU time decreased from 0.03125 to 0.015625
  seconds. Report:
  `build/generated-code-benchmarks/stage84-pointer-arithmetic-31/20260806-235344/report.json`.
- Stage86 SysV 16-byte pointer-arithmetic loop under Ubuntu WSL: O0 median
  0.035601973 seconds, O1 median 0.034589336 seconds, and O2 median
  0.018907832 seconds over 31 interleaved samples, with a 1.888392x median
  paired O2 speedup and identical `320004096` output. Median CPU time decreased
  from 0.028243 to 0.011678 seconds. Report:
  `build/generated-code-benchmarks/stage86-sysv-pointer-arithmetic-31/20260807-002709/report.json`.
- Stage90 Win64 Murmur-style constant-shift loop: O0 median 0.1227151 seconds
  and O2 median 0.0601718 seconds over 31 interleaved samples, with a 2.047412x
  median paired O2 speedup and identical `1826080327` output. Median CPU time
  decreased from 0.109375 to 0.046875 seconds. Report:
  `build/generated-code-benchmarks/stage90-integer-shift-31/20260807-021558/report.json`.
- Stage91 SysV constant-shift loop under the persistent Ubuntu WSL driver: O0
  median 0.105352131 seconds and O2 median 0.040969356 seconds over 31
  interleaved samples, with a 2.584133x median paired O2 speedup and identical
  `1826080327` output. Median CPU time decreased from 0.097446 to 0.032812
  seconds. Report:
  `build/generated-code-benchmarks/stage91-sysv-integer-shift-31/20260807-022716/report.json`.
- Stage95 Win64 variable-shift loop: O0 median 0.0941037 seconds and O2 median
  0.0750541 seconds over 31 interleaved samples, with a 1.267268x median paired
  O2 speedup and identical `-811334320` output. Median CPU time decreased from
  0.078125 to 0.0625 seconds. Report:
  `build/generated-code-benchmarks/stage95-variable-shift-31/20260807-033714/report.json`.
- Stage96 Win64 `log-b` loop: O0 median 0.117857 seconds and O2 median
  0.0801133 seconds over 31 interleaved samples, with a 1.469961x median paired
  O2 speedup and identical `1530921062` output. Median CPU time decreased from
  0.109375 to 0.0625 seconds. Report:
  `build/generated-code-benchmarks/stage96-log-b-31/20260807-034816/report.json`.
- Stage98 SysV variable-shift loop under the persistent Ubuntu WSL driver: O0
  median 0.080380236 seconds and O2 median 0.061238701 seconds over 31
  interleaved samples, with a 1.325907x median paired O2 speedup and identical
  `-811334320` output. Median CPU time decreased from 0.072424 to 0.053555
  seconds. Report:
  `build/generated-code-benchmarks/stage98-sysv-variable-shift-31/20260807-041238/report.json`.
- Stage98 SysV `log-b` loop under the persistent Ubuntu WSL driver: O0 median
  0.103968369 seconds and O2 median 0.076413161 seconds over 31 interleaved
  samples, with a 1.350562x median paired O2 speedup and identical `1530921062`
  output. Median CPU time decreased from 0.096298 to 0.069252 seconds. Report:
  `build/generated-code-benchmarks/stage98-sysv-log-b-31/20260807-041256/report.json`.
- Stage101 Win64 integer-division loop after callee-save allocation: O0 median
  0.132147 seconds and O2 median 0.1151674 seconds over 31 interleaved samples,
  with a 1.144635x median paired O2 speedup and identical `4850000` output.
  Median CPU time decreased from 0.125 to 0.109375 seconds. Report:
  `build/generated-code-benchmarks/stage101-integer-division-31/20260807-052450/report.json`.
- Stage103 Win64 integer-division loop after constant-divisor strength reduction:
  O0 median 0.131765 seconds and O2 median 0.0941433 seconds over 31 interleaved
  samples, with a 1.389445x median paired O2 speedup and identical `4850000`
  output. Median CPU time decreased from 0.125 to 0.078125 seconds. Report:
  `build/generated-code-benchmarks/stage103-integer-division-31/20260807-055929/report.json`.
- Stage104 SysV integer-division loop under the persistent Ubuntu WSL driver: O0
  median 0.116689328 seconds and O2 median 0.090788792 seconds over 31
  interleaved samples, with a 1.26493x median paired O2 speedup and identical
  `4850000` output. Median CPU time decreased from 0.108274 to 0.082708 seconds.
  Report:
  `build/generated-code-benchmarks/stage104-sysv-integer-division-31/20260807-060907/report.json`.
- Stage106 Win64 date-arithmetic loop: O0 median 0.5670221 seconds and O2
  median 0.293411 seconds over 31 interleaved samples, with a 1.930682x median
  paired O2 speedup and identical `-634967296` output. Median CPU time decreased
  from 0.546875 to 0.28125 seconds. Report:
  `build/generated-code-benchmarks/stage106-date-arithmetic-31/20260807-070130/report.json`.
- Stage108 SysV date-arithmetic loop under the persistent Ubuntu WSL driver: O0
  median 0.55551125 seconds and O2 median 0.255317943 seconds over 31
  interleaved samples, with a 2.177568x median paired O2 speedup and identical
  `-634967296` output. Median CPU time decreased from 0.549204 to 0.248904
  seconds. Report:
  `build/generated-code-benchmarks/stage108-sysv-date-arithmetic-31/20260807-072405/report.json`.
- Stage114 SysV five-case dense-switch loop after frameless single-exit
  lowering: O0 median 0.11 seconds and O2 median 0.08 seconds over 101
  interleaved WSL samples, with a 1.34x paired O2 speedup and identical
  `1120000000` output. Median CPU time decreased from 0.10 to 0.07 seconds.
  Report:
  `build/generated-code-benchmarks/stage114-sysv-small-dense-switch-101/20260807-083227/report.json`.
- Stage115 Win64 five-case dense-switch loop: O0 median 0.1248464 seconds and
  O2 median 0.1021486 seconds over 101 interleaved native samples, with a
  1.218992x paired O2 speedup and identical `1120000000` output. Median CPU
  time decreased from 0.109375 to 0.09375 seconds. Report:
  `build/generated-code-benchmarks/stage115-win64-small-dense-switch-101/20260807-084000/report.json`.
- Stage117/Stage118 Win64 framed pointer-index loop: the saved fallback O2
  binary had a 0.3678549-second median and the frame-memory selected O2 binary
  had a 0.3501501-second median over 51 alternating 100-million-iteration
  samples. The median paired wall-time speedup is 1.047184x; median CPU time
  decreased from 0.359375 to 0.34375 seconds. Every run produced `1400004096`.
  Report:
  `build/generated-code-benchmarks/pointer-frame-index-stage118/direct-fallback-vs-frame-memory-100m-result.json`.
- Stage113/Stage120 SysV framed pointer-index loop under the persistent WSL
  driver: the fallback O2 binary had a 0.355669230-second median and the
  frame-memory selected O2 binary had a 0.339168229-second median over 51
  alternating 100-million-iteration samples. Paired wall and CPU speedups are
  1.054558x and 1.053482x respectively, with identical `1400004096` output.
  Reports are under
  `build/generated-code-benchmarks/pointer-frame-index-sysv-stage118/`.
- Stage119/Stage122 Win64 pointer-comparison loop: the saved fallback O2 binary
  had a 0.2021115-second median and the selected O2 binary had a
  0.0515492-second median over 51 alternating 100-million-iteration samples.
  The median paired wall-time speedup is 3.901362x and the paired CPU speedup is
  4.333333x. Every execution produced `100000000`. Report:
  `build/generated-code-benchmarks/pointer-comparison-direct-stage122/direct-fallback-vs-selected-100m-result.json`.
- Stage120/Stage124 SysV pointer-comparison loop under the persistent WSL
  driver: the fallback O2 binary had a 0.205692906-second median and the selected
  O2 binary had a 0.037902811-second median over 51 alternating
  100-million-iteration samples. Paired wall and CPU speedups are 5.393911x and
  6.269814x respectively, with identical `100000000` output. Reports are under
  `build/generated-code-benchmarks/pointer-comparison-sysv-direct-stage124/`.

A 51-run alternating comparison isolates the spill-left two-address
legalization from the already optimized date loop. Stage105 fallback O2 had a
  0.4919279-second median, while Stage106 selected O2 had a 0.2908336-second
  median and a 1.691925x median paired speedup. Median CPU time decreased from
  0.484375 to 0.28125 seconds, and all 102 timed executions produced the same
  `-634967296` checksum.

A 101-run fallback-isolation comparison shows the frameless dense-switch change
itself is a runtime win. On SysV, the saved Stage108 framed fallback O2 binary
had a 0.088895957-second median versus 0.081182003 seconds for Stage114's
frameless O2 binary, for a 1.093161x paired wall-time speedup. Median CPU time
decreased from 0.081960 to 0.074198 seconds (1.106283x paired), with identical
`1120000000` output. On Win64, Stage107's fallback O2 binary had a
0.1086146-second median versus 0.1039615 seconds for Stage115's frameless
binary, for a 1.046236x paired wall-time speedup; CPU medians were both
0.09375 seconds at the available timer resolution. The raw comparisons are
stored under the corresponding Stage114 and Stage115 benchmark directories.

A separate 101-run alternating comparison isolated dense machine-IR lowering
from the established direct O2 jump-table lowering. Their raw medians were
0.106290 and 0.106223 seconds respectively, and the paired median differed by
only 0.03 percent. This meets the requirement that moving switch selection into
machine IR must not sacrifice generated-code speed.

A second 101-run alternating comparison isolated the resolver change. Stage63's
direct O2 resolver lowering had a 0.3462045-second median, while Stage64's typed
machine-IR lowering had a 0.2817161-second median and a 1.2285x median paired
speedup. The selected `resolve-node` wrapper is a frameless bounds-check and
lookup; `resolve-series` keeps the original helper call only in its invalid or
freed-handle slow block.

A third 101-run alternating comparison isolated comparison-only short-circuit
lowering. Stage69's direct O2 lowering had a 0.2134957-second median, while
Stage72's typed CFG lowering had a 0.2056781-second median and a 1.0410x median
paired speedup. Median process CPU time decreased from 0.203125 to 0.1875
seconds. Disassembly confirms that the selected helper loads its argument once,
compares it in a register, and lets the shared true block fall through to return.

A fourth 101-run alternating comparison isolated materialized short-circuit
branches. Stage73's direct O2 helper lowering had a 0.2418286-second median,
while Stage75's typed CFG helpers had a 0.2398261-second median and a 1.0094x
median paired speedup, with equal 0.234375-second median CPU time. This expansion
therefore adds coverage without regressing its established O2 fallback; the
larger O0/O1 gain is recorded above.

A fifth 101-run alternating comparison isolated namespace-qualified call
eligibility. Stage80's direct-fallback binary had a 0.0733181-second median and
Stage82's selected binary had a 0.0730506-second median, for a 1.003052x median
paired speedup. Both CPU medians were 0.0625 seconds and both outputs were
`20000000`. The expansion is therefore runtime-neutral to slightly positive.

A 51-run alternating cross-stage comparison isolates constant-shift selection
from the previously selected hot loop. Stage88 O2, whose `mix-hash` helper falls
back, had a 0.1034649-second median. Stage90 O2 selected that helper and had a
0.0597224-second median, for a 1.739603x paired median speedup. Median CPU time
decreased from 0.09375 to 0.046875 seconds. Both binaries produced
`1826080327` in all 102 timed samples. The old helper has a frame and repeatedly
loads and stores its local; the selected helper is a frameless ten-instruction
register sequence. Report:
`build/generated-code-benchmarks/stage88-vs-stage90-integer-shift-o2-51/20260807-021754/report.json`.

The Stage88 pointer-cast expansion is runtime-neutral in its focused call shape.
The Stage85 and Stage88 O2 medians were 0.0804585 and 0.0806549 seconds over 31
samples, with equal 0.0625-second CPU medians. Reports:
`build/generated-code-benchmarks/stage85-pointer-cast-call-31/20260807-013815/report.json`
and
`build/generated-code-benchmarks/stage88-pointer-cast-call-31/20260807-013824/report.json`.
An alternating three-pair compiler-throughput recheck likewise found no material
machine-IR smoke compile slowdown: Stage85 and Stage88 raw wall medians were
112.585559 and 112.966130 seconds, while the paired median favored Stage88 by
1.019566x with mixed pair directions.

Stage64 bootstraps successfully in release mode, passes all 124 compiler-regression
assertions, and passes the full Windows x64 Red/System O2 suite: 10,582 tests and
12,647 assertions with zero failures. The focused O0/O2 resolver fixture covers
valid, zero, negative, out-of-range, and freed handles; both modes print `8` with
exit status zero. Stage65 bootstraps both the PE-only Windows compiler and the
focused ELF Linux-x64 compiler from the current source; the emitted Linux O0/O2
resolver fixtures pass as described above. The machine-IR smoke fixture also
passes. Stage70 is compiled with O2 from the corrected Stage69 compiler, starts
normally, reports `0.6.6-selfhost.2`, and contains 61 selected functions with no
ineligible function emitted as selected code. Stage70 also recompiles and runs
the focused short-circuit fixture successfully. Stage72 starts normally, reports
`0.6.6-selfhost.2`, selects the focused short-circuit helper, and emits the
correct result `60000000`. With the x64 `structlib.dll` supplied to the harness,
Stage72 passes all 124 compiler-regression assertions and the full Windows x64
Red/System O2 suite: 10,582 tests and 12,647 assertions with zero failures.
Stage75 passes the same two suites after materialized branch and dead-relocation
support, again with zero failures. Stage76 is compiled under O2 from Stage75,
starts normally, and reports `0.6.6-selfhost.2`. Its dump contains 3,809
functions, 79 eligible functions, 63 selected functions, and no
`eligible=false selected=true` record. Stage76 recompiles the Red-level
`collect` smoke and the complete short-circuit fixture under O2; both executables
run successfully, all six focused helpers select, and all 16 side-effect and
result outputs match O0.

Stage77 is a focused Windows-hosted Linux-x64 compiler built from Stage76. Its
O2 dump selects all six short-circuit helpers with the SysV ABI and contains no
`eligible=false selected=true` record. The O0 and O2 ELF semantics fixtures have
identical 16-line output, and the two generated-runtime measurements above both
validate their checksum before recording time. The benchmark harness runs
verification, warmups, and interleaved samples inside one persistent WSL driver,
so WSL startup time is excluded. An attempted Stage65 comparison was excluded:
that older experimental Linux compiler incorrectly reduced the materialized
`all` helper to an unconditional tail call and produced `80000000` instead of
`60000000`; it is correctness evidence, not a performance baseline.

Stage78 adds scalar C-variadic machine-IR calls on Win64. The focused fixture
selects a native variadic call and two imported `sprintf` wrappers, including
nine floating arguments; O0 and O2 print the same three lines. Disassembly shows
the required first-four-slot XMM-to-integer duplication, IAT call encoding, and
one function-level shadow/outgoing area. Stage79 is the corresponding focused
Linux-x64 compiler. Its first runtime exposed a legacy SysV stack-parity mismatch;
selected calling functions now align `RSP` once before reserving their frame.
The corrected O0 and O2 ELF fixtures print identical output. Disassembly shows
`AL=1` for the mixed call and `AL=8` with the ninth `f64` stored at `[RSP]`.

Stage80 is compiled under O2 from Stage78, starts normally, and reports
`0.6.6-selfhost.2`. Its dump contains 3,812 functions, 79 initially eligible
functions, 63 selected functions, and no `eligible=false selected=true` record.
It recompiles and runs the focused variadic fixture with all four helpers
selected, passes all 124 compiler-regression assertions, and passes the full
Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with zero
failures. A targeted SysV O0/O2 differential additionally passes `vararg-test`,
`function-test`, `float-test`, `overflow-test`, `exceptions-test`, and
`push-pop-test` with identical output and 2,100 combined passing assertions.

Stage82 is compiled under O2 from the scanner-refined Stage81 compiler, starts
normally, and reports `0.6.6-selfhost.2`. Its dump contains 3,812 functions,
124 initially eligible functions, 95 selected functions, and no
`eligible=false selected=true` record. The 32 newly selected functions are
exactly a subset of Stage80's 45 path-only fallbacks; the thirteen non-selected
candidates now report independent selector reasons. Stage82 passes all 124
compiler-regression assertions and the full Windows x64 Red/System O2 suite:
10,582 tests and 12,647 assertions with zero failures. Stage83 is the matching
focused Linux-x64 compiler. Its qualified-symbol fixture has identical O0/O2
output, selects both normalized namespace operations, and retains fallback for
the real pointer path. The six-program SysV differential again passes all 2,100
assertions with identical O0/O2 output.

Stage85 is compiled under O2 from the pointer-aware Stage84 compiler, starts
normally, and reports `0.6.6-selfhost.2`. Its release dump contains 3,793
functions, 3,781 verified functions, 221 initially eligible functions, and 196
selected functions, with no `eligible=false selected=true` record. The focused
pointer fixture selects all four arithmetic helpers and gives identical O0/O2
output for positive, negative, subtracting, 16-byte-cell, and large signed-index
cases. Stage85 passes all 124 compiler-regression assertions and the full Windows
x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with zero failures.

Stage86 is the matching focused Linux-x64 compiler. The same pointer fixture
selects all four helpers under the SysV ABI and its O0/O2 ELF outputs both print
five successful checks. The six-program SysV differential passes `vararg-test`,
`function-test`, `float-test`, `overflow-test`, `exceptions-test`, and
`push-pop-test` with identical O0/O2 output and 2,100 passing assertions. The
generated-runtime result above validates the pointer-loop checksum before every
warmup and interleaved sample.

Stage88 self-hosts successfully after the representation-bitcast expansion,
reports `0.6.6-selfhost.2`, passes all 124 compiler-regression assertions, and
passes the full Windows x64 Red/System O2 suite with 10,582 tests and 12,647
assertions. The pointer-cast fixture selects all four helpers and gives identical
O0/O2 output.

Stage90 self-hosts with the constant-shift selector active, starts normally,
reports `0.6.6-selfhost.2`, and has no `eligible=false selected=true` record. Its
`-d` configuration dump contains 3,825 functions, 3,813 verified functions, 180
initially eligible functions, and 155 selected functions; those aggregate counts
are not compared directly with the differently configured Stage88 release dump.
Stage90 passes all 124 compiler-regression assertions and the full Windows x64
Red/System O2 suite: 10,582 tests and 12,647 assertions with zero failures. The
focused O0/O2 shift fixture prints six successful checks. Three constant-count
helpers select, while the variable-count helper retains direct code.

Stage91 is the matching focused Linux-x64 compiler. Its O2 dump selects the same
three helpers under the SysV ABI and reports `x64-shift-variable-count` for the
fourth. O0 and O2 ELF fixtures print the same six successful checks. The
six-program SysV differential passes `vararg-test`, `function-test`, `float-test`,
`overflow-test`, `exceptions-test`, and `push-pop-test` with identical O0/O2
output, 2,007 tests, and all 2,100 assertions passing.

Stage97 is the final Win64 bootstrap for the variable-shift and `log-b` expansion.
It starts normally, reports `0.6.6-selfhost.2`, and its dump contains 3,829
functions, 3,817 verified functions, 180 initially eligible functions, 156
selected functions, and no `eligible=false selected=true` record. In particular,
`red>deflate>npow2` contains typed `log-b` and variable-shift operations and is
selected. Stage97 passes all 124 compiler-regression assertions and the full
Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with zero
failures. The corrected focused `log-b` fixture passes all 14 O0/O2 checks,
including the loop checksum that exercises an immediate allocated to a spill.

Stage98 is the matching Windows-hosted Linux-x64 compiler. Its SysV shift dump
selects all three constant-count and all three variable-count helpers; its
`log-b` dump selects `log-value`, `next-power-of-two`, and the checksum loop.
Their O0 and O2 ELF executables respectively print ten and fourteen successful
checks. Disassembly contains `SHL`, `SAR`, and `SHR` with `CL`, plus `BSR`. The
six-program SysV differential again passes `vararg-test`, `function-test`,
`float-test`, `overflow-test`, `exceptions-test`, and `push-pop-test` with
identical O0/O2 output, 2,007 tests, and all 2,100 assertions passing. Reports are
under `build/generated-code-benchmarks/stage98-sysv-differential/`.

Stage101 is the final Win64 bootstrap for call-live callee-save allocation. The
focused division loop keeps its index and count in saved registers across helper
calls, saves each used register once in the frame, and has no per-call scalar
spill/reload sequence. It passes all 124 compiler-regression assertions and the
full Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with
zero failures.

Stage103 is the magic-division-enabled Win64 bootstrap. The 17-case focused
fixture gives identical O0/O2 results for positive and negative division,
remainder, and modulus. Disassembly of the benchmark helpers contains the
audited multiply-high sequences for 100, 400, and 800 instead of `IDIV`. Stage103
again passes all 124 compiler-regression assertions and the full Windows x64 O2
suite: 10,582 tests and 12,647 assertions with zero failures. The intermediate
Stage102 SysV benchmark was only 1.010531x faster than O0; that near-neutral
result exposed `IDIV` as the remaining hot cost and motivated the measured
Stage103/Stage104 strength reduction rather than treating code-size reduction as
success.

Stage104 is the matching Windows-hosted Linux-x64 compiler. Its O0 and O2 focused
division fixtures both print 17 successful checks, and the runtime benchmark
validates the same `4850000` checksum before every sample. An expanded SysV
differential covers `vararg-test`, `function-test`, `float-test`,
`overflow-test`, `exceptions-test`, `push-pop-test`, `integer-test`, and
`modulo-test`. O0 and O2 produce identical output across 2,821 tests and 3,679
assertions, all passing. Reports are under
`build/generated-code-benchmarks/stage104-sysv-differential/`.

Stage107 is the final Win64 bootstrap for spill-left two-address legalization.
It starts normally and its dump contains 3,847 functions, 3,835 verified
functions, 180 initially eligible functions, and 159 selected functions. Both
previous `x64-two-address-conflict` functions select and no fallback with that
reason remains. The six-case date fixture gives identical O0/O2 output, and
disassembly contains both expected scratch/result sequences. Stage107 passes all
124 compiler-regression assertions and the full Windows x64 Red/System O2 suite:
10,582 tests and 12,647 assertions with zero failures.

Stage108 is the matching Windows-hosted Linux-x64 compiler. The same three date
helpers select with the SysV ABI, and the O0/O2 fixtures print the same six
successful checks. The expanded SysV differential again covers the eight
programs listed for Stage104, with identical O0/O2 output across 2,821 tests and
3,679 assertions, all passing. Reports are under
`build/generated-code-benchmarks/stage108-sysv-differential/`.

Stage112 is the Win64 bootstrap for the guarded frameless dense-switch path.
The focused five-case switch is selected with `mov eax, ecx`, a range check,
and a jump table, with no stack-frame prologue; O0 and O2 print identical
results. Stage112 passes all 124 compiler-regression assertions and the full
Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with zero
failures. Stage113 is the matching Windows-hosted Linux-x64 compiler; its dump
selects the same function with `mov eax, edi`, and its O0/O2 ELF outputs also
match. The machine-IR smoke fixture covers both ABI encodings and rejects
multiple-return control flow for this path.

Stages114 and 115 provide the 101-sample runtime evidence recorded above. The
five-case threshold is therefore enabled for both ABIs only because the
frameless lowering removes the measured SysV regression. Sparse switches,
multi-exit dense switches, and functions with observable stack or call effects
continue to use their existing fallback paths.

Stage116 repeats the expanded SysV differential with Stage113. O0 and O2 produce
identical output for `vararg-test`, `function-test`, `float-test`,
`overflow-test`, `exceptions-test`, `push-pop-test`, `integer-test`, and
`modulo-test`: 2,821 tests and 3,679 assertions pass with zero failures. Reports
are under `build/generated-code-benchmarks/stage116-sysv-differential/`.

Stage119 is the fixed-point Win64 bootstrap for folded frame pointer indexes.
The thirteen functions that reported `x64-missing-allocation` in Stage117 now
all select, including `red>type-check-opt`, `red>string>to-float`, and eleven
`red>actions` wrappers. The focused O0/O2 fixture passes positive, negative, and
large signed-index cases. Stage119 passes all 124 compiler-regression assertions
and the full Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions
with zero failures.

Stage120 is the matching Windows-hosted Linux-x64 compiler. Its focused O0/O2
ELF fixture prints the same three successful checks, and disassembly contains
`movslq -0x30(%rbp), %r11` followed by a scaled `lea`. Stage121 repeats the
expanded SysV differential with Stage120. O0 and O2 produce identical output for
the same eight programs as Stage116: 2,821 tests and 3,679 assertions pass with
zero failures. Reports are under
`build/generated-code-benchmarks/stage121-sysv-differential/`.

Stage123 is the fixed-point Win64 bootstrap for typed pointer comparisons. Its
focused O0/O1/O2 fixture prints four successful unsigned high-bit and equality
checks, while disassembly shows frameless `CMP r64,r64`, `SETcc`, `MOVZX`, and
`RET` helpers. Stage123 passes all 124 compiler-regression assertions and the
full Windows x64 Red/System O2 suite: 10,582 tests and 12,647 assertions with
zero failures. Stage124 is the matching Windows-hosted Linux-x64 compiler. Its
focused O0/O1/O2 ELF fixture prints the same four checks, and disassembly uses
`cmp %rsi,%rdi` with `setb`, `seta`, `setbe`, and `setae`. Stage125 repeats the
expanded SysV differential with Stage124. O0 and O2 produce identical output
for `vararg-test`, `function-test`, `float-test`, `overflow-test`,
`exceptions-test`, `push-pop-test`, `integer-test`, and `modulo-test`: 2,821
tests and 3,679 assertions pass with zero failures. Reports are under
`build/generated-code-benchmarks/stage125-sysv-differential/`.

Stage131 is the final fixed-point Win64 bootstrap for relocation ownership and
call-live profitability. Its dump contains 3,855 functions, 3,843 verified
functions, 180 eligible functions, and all 180 selected, with no x64 selector
fallback. `red>externals>init`, `red>references>init`,
`red>object>fire-on-set*`, `red>image>resize`, and `red>actions>poke*` all select;
none of the real compiler candidates triggers the size-backed call-live guard.
Stage131 passes all 124 compiler-regression assertions and the full Windows x64
Red/System O2 suite: 10,582 tests and 12,647 assertions with zero failures.
Fifteen alternating O2 compilations of `float-test.reds` compare Stage127 with
Stage131 at `0.997x` paired wall and `0.998x` paired CPU speed, with identical
generated test output. This is runtime-neutral evidence within the 2 percent
no-regression gate, not evidence of a compiler-speed gain. The report is
`build/compiler-benchmarks/stage127-vs-stage131-float-o2/report.json`.

Stage132 is the matching Windows-hosted Linux-x64 compiler. Its dump contains
4,137 functions, 4,125 verified functions, 180 eligible functions, and all 180
selected, again with no x64 selector fallback. The focused nested-relocation
O0/O1/O2 ELF fixture prints identical `19` and `8` results and records
`x64-call-live-expansion` for the measured slower helper on SysV as well.
Stage133 repeats the expanded SysV differential with Stage132. O0 and O2 produce
identical exit status, stdout, and stderr for `vararg-test`, `function-test`,
`float-test`, `overflow-test`, `exceptions-test`, `push-pop-test`,
`integer-test`, and `modulo-test`: 2,821 tests and 3,679 assertions pass with
zero failures. Reports and the aggregate summary are under
`build/generated-code-benchmarks/stage133-sysv-differential/`.

Stage134 is the Stage1-built Win64 compiler containing the full-width scalar
stack-slot store. On the focused 101-sample `register-pressure-loop`, the old
Stage131 O2 binary was 1.0231x the O0 runtime (2.31% slower; 95% interval
1.0206..1.0261). Stage134 is 0.6692x O0 (33.08% faster; interval
0.6679..0.6717). The 12-workload Win64 core suite moves from a 0.5129x to a
0.4958x geometric-mean runtime ratio, with no credible regression. Reports are
under `build/generated-code-benchmark-suites/stage131-win64-register-pressure-101/`,
`stage134-win64-register-pressure-101/`, and
`stage134-win64-core/`.

Stage135 is the matching Windows-hosted Linux-x64 compiler. Its focused
SysV pressure result moves from Stage132 at 1.0266x O0 (2.66% slower; credible
above the two-percent gate) to 0.6331x O0 (36.69% faster; 95% interval
0.6319..0.6342). The final metadata-complete 12-workload SysV core suite has a
0.4794x geometric-mean runtime ratio (52.06% faster) and no credible regression.
Reports are under
`build/generated-code-benchmark-suites/stage132-sysv-register-pressure-101/`,
`stage135-sysv-register-pressure-101/`, and `stage135-sysv-core-v2/`.

Stage136 reruns the eight-program SysV O0/O2 differential with Stage135. All
2,821 tests and 3,679 assertions pass with zero failures, and every program's
exit status, stdout, and stderr are identical. The suite report is under
`build/generated-code-benchmark-suites/stage136-sysv-differential/`.

Stage137 is the O2 self-hosted Win64 fixed-point candidate. Its dump contains
3,855 functions, 3,843 verified functions, 180 eligible functions, and all 180
selected, with no eligible non-selection or x64 selector fallback. It passes
all 124 compiler-regression assertions and the full Win64 suite (10,582 tests,
12,647 assertions, zero failures). Its metadata-complete 12-workload Win64 core
suite has a 0.4950x geometric-mean runtime ratio (50.50% faster), with no
credible regression. The dump is
`build/self-hosting/red-bootstrap-o2-ir-stage137.ir`; the performance report is
under `build/generated-code-benchmark-suites/stage137-win64-core/`.

Stage143 is the corrected fixed-point Win64 compiler for typed local member
stores. Its dump contains 3,864 functions, 3,852 verified functions, 214
eligible functions, and all 214 selected, with `red>collector>init` and other
inline global aggregate stores retaining the direct `path-assignment` fallback.
The first implementation admitted an inline global struct as though a global
load were an address; the eligibility rule now requires a function-local or
argument root until a separate RIP-relative address-of-global IR operation and
by-value representation check exist. A second fixed-point regression exposed
that direct Win64 call preparation can reverse a nested qualified call's
argument block in place. The IR snapshot now recursively copies action objects
and their call data before direct lowering; the focused assigned `[cdecl]` cast
fixture returns `102` at both O0 and O2, and the member-store fixture returns
`41`, `true`, and `2.5` at both levels.

Stage143 passes all 124 compiler-regression assertions and the complete
Windows x64 Red/System suite: 10,582 tests, 12,647 assertions, and zero
failures. The x64 suite must use the x64 `structlib.dll` artifact (the checked-in
legacy `structlib.dll` is IA-32); the verified dependency used here is
`build/self-hosting/x64-structlib/structlib.dll`.

Stage169 adds typed aggregate call metadata and one pre-allocation argument
location plan for SysV x64. Each aggregate records its flattened operand range,
INTEGER/SSE classes, exact size, and whether it must be passed on the stack.
The planner enforces the SysV all-registers-or-all-stack rollback rule before
linear-scan allocation and shares that decision with outgoing-frame sizing and
late encoding. Imported aggregate returns now cover RAX/RDX, XMM0/XMM1, mixed
INTEGER/SSE class order, and hidden result buffers. The hidden pointer shifts
subsequent aggregate groups as one unit.

The focused Linux fixture calls a GCC-built shared library with mixed
INTEGER/SSE, SSE/INTEGER, pure-SSE, register-pressure rollback, memory-class
arguments, register returns, and a memory-class hidden return that also accepts
a mixed aggregate argument. Its Stage169 O0 and O2 PIE executables both exit 0
under Ubuntu 24.04 WSL. All nine wrapper functions are eligible and selected at
O2. Disassembly of the hidden-return case confirms `RDI` holds the result
buffer, `RSI` and `XMM0` hold the aggregate classes, and `EDX` holds the trailing
scalar. The machine-IR smoke fixture now has 91 functions and independently
checks mixed register placement, whole-aggregate rollback, and exact mixed
return bytes.

Stage172 extends aggregate lowering to native and imported Win64 calls and adds
typed variadic-list construction, aggregate temporaries and copies, exact-width
32/64-bit integer constants, floating-point constants, and 16-byte cell copies.
The focused aggregate, imported-aggregate, floating-constant, cell-copy, and
`#typed` programs produce identical O0/O2 results on Win64; the corresponding
SysV aggregate and typed programs also exit successfully at both levels. The
typed wrapper is selected at O2, and the machine-IR smoke has 93 verified
functions with four intentional unsupported cases.

Stage173 fixes two regressions exposed by the full Win64 suite. A commutative
constant on the left of a folded frame-memory operand was marked for immediate
encoding but then read from its uninitialized allocation register; selection now
materializes the constant before the direct memory operation. Simple local
tagged-union assignment now emits the required ordered variant-tag store before
the payload store. The focused memory program prints `19`, `12`, and `123` at
both O0 and O2, while the formerly failing union and aggregate-callback tests
pass completely.

Stage173 was bootstrapped in development mode from the newest compatible
Stage172 compiler. Runtime sources were unchanged, and the matching
`libRedRT.dll` remained byte-identical (SHA-256
`96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`). It passes
all 124 compiler-regression assertions and the complete Windows x64 O2 suite:
10,582 tests, 12,647 assertions, and zero failures.

The generated-program runtime gate is positive with speed as the primary
metric. A 31-sample register-pressure run measures an O2/O0 wall ratio of
`0.671789` (32.821% faster; paired 95% interval `0.67..0.68`). The 12-workload
Win64 core suite, using 15 interleaved samples per workload and release/no-debug
outputs, measures a geometric-mean ratio of `0.495734` (50.427% faster) with no
credible regression. Reports are under
`build/generated-code-benchmark-suites/stage143-win64-pressure/` and
`build/generated-code-benchmark-suites/stage143-win64-core/`.

Stage174 extends the evidence to both x64 ABIs after typed custom calls, explicit
stack state, aggregate ABI handling, managed-root call liveness, and exception
unwind integration. The 12-workload suites use two warmups and 15 interleaved
O0/O2 runs per workload. Win64 measures an O2/O0 geometric-mean ratio of
`0.479607` (52.039% faster, 95% interval `0.458739..0.486023`); SysV measures
`0.471707` (52.829% faster, interval `0.461967..0.508404`). Both gates pass with
no credible or point-estimate regression. Reports are under
`build/generated-code-benchmark-suites/stage174-win64-core/` and
`build/generated-code-benchmark-suites/stage174-sysv-core/`.

The first successful current Win64 `atomicfix` development compiler is the
post-control-flow validation artifact; it is not a dependency on a numbered
historical stage. Its SHA-256 is
`8E984B0BA9B73D288E0F8DDA9F45D4C23B5190B8F1F66FA9348A7E5BD944D787`, and the
adjacent Stage1-built `libRedRT.dll` remains
`96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`. At commit
`45a569f6b`, the same 12-workload Win64 protocol measures `0.481164` (51.884%
faster, interval `0.464283..0.518892`) with no regression. The report is under
`build/generated-code-benchmark-suites/atomicfix-current-win64/`.

The report's recorded Git HEAD is `45a569f6b`, while this successful executable
was built earlier, before the final target-file and atomic-fixture edits. It is
therefore valid core runtime evidence for the successful artifact, but not a
source-identical final bootstrap proof; the default-enablement audit below
requires that exact-source rebuild.

Commit `45a569f6b` completes the planned control-flow and machine-state expansion:
explicit `return` and `exit`, `if`/`either`/`case`/`switch`, `loop`/`until`/
`while` with `break` and `continue`, nested and lexical `overflow?` flag scopes,
custom calls backed by explicit stack state, and typed x64 atomic operations.
The current machine-IR smoke dump has 106 verified functions, 102 selected
functions, and four intentional unsupported cases. It independently exercises
the IR passes, ABI planners, allocator, memory and LEA selection, branch
relaxation, relocations, debug offsets, GC verification, and exact encodings.

Focused O0/O2 differential runs compare exit status, stdout, and stderr. Win64
covers case control, explicit returns, loops, custom calls, managed node handles,
byte and integer overflow flags, resolver calls without a registry, and unwind
through an O2 frame. SysV covers the same semantics plus aggregate callback
entry. The emitted Stage174 SysV eight-program suite produces identical O0/O2
behavior across 2,821 tests and 3,679 assertions. The complete Win64 suite passes
10,582 tests and 12,647 assertions, and the compiler regression passes all 124
assertions. GC safepoint executables pass at O0 and O2 on Win64 and at O0, O1,
and O2 on SysV; the direct atomic fixture passes at O0 and O2 on both ABIs, and
the original multithreaded atomic test passes all eight checks.

These results complete the implementation phases while O2 remains explicitly
experimental and opt-in. A source-identical final fixed-point fallback census
and a controlled compiler-sized runtime comparison are still required by the
separate default-enablement decision. Old Stage178/Stage179 dumps are historical
diagnostics and must not be presented as final coverage for `45a569f6b`.

## Rollout

1. Land the IR and verifier with no optimizing behavior change.
2. Enable one phase at a time behind O2 sub-options suitable for bisection.
3. Keep per-function fallback counters and report why each function fell back.
4. Run the full differential suite and runtime benchmark set at each eligibility
   expansion.
5. Keep O2 explicitly experimental until Win64 and SysV pass the feature matrix,
   GC stress, self-hosting, ABI, debug/unwind, and performance gates.
6. Removing the experimental status or making O2 the default requires a separate
   decision backed by recorded benchmark and correctness results. It is not an
   automatic consequence of completing the implementation phases.

## Implementation Completion Criteria

The implementation plan is complete when:

- O0 and O1 retain their existing behavior and code paths.
- O2 uses verified typed machine IR for the intended Red/System feature set on
  Win64 and SysV x64, with documented fallback only where explicitly accepted.
- Constant/copy propagation, local value numbering, dead-code elimination,
  branch folding, memory/LEA selection, linear-scan allocation, function-level
  call/frame planning, and late encoding are independently tested.
- Left-to-right observable behavior, aliasing, explicit stack semantics,
  arithmetic flags, GC roots, exceptions, and debug mappings pass focused and
  differential tests.
- Generated-program runtime meets the aggregate performance gate on both ABIs.
- Benchmark evidence and accepted limitations are recorded in the repository.

At `45a569f6b`, these implementation criteria are satisfied by the evidence
above. This does not enable O2 by default. Default enablement additionally
requires a source-identical final fixed-point fallback census, a controlled
compiler-sized runtime gain, and a fresh full-suite audit using the exact
candidate compiler. Those are rollout gates, not reasons to rebuild historical
stages during ordinary focused development.
