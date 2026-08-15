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
coverage. The protocol remains unfrozen until the remaining Windows x64
feature blockers and message-level semantic fixtures satisfy the Phase 1 exit
criteria.

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

The end state contains no emitter fallback. A release executable remains
statically linked and has no new `libRedRT.dll` dependency.

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

Three driver modes are allowed during migration:

- `legacy`: current emitter only;
- `shadow`: legacy output plus RSIR construction and verification, used for
  differential evidence;
- `rsir`: RSIR -> Red/System codegen -> RSCG -> linker, with unsupported input a
  hard diagnostic and no emitter invocation.

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
code.
Lifecycle fields declare module-owned functions, while explicit calls in the
glue function remain the sole authority for execution order. RSDG preserves
primary/note producer order, binds every
record to one nonzero routine status, and represents source/function/instruction
context with explicit presence bits. These are protocol prerequisites only;
they do not invoke the legacy emitter or constitute a partial backend execution
path. The control verifier is independent of legacy
`machine-ir/verify-current`. These layers do not produce direct code bytes. The
Phase 2 smoke backend can produce only a self-verified no-code RSCG for an
otherwise empty module; frontend RSIR production and machine-code RSCG
generation remain later work.

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

- a bridge smoke backend consumes a minimal RSIR and returns a valid no-code
  RSCG containing the required module record;
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
  `system/codegen/codegen-bridge.reds` owns validation, diagnostics, the smoke
  backend, and the single output commit;
- `wire-arena.reds` and `wire-writer.reds` provide bounded native allocation and
  deterministic RSCG/RSDG construction; every completed output is independently
  self-verified before it can cross the routine boundary;
- `wire-rsir.reds` performs the shared decode once and applies target, atomic,
  and memory/aggregate checks over unpublished verified views. External views
  are copied only after all layers succeed;
- the smoke backend accepts only a semantically valid empty USER or SUPPORT
  module. Any valid nonempty module returns `CODEGEN_FAILURE` at SELECT and
  produces no artifact; this is not a partial machine-code backend;
- `generate-codegen-bridge-fixtures.red` first validates its RSIR, RSCG, and
  RSDG fixtures with the Red verifiers. Its compiled integration test pins exact
  output bytes and covers decode/verify/target/select/encode failures, output
  bounds, disabled diagnostics, all six series-alias pairs, nonzero heads,
  atomic and memory/aggregate view errors, and repeated forced GC;
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

Deliverables:

- introduce a backend-neutral semantic sink in `compiler-core`; direct emitter
  calls are routed through explicit operations with typed inputs;
- build module/type/signature/symbol/constant/import/export tables before body
  serialization and assign stable IDs;
- lower function bodies into typed CFG with explicit memory effects,
  single-definition expression temporaries, mutable locals/merge slots,
  explicit stack operations, calls, and source locations;
- serialize directly into pre-sized binaries instead of constructing a second
  tree of Red blocks;
- use current `machine-ir.red` only as a differential oracle for covered
  functions; do not serialize it and do not consume its direct byte chunks;
- add the three mutually exclusive backend modes.

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
- shadow mode produces deterministic, semantically valid RSIR for the entire
  Windows x64 system suite;
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

Exit criteria:

- focused probes execute identically in legacy and rsir modes;
- RSCG self-verifies without consulting frontend objects;
- no selected function contains copied legacy prolog, body, epilog, or bitmap
  bytes.

## Phase 6: RSCG merger and linker adapter

Deliverables:

- deterministic alignment and merge of multiple code, rodata, data, BSS, and
  platform sections;
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

- all Windows x64 Red/System compiler/unit/static-link tests pass in `rsir` mode;
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

1. the canonical Stage1 compiler builds a cacheless hybrid candidate;
2. that candidate generates and verifies the target runtime RSCG plus frontend
   interface manifest as an external bundle;
3. Stage1 or the candidate builds the packaged compiler with that exact bundle
   embedded, recording its content and configuration fingerprints;
4. the packaged compiler regenerates the bundle and builds the next packaged
   generation;
5. bundle/schema fingerprints and the full test matrix must stabilize across
   the two packaged generations.

This sequence uses no Stage0/Rebol compiler. Keeping the bundle external until
step 3 makes failures inspectable and avoids hiding a circular build dependency.

## Phase 9: bootstrap, performance gates, and default switch

Benchmark protocol:

1. Build each candidate release compiler with the canonical Stage1 command:

   ```powershell
   build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
       -t Windows-X86-64 -o <candidate> <compiler-source>
   ```

2. Verify compiler dependencies with `dumpbin /dependents`.
3. Warm once, then run at least five isolated `hello.red` release compilations
   at the same optimization level; report median and range, not the best run.
4. Record loader, RSIR serialization, routine decode/verify, each MIR pass,
   selection/allocation/encode, merge/adapter, linker, wall time, peak memory,
   IR size, RSCG size, allocation count, and cached-interface import time.
5. Repeat on a call-heavy Red/System fixture, the runtime module, the system
   suite aggregate, and a full compiler self-build.

Proposed default-switch gates:

- zero Windows x64 test regressions and zero silent fallbacks;
- Red frontend plus RSIR serialization no more than 10% slower than the
  corresponding legacy semantic phase;
- native decode/optimization/codegen at most 25% of the measured legacy backend
  time for the same module;
- cached-runtime `hello.red` median wall time at most 50% of the recorded release
  baseline, with peak memory no more than 1.5 times baseline;
- cached runtime-interface import at most 10% of the corresponding fresh runtime
  load/semantic time on the same compiler and machine;
- two consecutive compiler generations pass the same suites, and schema/cache
  fingerprints are reproducible;
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
| semantic shadow | frontend omissions and wrong ownership |
| encoder vectors | machine-byte and relocation mistakes |
| ABI/GC probes | calling convention and live-root corruption |
| legacy differential execution | behavioral codegen regressions |
| object reload/merge | hidden frontend/linker coupling |
| system and Red suites | language/runtime integration |
| two-generation bootstrap | compiler self-hosting instability |
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
| Red series moves during routine | native arenas, no-GC pointer window, one append |
| aggregate/callback ABI mismatch | table-driven classifier and exhaustive probes |
| GC roots lost in allocation | typed GC kinds, liveness verification, forced-GC tests |
| legacy linker drops a relocation | per-kind mapping tests and reject-by-default adapter |
| runtime cache becomes stale | complete cache key plus schema/build fingerprints |
| cached code lacks frontend state/startup context | interface manifest plus explicit lifecycle/glue functions |
| shadow mode distorts benchmarks | benchmark `legacy` and `rsir` separately; shadow is correctness-only |
| optimizer work obscures parity | O0 first, pass-by-pass verifier, O1 gates before O2 |
| bootstrap cycle breaks recovery | small commits, checked-in schema output, canonical Stage1 compiler |

## Commit boundaries

Each phase is split into reviewable commits with its tests, and every major
completed task is committed as required by the repository workflow. Suggested
major boundaries are: protocol/fixtures, reader/arena, writer/diagnostics,
routine bridge, RSIR module tables, RSIR function CFG, MIR verifier, x64 scalar
encoder, x64 ABI/frame/GC, RSCG merger, linker adapter, full coverage, runtime
object cache, and default switch. The emitter deletion is never combined with
the default switch.
