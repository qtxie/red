# Hybrid Red/System Codegen Execution Plan

Status: implementation in progress. The draft schema generator, dual-language
constants, compiler-core ownership gate, checked common-container readers, and
independent RSCF, data-layout, string, file, checksum, source-location, type/
aggregate-layout, function/signature, module-lifecycle, symbol/linkage,
constant/global-initializer, scalar-operation, memory/aggregate-operation,
control-flow, calls/ABI, atomic-operation, subroutine, exception,
explicit-stack, target-intrinsic, and RSDG diagnostic verifiers now have
executable coverage. The bounded native arena/writer, aggregate RSIR verifier,
and first `codegen-module` routine bridge also have cross-language integration
coverage. An allocation-free canonical string merger and the first Windows x64
machine-code slice now produce an exact, self-verified RSCG for one internal
`void` function containing only `RETURN`. A GLUE entry lowers that return to an
explicit `ExitProcess(0)` import and RIP-relative RSCG relocation; ordinary
USER/SUPPORT functions retain the original body. A bounded Red container
writer and minimal RSIR producer create that semantic module without emitter or
machine-IR input and pass it through the compiled routine integration test. An
exclusive `compiler-rsir-core.red` path sends the same semantic event to the
producer without compiling or initializing the legacy compiler core, emitter,
or machine IR. The first
failure-atomic linker adapter slice maps the verified GLUE object into the
legacy PE linker, and a fresh process loads, links, and executes the result
without frontend semantic state. The strict driver now connects that slice to
codegen, the adapter, and the linker exactly once. A recursive source-closure
test rejects `compiler-core.red`, `emitter.red`, and `machine-ir*.red` from the
hybrid package. The designated legacy compiler completes the hybrid compiler's
frontend-only build in 34.9 seconds and writes a 4.50 MB generated Red/System
source plus a 483 KB Redbin payload. Compiling even the smaller AOT integration
package through the legacy native emitter still takes 3 minutes 25 seconds, so
that native phase is a comparison baseline, not a valid fast-build route.
The protocol remains unfrozen until the remaining Windows x64 feature blockers
and message-level semantic fixtures satisfy the Phase 1 exit criteria.

The detailed contracts are in [the wire protocol](compiler-wire-format.md) and
[the backend ownership audit](compiler-backend-ownership.md).

## Objective

Replace the Red implementation of Red/System native code generation with an
embedded Red/System backend while retaining the existing Red semantic frontend
and Red image linker:

```text
Red source -> Red frontend -> generated Red/System source
                                |
Red/System source -> Red semantic frontend -> RSIR
                                            |
                                   codegen-module routine!
                                            |
                                      RSCG object
                                            |
              embedded runtime RSCG ------>+----> RSCG merger
                                                       |
                                                linker adapter
                                                       |
                                                existing linker
```

The end state contains no emitter fallback. The development build must also
exclude the legacy emitter and machine-IR sources so changing the compiler does
not trigger their compilation. A release executable remains statically linked
and has no new `libRedRT.dll` dependency; a development package may reuse its
existing `libRedRT.dll` only when measured separately and without changing
correctness.

## Final acceptance

The core product gate is not a smoke program or a reduced backend fixture. On a
Windows x64 host, the final hybrid compiler must make this repository runner
exit with status zero:

```powershell
rebcmdview.exe -s run-all-tests-x64.r --binary <hybrid-compiler.exe> --batch
```

`rebcmdview.exe` here is only the repository's existing test orchestrator; it is
not used to compile the hybrid compiler. The `--binary` argument makes the
generated hybrid compiler the compiler under test. This runner covers compiled
and interpreted Red tests, Red compiler regressions, the complete target-
applicable Red/System compiler and unit suite, plus the Windows x64 ABI,
release, development, DLL, WindowLongPtr, and View native phases. Target
conditions already encoded by the canonical runner are allowed; a hybrid-only
failure allowlist is not.

The same candidate must satisfy both compiler-build gates: the designated
legacy compiler's frontend-only seed route plus hybrid backend, and hybrid
generation N building N+1. Neither timed route may enter the legacy emitter
native phase. The suite gate is rerun after runtime-object caching and again on
the fixed-point generation used for release.

## Evidence and constraints

The profiling work preceding this plan established:

- a profiled release compiler spent about 82.6 seconds in accumulated
  `rs-loader` work, about 36 seconds in backend finalization, and about 8 seconds
  linking the small `hello.red` workload;
- the runtime prolog dominates the compile because release mode loads and
  compiles the runtime on every invocation;
- current O2 machine IR is recorded alongside direct emitter work, uses direct
  bytes for prolog/frame facts, and falls back per function;
- current linker input is not a generic relocation table. It consumes nested
  symbol reference lists, import callsite lists, compiler-owned debug function
  specifications, and GC compatibility symbols;
- `routine!` passes a `binary!` as a `red-binary!` cell, and series expansion can
  invalidate a previously acquired data pointer.

Consequently, native codegen alone cannot deliver the desired end-to-end speed.
The same design must enable a relocatable, statically embedded runtime RSCG so
release compilation skips the runtime loader and semantic frontend without
switching to a runtime DLL.

## Architectural decisions

| Decision | Reason |
| --- | --- |
| whole-module routine call | avoids Red/R/S calls per function and enables module optimization |
| four versioned messages | configuration and diagnostics need the same bounded ABI discipline |
| target-parametric semantic IR | Red/System type layout depends on target, but machine details do not belong in frontend |
| typed temporaries/slots, SSA in native MIR | moves CFG analysis, phi construction, and promotion out of Red |
| no serialized frame/stack/liveness state | these facts become invalid when codegen changes layout |
| relocatable RSCG, not final bytes | permits static runtime caching and multi-module linking |
| native arena plus one output append | prevents Red-series relocation bugs and repeated expansion |
| module-level `rsir` failure | a hidden per-function fallback would retain emitter dependencies indefinitely |
| legacy linker adapter first | reduces initial scope while making every old encoding explicit and testable |
| O0/O1 correctness before O2 | the current O2 path is experimental and is not the migration foundation |
| source-closure exclusion | an uncalled legacy emitter still makes the compiler itself slow to build |
| two fast bootstrap routes | legacy-seeded and hybrid-to-hybrid compiler evolution must both be fast |

Two mutually exclusive driver modes are allowed during migration:

- `legacy`: current emitter only;
- `rsir`: RSIR -> Red/System codegen -> RSCG -> linker, with unsupported input a
  hard diagnostic and no emitter invocation.

There is no same-invocation shadow mode. Differential evidence comes from
separate `legacy` and `rsir` runs so a production compile never performs both
backend workloads.

## Phase 0: baseline and dependency audit

Deliverables:

- retain phase timing for loader, semantic lowering, function finalization,
  linker preparation, and linker build;
- record compiler identity, optimization level, release/development mode,
  runtime dependency list, wall time, CPU time, and peak memory with each run;
- create a semantic ownership inventory for every direct call from
  `compiler-core` into `emitter` or `target`;
- classify all linker reads of emitter/compiler data, including magic runtime
  symbols, imports, exports, debug, GC, PIC, and static-object paths.

Exit criteria:

- every dependency is assigned to frontend, RSIR, codegen, RSCG, adapter, or
  linker; there is no "copy existing object" category;
- baseline commands and raw reports are reproducible from a clean release
  compiler build.
- compiler-build reports distinguish Red lowering, RSIR serialization, native
  codegen, linking, and prebuilt-runtime or cached-interface work;
- a dependency-closure audit rejects `compiler-core.red`, `emitter.red`, target
  emitters, and `machine-ir.red` from the hybrid development package before
  timing begins.

The initial profiling, reverse audit, and exhaustive compiler-core ownership
inventory are complete. Auditing implementation-side emitter/target behavior
and linker consumption remains part of phase 1 because it controls schema
freeze.

The common container, RSCF configuration, Windows x64 data layout, canonical
UTF-8 string tables, file checksums, source-location ordering, and structured
RSDG failures now have independent Red and Red/System verifiers with shared
malformed corpora. Canonical representation types and natural struct/raw-union/
tagged-union layouts are also checked independently, including forward pointer
recursion and topologically ordered by-value aggregate dependencies. Module
roles, executable/DLL identity, lifecycle function references, glue shape, and
RSCG multi-object symbol provenance are now checked independently as well.
Function signatures and definitions, symbol/import/export identity, the
topologically ordered constant graph, symbolic address expressions, named
constant bindings, mutable global storage, and zero/explicit initializers are
checked independently too. Scalar values, deterministic instruction/operand
ownership, conversions, arithmetic, comparisons, shifts, checked overflow,
managed-handle boundaries, and exact scalar effects are now specified for the
same independent verification path. Typed local/global/indirect memory access,
canonical address paths, exact alias and volatile effects, by-value aggregate
construction, overlap-safe aggregate copy, and explicit tagged-union state are
now specified and checked on that path as well. Block/edge partitioning, exact
branch/jump/switch/return/unreachable shapes, virtual CFG roots, direct-value
dominance, and explicit merge-slot ownership are now specified and checked too;
call descriptor domains, logical argument slices, variable-arity protocols,
conservative call effects, and derived Win64 aggregate/hidden-return rules are
now specified and checked too. Atomic RMW operation IDs, legal memory orders,
exact signed-i32 pointer/value/result shapes, old/new return behavior, effects,
aliases, and the natural-alignment producer contract are independently checked
as well. Exception region kinds and membership, exact handler nesting, entry
and leave boundaries, exception-edge suffixes, `THROW`, `[catch]` call wrappers,
callback boundaries, and conservative stack interaction are independently
checked as well. Named host-owned subroutine regions, effective signatures,
dedicated returns, call ownership, recursion boundaries, and execution-region
CFG isolation are independently checked too. Explicit stack instruction
shapes, signed slot counts, exact/dynamic fixed-point joins, opaque
`PUSH_ALL`/`POP_ALL` regions, custom-call consumption, and subroutine return
depth are now checked on the same path with allocation-free native workspace;
stack-top and frame-address reads have explicit pointer result shapes. Target
fragments, typed port I/O, current-PC capture, x64 CPU-register access, and the
Win64 syscall argument limit now have exact instruction, type, effect, alias,
clobber, return, source, and data-ownership contracts. Independent Red and
allocation-free Red/System target-intrinsic verifiers check those contracts
against one shared malformed corpus.
Canonical RSCG CODE/RODATA/DATA/BSS ownership, defined and unresolved symbols,
function extents, lifecycle references, and the x64 runtime image/bitmap roles
now have the same independent Red and failure-atomic Red/System verification.
Typed `X64_REL32`, RIP-relative and IAT references, `ABSOLUTE64`
data/rodata pointers, function and variable imports, and DLL exports are now
independently verified too. The contract fixes canonical addends, zero
placeholders, and PE `DIR64` ownership while leaving final post-merge range
checks to the adapter. Function-relative debug lines, dense debug-parameter
ordinals, exact GC bitmap ownership, the x64 fixed-width prolog patch point,
and the current empty Windows x64 unwind contract are independently verified
as well. Nonempty unwind records are an explicit v1 unsupported error until
the codegen and adapter implement `.pdata`/`.xdata`; they are never silently
dropped. These layers only inspect serialized bytes and generate no machine
code. The bridge now adds one deliberately narrow machine-code slice: a USER,
SUPPORT, or GLUE executable module containing one internal hidden Red/System
`void()` function, one block, and one operand-free `RETURN`. Red/System codegen
emits the x64 prolog/epilog bytes, an empty GC bitmap, and complete RSCG section,
symbol, function, frame, and module records. GLUE additionally owns the explicit
Windows process-termination import and relocation. Every other valid nonempty
RSIR still fails at SELECT. This path does not call
`machine-ir/verify-current`, consume frontend direct-code fragments, or invoke
the legacy emitter.
Standalone USER and SUPPORT objects validate each GC frame against its
explicit initialized-DATA slice without inventing runtime compatibility roles;
only an object containing the RUNTIME module requires exact coverage of
`***-ptr-bitmaps`. The merger must collect and remap standalone slices before
applying that final runtime-role check. This distinction is part of the wire
contract, not a codegen exception.
Lifecycle fields declare module-owned functions, while explicit calls in the
glue function remain the sole authority for execution order. RSDG preserves
primary/note producer order, binds every
record to one nonzero routine status, and represents source/function/instruction
context with explicit presence bits. These are protocol prerequisites only;
they do not invoke the legacy emitter or constitute a partial backend execution
path. The control verifier is independent of legacy
`machine-ir/verify-current`. These layers do not produce direct code bytes. The
first codegen slice described above is separate from these verifier layers: it
is the first component allowed to emit machine bytes, and only for the exact
one-function `void RETURN` shape. The first Red producer can serialize that
same exact shape, and compiler-core routes the bounded empty-function event to
it exclusively. Optimization and broader semantic/machine-code coverage remain
later work.

`compiler/backend-feature-spec.red` is the executable Phase 1 feature matrix.
Its test reads `system/tests/run-all.r` as data and rejects any unclassified
Windows x64 unit file. It also requires every schema record and enum value to be
owned by a feature. A `specified` feature means only that its wire contract is
ready for independent verifier work; a `blocked` feature names the missing
contract explicitly and cannot be counted as backend support.

## Phase 1: protocol and semantic coverage

Deliverables:

- finish `docs/compiler-wire-format.md` from the ownership matrix;
- enumerate stable numeric IDs for message sections, types, opcodes, effects,
  calling conventions, relocations, diagnostics, and flags;
- keep one declarative schema manifest, generate checked-in Red and Red/System
  constants, and calculate a schema fingerprint;
- build a feature matrix from `system/tests` covering scalar operations,
  control flow, casts, pointers, structs/unions/arrays, function pointers,
  namespaces, callbacks, imports/exports, variadic/typed/custom calls, atomics,
  catch/throw, dynamic stack operations, GC handles, debug, PIC, and static
linking, plus target-bound `#inline`, port I/O, push/pop-all, and subroutines;
- specify exact mappings for all Win64 relocation forms accepted by the current
  PE linker.

Tests:

- schema-layout tests assert every record size and field offset in both
  languages;
- golden containers cover the smallest valid RSIR/RSCF/RSCG/RSDG messages;
- independent Red and Red/System RSCF verifiers agree on target/config domains,
  feature masks, arena limits, flag consistency, errors, and byte locations;
- independent data-layout verifiers freeze the Windows x64 header/layout tuple
  for both RSIR and RSCG before type or ABI rules depend on it;
- independent diagnostic verifiers agree on status/phase domains, primary and
  follow-up ordering, message validity, context presence, errors, and byte
  locations without requiring a trusted RSIR graph;
- independent type/layout verifiers agree on canonical type domains, kind-
  specific detail fields, GC kinds, field ownership/order, and exact Windows x64
  aggregate layout without consulting emitter state;
- independent module-lifecycle verifiers agree on module/image domains,
  lifecycle reference bounds, glue shape, RSCG symbol provenance, and exact
  error locations without synthesizing startup calls;
- independent scalar-operation verifiers agree on deterministic value/operand
  ownership, type rules, checked results, handle boundaries, exact effects, and
  failure-atomic output views;
- independent memory/aggregate verifiers agree on address decomposition,
  storage compatibility, aliases, volatility, aggregate build/copy, explicit
  union tags, nested errors, and exact byte locations without emitting code;
- independent control-flow verifiers agree on block/edge ownership, terminator
  shape and edge order, switch constants, virtual roots, direct-value dominance,
  explicit merge slots, workspace failure, and failure-atomic output views;
- independent call/ABI verifiers agree on callee descriptor domains, logical
  argument slices, direct/import/indirect/syscall targets, variadic/typed/custom
  protocols, callback signatures, conservative call effects, and derived Win64
  aggregate/hidden-return rules without serializing physical ABI state;
- independent atomic verifiers agree on RMW operation IDs, legal load/store/
  RMW/CAS/fence orders, exact signed-i32 address/value/result shapes, old/new
  result modes, effects, aliases, and exact byte locations without emitting
  code;
- independent exception verifiers agree on laminar region membership, handler
  nesting, enter/leave boundaries, innermost-first exception edges, FILTER and
  FUNCTION catch-all semantics, throw/call placement, callback declarations,
  stack exclusions, nested errors, and exact byte locations without emitting
  code;
- independent subroutine verifiers agree on host ownership, ordered block
  membership, execution roots, ordinary-edge isolation, effective signatures,
  dedicated returns, descriptor-only calls, recursion rules, nested errors,
  and exact byte locations without emitting code;
- independent explicit-stack verifiers agree on instruction shapes, signed
  slot counts, exact/dynamic joins, save-region identity, custom-call
  consumption, host epilog ownership, subroutine return depth, caller-owned
  workspace, and failure-atomic views without emitting code;
- independent target-intrinsic verifiers agree on constant-data prefix/suffix
  ownership, target/ABI-bound fragments, conservative effects and Win64
  clobbers, typed port widths, current-PC and CPU-register shapes, sequential
  fragment use, syscall argument limits, nested errors, and failure-atomic
  views without decoding or emitting fragment bytes;
- malformed fixtures cover truncation, overlap, bad alignment, overflow,
  unknown required flags, invalid IDs, cyclic constants, bad CFG, type errors,
  and unsupported relocations.

Exit criteria:

- every feature in the Windows x64 Red/System suite has an encoding and owner;
- both language implementations agree on the schema fingerprint and golden
  bytes;
- no v1 record contains a Red value or optimizer-derived state.

## Phase 2: bridge substrate

Deliverables:

- implement a Red/System checked reader with `checked-add`, `checked-multiply`,
  bounded slice, little-endian load, ID lookup, and section lookup primitives;
- implement native arenas with explicit capacity limits, alignment, growth,
  allocation-failure propagation, and one cleanup path;
- implement a deterministic RSCG/RSDG writer and self-verifier;
- add the `codegen-module` routine with distinct-series checks and the no-GC
  pointer lifetime protocol;
- implement Red structural verifiers independently rather than sharing the
  producer's unchecked accessors.

Tests:

- the bridge preserves a valid no-code RSCG for an empty module and produces a
  real, self-verified RSCG for the exact one-function `void RETURN` slice;
- every valid nonempty module outside that exact slice fails at SELECT without
  committing an artifact;
- every malformed phase-1 fixture produces a stable status and bounded RSDG;
- aliased inputs/outputs and nonzero output heads are rejected;
- repeated calls under forced Red GC do not retain or corrupt series pointers;
- the release compiler imports only system DLLs, verified with `dumpbin`.

Exit criteria:

- the bridge runs in a Stage1-built release compiler without `libRedRT.dll`;
- all native allocations are released on every nonfatal path;
- artifact output is committed once and is empty on failure.

Bridge-substrate implementation status:

- `compiler/codegen-bridge.red` exposes the four-binary `routine!`, while
  `system/codegen/codegen-bridge.reds` owns validation, diagnostics, exact
  subset selection, native backend dispatch, and the single output commit;
- `wire-arena.reds` and `wire-writer.reds` provide bounded native allocation and
  deterministic RSCG/RSDG construction; every completed output is independently
  self-verified before it can cross the routine boundary;
- `wire-rsir.reds` performs the shared decode once and applies target, atomic,
  and memory/aggregate checks over unpublished verified views. External views
  are copied only after all layers succeed;
- an empty USER or SUPPORT module retains the no-code result. The first native
  slice accepts exactly one internal hidden `void()` function with one block and
  one `RETURN`; `x64-encoder.reds` emits 17 fixed bytes and
  `x64-o0-codegen.reds` constructs and self-verifies its complete RSCG;
- `wire-codegen-strings.reds` merges `.data` and `.text` into the verified input
  string table with two allocation-free scans, preserving canonical order,
  deduplicating names, and explicitly remapping input IDs. Every other valid
  nonempty module returns `CODEGEN_FAILURE` at SELECT with no artifact;
- `generate-codegen-bridge-fixtures.red` first validates its RSIR, RSCG, and
  RSDG fixtures with the Red verifiers. Its compiled integration test pins exact
  bytes for both the empty and one-function RSCG outputs and covers decode/
  verify/target/select/encode failures, output bounds, disabled diagnostics,
  all six series-alias pairs, nonzero heads, atomic and memory/aggregate view
  errors, and repeated forced GC;
- the release integration executable imports system DLLs only. `dumpbin`
  reports no `libRedRT.dll` dependency even when that DLL is present beside the
  executable.

The comprehensive "every malformed Phase 1 fixture through the routine"
matrix remains open. Packaging verification also remains open for the
canonical `red-bootstrap-stage1-x64-gc-fixed.exe`: that older executable rejects
the current runtime's scalar `alias integer!` declarations before reaching the
bridge. The current optimized bootstrap compiles and runs the release
integration test; the canonical Stage1 binary must be rebuilt or advanced
before this Phase 2 exit condition can be claimed.

## Phase 3: complete RSIR frontend

Current implementation seed: `compiler/wire-writer.red` mirrors the bounded,
monotonic section state machine used by the native writer, and
`compiler/rsir-producer.red` serializes the exact supported anonymous or named
USER/SUPPORT/GLUE executable module into an exactly measured binary. It stages only
the canonical string slices/data, writes every required section and flag, and
returns no partial binary on failure. Its output is byte-identical to the
independently constructed fixture and succeeds through the compiled routine.
`compiler/rsir-sink.red` now receives the first function-declaration semantic
event from `compiler-core`, accepts exactly one empty `void()` function, and
publishes the complete binary through `system-dialect/last-rsir`. Compiler entry
validation restricts this slice to one Windows x64 Win64 executable module,
O0/O1, no runtime, no debug, and no Red-generated input. No-link jobs publish
RSIR only; linked jobs require the installed hybrid package and cannot fall
back to the emitter. Unsupported options, root forms, signatures, bodies, and
extra functions fail before the legacy emitter can run. The next Phase 3
boundary is expanding the sink's semantic table and instruction coverage.

Deliverables:

- expand the backend-neutral semantic sink in `compiler-core`; remaining direct
  emitter calls are routed through explicit operations with typed inputs;
- build module/type/signature/symbol/constant/import/export tables before body
  serialization and assign stable IDs;
- lower function bodies into typed CFG with explicit memory effects,
  single-definition expression temporaries, mutable locals/merge slots,
  explicit stack operations, calls, and source locations;
- serialize directly into pre-sized binaries instead of constructing a second
  tree of Red blocks;
- never start or read `machine-ir.red` during an `rsir` compile; differential
  evidence uses separate legacy runs and never consumes direct byte chunks;
- retain only the two mutually exclusive `legacy` and `rsir` backend modes.

Recommended slice order:

1. module metadata, scalar types/constants/globals, straight-line integer code;
2. locals, merge slots, loads/stores, comparisons, branches, and loops;
3. direct/indirect calls and all Win64 scalar argument/return cases;
4. pointers, field paths, arrays, aggregates and aggregate returns;
5. dynamic stack, variadic/typed/custom calls and callbacks;
6. atomics, exceptions, managed handles, debug, imports and exports;
7. runtime-specific global prolog/epilog semantics.

Tests and exit criteria:

- each slice adds positive, negative, and malformed semantic fixtures before
  moving to the next;
- `rsir` mode produces deterministic, semantically valid RSIR for the entire
  Windows x64 system suite without also running `legacy`;
- RSIR creation has no reads from emitter addresses, stacks, chunks, bitmaps,
  or symbol reference blocks;
- legacy mode remains behaviorally unchanged.

## Phase 4: Red/System internal MIR and verifier

Deliverables:

- decode immutable RSIR tables zero-copy where possible and build only derived
  indexes in arenas;
- construct predecessor lists, dominance, scalar use lists, memory SSA, stack
  state, safepoint candidates, and liveness in Red/System;
- promote eligible locals/merge slots and construct scalar SSA and phi nodes in
  Red/System before optimization;
- define a compact internal MIR that may change without wire-version changes;
- implement pass manager accounting: verification after every mutating pass,
  instruction counts, arena bytes, and per-pass time;
- start with canonicalization, unreachable removal, trivial phi elimination,
  constant folding, copy propagation, and dead-code elimination.

Exit criteria:

- unoptimized MIR round-trips to a stable textual dump for focused fixtures;
- verifier rejects every invalid semantic relation before instruction selection;
- optimization can be disabled completely and never changes diagnostics from
  the frontend.

## Phase 5: Windows x64 O0 codegen

Deliverables:

- Win64 instruction selection and encoding with no legacy target/emitter calls;
- ABI classification from RSIR signatures, including hidden aggregate returns,
  shadow space, alignment, callbacks, function pointers, and imported variables;
- linear-scan or simpler correct-first allocation, callee-save handling, spill
  slots, outgoing-call area, dynamic stack checks, and prolog/epilog generation;
- final GC frame bitmap generation from arguments, locals, and allocated spill
  roots, with the runtime compatibility symbol and patches;
- RSCG symbols, typed relocations, imports, exports, function extents, debug
  lines/parameters, and optional platform sections;
- conservatively lower target-bound `#inline` fragments by spilling live values,
  applying their opaque effect/clobber contract, emitting bytes, and importing
  an optional conventional result;
- lower typed port I/O, current-PC capture, CPU-register access, syscalls, and
  explicit stack-address operations from verified semantic instructions; none
  may import a frontend-selected instruction sequence.

Tests:

- instruction encoder unit vectors check exact bytes and displacement bounds;
- ABI probes cover 0-N integer/XMM arguments, mixed arguments, nested calls,
  small/large structs, callbacks, variadic/typed/custom calls, and return modes;
- GC probes force collection with live handles in arguments, locals, callee-save
  registers, and spills;
- atomic and overflow edge cases run in both legacy and rsir modes.

Current implementation slice:

- `x64-encoder.reds` transactionally emits the exact empty-`void` function
  bytes, including a fixed-width GC bitmap patch point, and rolls its arena back
  on bounded-output failure;
- `x64-o0-codegen.reds` performs exact semantic selection, canonical string-ID
  remapping, RSCG construction, and full native metadata self-verification;
- this is a vertical protocol/codegen proof, not Phase 5 completion. It has no
  operands, general calls, register allocation, exports, debug records, or
  general relocation/import lowering. Its sole call-shaped operation is the
  target-owned GLUE termination import, and unsupported inputs never fall back.

Exit criteria:

- focused probes execute identically in legacy and rsir modes;
- RSCG self-verifies without consulting frontend objects;
- no selected function contains copied legacy prolog, body, epilog, or bitmap
  bytes.

## Phase 6: RSCG merger and linker adapter

Deliverables:

- deterministic alignment and merge of multiple code, rodata, data, BSS, and
  platform sections;
- collect standalone GC bitmap slices into the runtime-owned bitmap role,
  rewrite each frame's section/offset, and verify final exact coverage;
- local-ID remapping, strong/weak/undefined symbol resolution, import merging,
  export conflict checking, and relocation source adjustment;
- exact conversion of RSCG relocations to current linker symbol/import reference
  structures for the first implementation;
- extend `job/debug-info` to carry complete function records and argument type
  bytes, removing the linker's dependency on `compiler/functions`;
- retain existing PE resource and external static-object processing.

Tests:

- single- and multi-object fixtures reference code/data/rodata in both
  directions and through imports;
- zero-based RSCG offsets are checked against the linker's one-based legacy
  convention;
- import functions, import variables, renamed exports, duplicate symbols, PIC,
  and data/rodata base relocations have focused tests;
- linked output is inspected with `dumpbin` and then executed.

Current implementation slice:

- `compiler/rscf-producer.red` now derives a deterministic, bounded RSCF
  message from the compiler job. It accepts only the Win64 O0/O1, non-debug,
  non-PIC configuration that the current native codegen and adapter honor;
- `compiler/hybrid-driver.red` fails closed unless a package installs both
  codegen and adapter hooks. It validates RSDG, enforces success/failure output
  atomicity, and exposes the last RSCF/RSCG/RSDG state without mutating the
  linker job during codegen;
- `system/compiler-windows-hybrid-bootstrap.red` is the current integration
  binding for the Red/System routine and Red adapter. `compiler-rsir-core` calls
  codegen, adapter, and linker exactly once for an RSIR link job and publishes
  the same four-field result shape as the legacy path. The Windows hybrid core
  shares loader, job, PE, and linker modules with the existing compiler, while
  its recursive source closure excludes the legacy compiler core and both
  legacy backend implementations;
- `compiler/rscg-linker-adapter.red` accepts one fully verified Windows x64
  GLUE object with `.text`, `.data`, one entry function, one GC bitmap, and one
  `kernel32.dll!ExitProcess` IAT relocation;
- canonical RSCG symbol ordering may place the entry or import first. Codegen
  remaps every function, lifecycle, relocation, and import reference, and the
  adapter follows those IDs rather than assuming ordinal 1;
- the adapter copies section buffers, patches the verified bitmap immediate,
  converts relocation offset 23 to the legacy one-based callsite 24, and
  commits no job mutation until all checks succeed;
- the PE writer omits empty import/base-relocation sections before layout and
  advertises relocation directories and ASLR flags only when a relocation
  section exists. The linked slice has one real import/IAT and no empty
  `.reloc`; `pe-empty-sections-test.red` covers the fully empty import/IAT/
  relocation case;
- `rscg-linker-adapter-integration.red` reads only serialized RSCG in a fresh
  process, links it with the existing PE writer, and requires the resulting
  executable to terminate with status 0. The RSIR-core driver integration
  asserts that emitter/machine-IR objects do not exist, counts one codegen,
  adapter, and linker invocation, executes the result, and removes it. Rebuilding
  the integration image with the legacy backend remains a correctness probe,
  not a performance gate. Multi-object merge, other relocation kinds, and
  general imports/exports/debug remain Phase 6 work.

Exit criteria:

- an RSCG object saved to disk and loaded in a fresh compiler process links
  without any semantic frontend state;
- every relocation is either applied/mapped exactly once or produces a hard
  diagnostic;
- hello and the covered system-test slice link and run in `rsir` mode.

## Phase 7: full O1 semantic parity

Deliverables:

- complete all remaining Windows x64 language and runtime operations;
- port only mature, profitable optimization logic into Red/System after O0 is
  stable; the experimental Red O2 implementation remains an oracle, not a
  dependency;
- support executable, DLL, no-runtime, debug, PIC, and existing static-link
  combinations used by the suite;
- make unsupported RSIR impossible for covered target/options rather than
  adding fallback.

Exit criteria:

- `run-all-tests-x64.r --binary <hybrid-compiler> --batch` exits zero, including
  all target-applicable Red/System and Red suites and every native subphase;
- the Red compiler and its generated runtime sources compile in `rsir` mode;
- debug stack traces, GC stress, imports/exports, and callbacks pass repeated
  runs;
- legacy and rsir compile-error behavior agrees at the frontend boundary.

## Phase 8: precompiled static runtime RSCG

Deliverables:

- build the runtime as one or more relocatable RSCG objects during compiler
  bootstrap, using the same codegen and verifier as user modules;
- generate a versioned, declarative frontend interface manifest containing the
  runtime type/function/global/alias/namespace/enumeration/managed-handle and
  preprocessor-definition environment needed to analyze user code;
- embed the verified bytes in the release compiler or package them as a
  version-locked resource selected by the full cache key;
- replace the current open global-code frame with explicit runtime-init,
  user-init, finalizer, and startup-glue functions; the glue RSIR module owns the
  final executable or runtime-enabled DLL entry symbol and preserves
  initialization order;
- keep program-specific Redbin boot payload and `red/sys-global` code/data in a
  generated user or glue object, outside the shared runtime cache;
- merge runtime and user objects at compile time and preserve all runtime magic
  symbols, startup ordering, GC bitmaps, and image-info patches;
- keep an explicit diagnostic path for cache mismatch; rebuilding through RSIR
  is allowed, falling back to emitter is not.

Exit criteria:

- release `hello.red` does not load or semantically compile runtime Red/System
  sources during the measured invocation;
- importing the cached frontend interface produces the same semantic tables and
  preprocessor behavior as processing runtime sources, checked by a normalized
  manifest comparison;
- the produced executable remains self-contained and has no `libRedRT.dll`
  import;
- cached and freshly generated runtime objects produce equivalent test results;
- corrupt or mismatched embedded objects are rejected before linking.

Bootstrap packaging sequence:

1. the existing compiler performs only its Red frontend pass for the hybrid
   compiler and saves the generated Red/System source plus Redbin payload;
2. the standalone hybrid Red/System path consumes that saved frontend result,
   emits RSIR, invokes native codegen, and links the first hybrid-only candidate;
3. the candidate generates and verifies the target runtime RSCG plus frontend
   interface manifest as an external bundle;
4. the candidate builds the next hybrid generation with that exact bundle,
   recording its content and configuration fingerprints;
5. the existing-compiler-seeded route and the hybrid-to-hybrid route are timed
   independently, and neither may execute the legacy emitter native phase;
6. bundle/schema fingerprints and the complete test matrix must stabilize
   across two hybrid generations.

This sequence uses no Stage0/Rebol compiler. Keeping the bundle external until
step 3 makes failures inspectable and avoids hiding a circular build dependency.

The saved frontend boundary is a four-file artifact set: `<name>.reds`,
`<name>.reds.redbin`, `<name>.reds.resources.red`, and
`<name>.reds.manifest.red`. Manifest version 2 binds the original source,
generated Red/System, Redbin, resources, target, and the sorted SHA-256 records
of every frontend-expanded `#script` dependency recovered structurally from
the generated source. `--loaded-red` verifies the complete set before the
Red/System loader runs. A compiler containing the new frontend writes all four
files directly; a pre-existing `--red-only` compiler can be followed by
`tools/self_hosting/seal-saved-frontend.red` without invoking a native backend.

The first Windows x64 development seed confirms this boundary reaches the
independent compiler core: the existing compiler's frontend-only pass took
25.826 seconds, sealing took 1.191 seconds, and the standalone seed loaded that
set before hard-failing in 0.651 seconds at the intentionally unsupported
Red/System runtime lifecycle. Its one-time legacy AOT build took 126.6 seconds
and is diagnostic bootstrap cost, not a result accepted by either fast-build
gate.

## Phase 9: bootstrap, performance gates, and default switch

Benchmark protocol:

1. Build each candidate through both compiler-build routes:

   ```powershell
   <existing-compiler> --red-only -t Windows-X86-64 `
       -o <candidate.reds> <compiler-source>
   <hybrid-backend> --loaded-red <candidate.reds> `
       -o <candidate.exe> <compiler-source>

   <hybrid-N> -t Windows-X86-64 -o <hybrid-N+1.exe> <compiler-source>
   ```

   The first measurement includes both processes. A direct monolithic build by
   the legacy emitter is diagnostic-only and cannot satisfy this gate.
2. Audit the hybrid source/include closure, then verify executable dependencies
   with `dumpbin /dependents`.
3. Warm once, then run at least five isolated `hello.red` release compilations
   at the same optimization level; report median and range, not the best run.
4. Record loader, RSIR serialization, routine decode/verify, each MIR pass,
   selection/allocation/encode, merge/adapter, linker, wall time, peak memory,
   IR size, RSCG size, allocation count, and cached-interface import time.
5. Repeat on a call-heavy Red/System fixture, the runtime module, the system
   suite aggregate, and both full compiler-build routes.
6. Run the repository's complete Windows-applicable Red/System unit/compiler/
   static-link suites and Red compiled/interpreted/core/regression/View/ABI,
   development, release, and DLL suites. Platform-inapplicable cases must be
   enumerated; feature-based omissions are failures, not exclusions.

Proposed default-switch gates:

- zero Windows x64 test regressions and zero silent fallbacks;
- zero legacy emitter or machine-IR files in the hybrid development package
  closure, and zero legacy native-backend phases in either compiler-build route;
- Red frontend plus RSIR serialization no more than 10% slower than the
  corresponding legacy semantic phase;
- native decode/optimization/codegen at most 25% of the measured legacy backend
  time for the same module;
- cached-runtime `hello.red` median wall time at most 50% of the recorded release
  baseline, with peak memory no more than 1.5 times baseline;
- cached runtime-interface import at most 10% of the corresponding fresh runtime
  load/semantic time on the same compiler and machine;
- the existing compiler builds the hybrid compiler within the compiler-build
  budget, and hybrid generation N builds N+1 within its separate budget;
- two consecutive hybrid generations pass all Windows-applicable Red/System
  and Red suites, and schema/cache fingerprints are reproducible;
- release compiler and generated executables have the expected dependency set.

After the gates pass:

- switch Windows x64 default to `rsir`, retain `legacy` for one bounded audit
  period, and collect any mismatch as a release blocker;
- remove current O2 dual-work hooks first, then delete x64 emitter code only
  after searches and instrumentation prove it is unreachable;
- remove the legacy mode and compatibility adapter internals in separate commits
  once the typed linker path, if adopted, has equivalent coverage.

Other targets are subsequent projects. ARM64 is the next sensible backend, but
the RSIR protocol must not claim target independence until a second backend has
validated the abstractions.

## Test layers

| Layer | Main failure caught |
| --- | --- |
| schema/golden bytes | Red and Red/System ABI drift |
| malformed corpus | bounds, overflow, ID and verifier bugs |
| separate-run semantic differential | frontend omissions and wrong ownership |
| encoder vectors | machine-byte and relocation mistakes |
| ABI/GC probes | calling convention and live-root corruption |
| legacy differential execution | behavioral codegen regressions |
| object reload/merge | hidden frontend/linker coupling |
| complete Red/System and Red suites | language/runtime/GUI/linking integration |
| legacy-seeded compiler build | slow or circular first hybrid bootstrap |
| hybrid N -> N+1 build | compiler self-hosting instability and iteration speed |
| performance harness | optimization that only moves or duplicates work |

Byte-for-byte executable equality is useful where deterministic layout matches,
but it is not the primary correctness oracle. Section layout may legitimately
change. Runtime output, ABI probes, debug behavior, exported interfaces, and
relocation inspection are authoritative.

## Principal risks

| Risk | Control |
| --- | --- |
| frontend silently reads emitter state | ownership matrix, `rsir` poison stubs, fresh-process object reload |
| premature schema freeze | draft version until 100% Win64 feature coverage |
| Red series moves during routine | native arenas, pre-reserved output series, allocation-free tail commit |
| aggregate/callback ABI mismatch | table-driven classifier and exhaustive probes |
| GC roots lost in allocation | typed GC kinds, liveness verification, forced-GC tests |
| legacy linker drops a relocation | per-kind mapping tests and reject-by-default adapter |
| runtime cache becomes stale | complete cache key plus schema/build fingerprints |
| cached code lacks frontend state/startup context | interface manifest plus explicit lifecycle/glue functions |
| differential testing duplicates production work | run `legacy` and `rsir` as separate test processes; each production compile selects one mode |
| optimizer work obscures parity | O0 first, pass-by-pass verifier, O1 gates before O2 |
| bootstrap cycle breaks recovery | small commits, checked-in schema output, canonical Stage1 compiler |
| unused legacy code keeps rebuilds slow | source-closure audit, not merely runtime poison tests |

## Commit boundaries

Each phase is split into reviewable commits with its tests, and every major
completed task is committed as required by the repository workflow. Suggested
major boundaries are: protocol/fixtures, reader/arena, writer/diagnostics,
routine bridge, RSIR module tables, RSIR function CFG, MIR verifier, x64 scalar
encoder, x64 ABI/frame/GC, RSCG merger, linker adapter, full coverage, runtime
object cache, and default switch. The emitter deletion is never combined with
the default switch.
