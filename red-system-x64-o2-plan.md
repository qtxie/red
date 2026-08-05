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

As of Stage38, the experimental O2 path supports scalar Win64 and SysV direct
calls with ABI register arguments, stack arguments, parallel register copies,
and one function-level outgoing argument area. Values live across calls use
typed spill slots; call lowering can reload those values directly into their
later ABI argument registers after completing register-to-register copies. This
covers source forms such as `consume-two value (one)` without falling back.

The focused Win64 register-argument-across-call benchmark records an O0 median
of 0.25 seconds and an O2 median of 0.14 seconds over 15 interleaved samples, a
median paired speedup of 1.85x. The report is at
`build/generated-code-benchmarks/stage38-register-argument/20260806-004522/report.json`.
Stage38 passes all 124 compiler-regression assertions and the full Red/System O2
suite (10,582 tests and 12,647 assertions, zero failures).

This evidence does not complete the plan. Generic relocation consumption, GC
safepoint/root maps, unwind integration, aggregate and variadic ABI lowering,
and emitted SysV binary validation remain required before O2 can leave its
experimental state.

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

## Completion Criteria

The plan is complete when:

- O0 and O1 retain their existing behavior and code paths.
- O2 uses verified typed machine IR for the intended Red/System feature set on
  Win64 and SysV x64, with documented fallback only where explicitly accepted.
- Constant/copy propagation, local value numbering, dead-code elimination,
  branch folding, memory/LEA selection, linear-scan allocation, function-level
  call/frame planning, and late encoding are independently tested.
- Left-to-right observable behavior, aliasing, explicit stack semantics,
  arithmetic flags, GC roots, exceptions, and debug mappings pass focused and
  differential tests.
- Generated-program runtime meets the performance gate on both ABIs.
- Benchmark evidence, fallback coverage, and any accepted limitations are checked
  into the repository with the final enablement change.
