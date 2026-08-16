# Direct Hybrid Red/System Compiler Plan

Status: implementation in progress. The production path is now direct:

```text
Red/System source
    -> rs-compiler (Red)
    -> compact RSIR binary!
    -> codegen-module routine! (Red/System)
    -> compact native linker image binary!
    -> linker (Red)
    -> PE
```

There is no legacy emitter fallback, shadow compilation, `verify-current`,
direct-code field, event sink, producer/builder adapter, generic wire
container, RSCF/RSDG message, RSCG adapter, or runtime schema lookup in this
path.

## Goal

The product is one complete Windows x64 Red/Red/System compiler whose Red
closure is small enough that both of these operations are fast:

1. the designated existing compiler builds the complete hybrid compiler H0;
2. hybrid generation Hn builds the same complete source as Hn+1.

H0 is not a reduced bootstrap product. It becomes H0 only when it implements
the complete compiler behavior needed by the repository. The existing compiler
is used as the seed until that point, but no legacy backend source belongs to
the hybrid product closure.

The final correctness gate is the complete Red/System and Red test suite, not a
small machine-code fixture:

```powershell
rebcmdview.exe -s run-all-tests-x64.r --binary <hybrid-compiler.exe> --batch
```

## Current Foundation

The current narrow slice accepts source-ordered `() -> void`, `() -> i32`, and
`(i32) -> i32` functions. Scalar aliases such as `node-handle!: alias integer!`
resolve in lexical, path, and `with` scopes. An `i32` body can return a literal
or parameter, or directly call another supported function with zero arguments
or one literal/parameter argument. Glue modules use the last declared function
as their explicit entry ID; codegen still places that entry at code offset zero.
Function declarations may live in nested `context` blocks; short names,
explicit context paths, and `with` lookup scopes resolve to the same
`>`-decorated symbol style used by Red/System. This slice proves the
architecture and multi-function traversal; it does not define a smaller H0.
All current aliases and enums also receive source-order logical type IDs. Their
unmodified aggregate/function specs stay in frontend state until the native
consumer is implemented; target sizes and offsets are deliberately absent.

- `compiler/rsir-frontend.red` parses and writes RSIR directly.
- `compiler/codegen-bridge.red` contains only the `routine!` declaration.
- `system/codegen/codegen-bridge.reds` owns the Red series boundary.
- `system/codegen/x64-codegen.reds` reads RSIR and writes the linker image.
- `system/codegen/x64-encoder.reds` writes x64 bytes into the reserved output.
- `system/linker.red/load-codegen` loads the image directly into linker state.

For the current slice, empty-void and i32 RSIR are 50 and 66 bytes. A GLUE i32
native image is 196 bytes. Both the two-function `main -> helper -> 41` and
`main -> identity 42` samples are 122 RSIR bytes and produce 252-byte native
images. Their generated PEs exit with status 41 and 42 respectively. The
previous rebuilt H0 compiled and linked the zero-argument sample in 114.8 ms.

The designated existing compiler built the multi-function current hybrid entry
in 90.1 seconds: 14.9 seconds frontend, 63.8 seconds native compilation, and
11.0 seconds linking. The preceding wire/adapter entry took about 123.3 seconds:
22.2 seconds frontend and 95.4 seconds native compilation. The focused routine
smoke fell from roughly 43 seconds to roughly 7 seconds. These are development
samples on the same machine and compiler, not final performance gates, but they
show that deleting the layers reduced real compiler-build work.

For the current declaration-pass increment, regenerating the complete H0
Red/System corpus with `--red-only` took 16.53 seconds. The focused development
frontend-plus-routine smoke took 1.11 seconds in the Red frontend, 8.55 seconds
in native compilation, and 1.16 seconds in linking, producing an 801,792-byte
executable. Before folding two single-use Red helpers into their callers, the
same working tree took 13.35 seconds in native compilation and produced
806,912 bytes. This is why the direct frontend keeps helper functions only when
they represent reusable work.

The source-order logical-type checkpoint builds the same focused development
routine smoke in 12.05 seconds wall time and produces an 820,736-byte
executable. A discarded prototype that calculated Win64 aggregate layouts in
Red took 13.238 seconds and produced 915,456 bytes with the same command. It was
removed: target layout belongs in Red/System codegen, both for a
backend-independent IR and for a smaller, faster-to-build Red closure.

## Data Layout Rule

RSIR is a private in-process format compiled as one source set with its only
consumer. It is not a public object format. Consequently it has:

- no magic value or version negotiation;
- no named section directory;
- no canonical string-ID remapping;
- no generic reader/writer object;
- no repeated semantic verifier pipeline;
- no compatibility adapter.

The current RSIR is only the data that codegen consumes:

```text
4 words: module kind, entry function, function count, instruction count
4 words per function: name offset, name size, signature, instruction count
4 words per instruction: typed opcode, result, operand, immediate
raw function-name bytes
```

The input `binary!` length supplies the total size. Sequential instruction
ranges are derived by addition, so they are not repeated in function records.
The three currently implemented signatures are direct integer values; there is
no signature registry. A one-argument call stores its argument value ID in the
call instruction itself; there is no parameter or operand section. Function
IDs and value IDs are one-based where zero means absent. The routine performs
only the bounds and shape checks required for safe pointer traversal and then
casts these arrays directly.

The native linker image follows the same rule. Its current order is:

```text
header
function records
import records
reference offsets
name bytes
alignment padding
code bytes
alignment padding
data bytes
```

Function and import records own contiguous reference slices. This maps directly
to the existing linker's native symbol and import reference lists, so the Red
linker does not search all relocations for every symbol and does not construct
an intermediate object model.

Both layouts may change while frontend, codegen, and linker are rebuilt
together. A stable cache format is a later requirement and will be designed
from measured cache needs, not by turning the internal IR into a general wire
protocol.

## Style And Performance Rules

- Prefer source-order IDs. Determinism does not require lexical sorting.
- Use `hash!` for name lookup in Red; never use `select` on a long pair block in
  a hot symbol path.
- Write table bytes directly. A helper must remove real repeated work, not hide
  a constant or field offset behind another name.
- Cast verified table starts to Red/System record structs once, then advance
  pointers. Do not call a field reader for every scalar.
- Reserve the routine output once and write into it in place. Do not allocate a
  native artifact and copy it back into a Red series.
- Keep target layout, register allocation, frame layout, instruction selection,
  and encoding in Red/System.
- Keep parsing, semantic name resolution, and the final PE linker in Red only
  while that ownership remains smaller and clearer.
- Do not serialize derived MIR facts such as liveness, physical registers,
  frame offsets, branch widths, or spill slots.
- An unsupported construct is a hard compiler error. It never invokes the old
  emitter.

## Phase 1: Direct Boundary

Status: complete in `900d3d1f0`.

Deliverables:

- replace the generic RSIR container with header + tables + bytes;
- pass only `ir`, `artifact`, and `opt-level` through `routine!`;
- write native output directly into the reserved Red binary;
- make `linker/load-codegen` the direct consumer;
- remove schema, config/diagnostic messages, hybrid driver, and adapter from the
  recursive hybrid source closure;
- keep exact byte tests, bounded-output failure tests, and a real PE exit-code
  test.

Exit criteria:

- recursive closure audit finds none of the retired wire/adapter modules;
- the designated existing compiler builds the hybrid entry;
- that executable compiles and links the supported fixture;
- the generated PE executes with the expected status;
- compiler-build timing is recorded.

## Phase 2: Real Frontend Core

Status: current major task. Source-order function, import, and global IDs;
duplicate detection; retained specs and bodies; a separate lowering pass;
multi-function native traversal; zero/one-argument direct calls; scalar
aliases; source-order logical type records; context-qualified names; and `with`
resolution scopes are implemented. The declaration pass also scans loader
`#script` markers, enum constants, aggregate and function aliases, import
groups, and global assignments without serializing data that codegen does not
consume yet. Type/member serialization, native layouts, complete signatures,
initializers, and function bodies remain pending.

The implementation order is driven by the actual generated self-host source,
not isolated language examples. A fresh `--red-only` generation of the direct
hybrid source is 2,961,043 bytes. After includes and macros are expanded by the
real Red/System loader, the structured audit finds 530 defined functions, 62
contexts, 725 imported symbols, 73 aliases, 14 enums, 4,310 global assignments,
and 4,262 unique global names. Of the defined functions, 489 have one
parameter, 34 have none, and seven have two to five; the dominant parameter
type is `node-handle!`. Context depth is at most two, while functions have up
to 55 locals and substantial control flow. The direct declaration pass matches
all independently audited function, context, import, alias, and enum counts in
about 240 ms under the interpreter after loading, then fails explicitly at the
unimplemented global-code lowering boundary.

Regenerate and inspect this corpus without native compilation:

```powershell
red-bootstrap-ifphi-final-win64-o2-dev.exe --red-only -d -t Windows-X86-64 `
  -o build\self-hosting\compact-hybrid-direct-stream.reds red-bootstrap-windows-hybrid.red
D:\EE\QTool\red-console.exe tools\self_hosting\audit-rsir-corpus.red
```

### 2.1 Declarations And Stable IDs

Current checkpoint: declaration discovery traverses the complete current H0
corpus and assigns source-order type, function, import, and global IDs. Logical
type records retain kind, source spec, lexical scope, and `with` scopes without
target layout. Global source blocks and import records remain in Red frontend
state and are rejected before RSIR output until 2.2 and 2.3 define their
consumed representation.

- scan top-level declarations and contexts without creating an AST copy;
- maintain qualified-name and local-scope `hash!` tables;
- assign source-order IDs to types, globals, imports, and functions;
- emit function records only after their signature is known;
- retain unresolved body slices until declarations are complete;
- detect duplicates at insertion time.

Gate: the frontend emits every declaration in the complete H0 source and can
resolve every referenced name, while bodies may still fail as unsupported.

### 2.2 Types And Layout

- write only logical type/member records that native codegen consumes, directly
  into the compact RSIR order; do not add a schema, section directory, or
  frontend layout table;
- base scalar, pointer, function-pointer, alias, enum, struct, union, and array
  representations;
- forward pointer references and by-value dependency ordering;
- Windows x64 size/alignment/member offsets computed in Red/System codegen;
- logical function signatures, callbacks, variadic imports, and return types;
- GC kind attached to semantic types, not stack slots.

Gate: layout results match the existing compiler across the complete applicable
type/layout suite, without importing the emitter datatype table or calculating
target layout in Red.

### 2.3 Imports, Globals, And Constants

- preserve `#import` library grouping and calling convention;
- emit imported functions and variables directly;
- lower scalar, string, aggregate, address, and zero initializers;
- represent symbolic addresses as target-independent references;
- assign all data ownership before function codegen.

Gate: import/global/constant fixtures and the corresponding Red/System suite
families pass through the new path.

### 2.4 Functions And Scopes

- parameters, locals, nested contexts, namespace paths, aliases, and function
  variables;
- direct and indirect calls with logical argument lists;
- explicit result values and mutable local slots;
- source locations only where required by diagnostics or debug output.

Gate: every function in the complete H0 source lowers to typed RSIR with no
emitter state and no source construct silently omitted.

### 2.5 Control Flow And Effects

- blocks for conditionals, `case`, `switch`, loops, break/continue, and return;
- explicit targets in terminators; predecessor lists are derived natively;
- load/store/address operations and conservative call effects;
- exceptions, subroutines, explicit stack operations, atomics, and target
  intrinsics in corpus-driven order.

Gate: complete RSIR construction for the H0 source, plus differential semantic
tests against separate runs of the existing compiler.

## Phase 3: Native Backend

### 3.1 Multi-function Traversal

- remove the one-function shape selector;
- traverse every function and its owned instruction range;
- place the executable entry at code offset zero while preserving function IDs;
- emit function records and name bytes once;
- group import references contiguously as expected by the linker image.

### 3.2 MIR And CFG

- build allocation-friendly native MIR from RSIR;
- derive predecessors, dominators, merge values, and liveness in Red/System;
- verify internal pass invariants with debug-only assertions, not a serialized
  protocol verifier;
- keep O0 straightforward and correct before adding optimization passes.

### 3.3 Win64 Calls And Frames

- scalar and aggregate argument classification;
- shadow space, alignment, hidden return buffers, callbacks, and variadics;
- callee-save handling, spills, GC root bitmaps, and unwind data;
- internal, imported, indirect, syscall, and runtime resolver calls.

### 3.4 Encoding And Optimization

- integer, floating-point, memory, aggregate, branch, and call encodings;
- branch relaxation after final block layout;
- O1 local simplification, constant folding, dead code, and slot promotion;
- O2 only after O0/O1 pass the complete suites; the retired legacy O2 path is
  not a migration dependency.

Gate: all Windows x64 Red/System tests pass with the old emitter absent from the
process.

## Phase 4: Runtime And Red Compilation

Native codegen alone cannot make release Red compilation fast if every command
reparses and recompiles the runtime. This phase adds:

- a relocatable prebuilt runtime image generated by the same native backend;
- a compact frontend interface containing only exported semantic state;
- cache keys covering compiler generation, target, ABI, build mode, and runtime
  source identity;
- direct merge of runtime and user linker images;
- explicit startup, initializer, finalizer, DLL, and callback ownership.

Fresh and cached paths must produce equivalent runtime behavior. A runtime DLL
may be measured as a development configuration, but it is not the release
correctness solution.

Gate: compiled and interpreted Red suites, release/development executables,
DLLs, View, ABI probes, and runtime GC tests pass.

## Phase 5: Bootstrap And Fixed Point

Let `S` be the one complete hybrid compiler source set.

1. Existing compiler builds `S` -> H0.
2. H0 builds `S` -> H1.
3. H1 builds `S` -> H2.
4. H1 and H2 pass all suites.
5. Compare deterministic compiler-owned artifacts and explain any executable
   differences caused by timestamps or linker metadata.
6. Measure old -> H0 and H1 -> H2 separately.

There is no separate minimal bootstrap source. If old -> H0 is too slow, reduce
the Red ownership in `S` or move another complete responsibility to Red/System;
do not omit product behavior.

## Verification

Fast tests run on every semantic increment:

- interpreted Red frontend byte tests;
- direct Red/System encoder/codegen tests;
- malformed length/range tests at the routine boundary;
- direct linker image loading and actual PE execution;
- recursive source-closure audit;
- focused language-family differential tests.

Broader tests run at milestones:

- complete applicable Red/System compiler and unit suites;
- complete compiled/interpreted Red suites;
- release, development, DLL, View, ABI, and GC configurations;
- old -> H0 and Hn -> Hn+1 builds;
- five-run warm performance samples with median and range.

Record frontend time, native time, linker time, wall time, generated Red/System
bytes, executable size, peak memory, RSIR bytes, native-image bytes, and cache
state. A change that merely moves work between phases is not a speedup.

## Commit Boundaries

Use small recoverable commits after each completed responsibility:

1. direct compact boundary and linker path;
2. multi-function declarations and traversal;
3. types and layouts;
4. imports/globals/constants;
5. locals/calls;
6. CFG and control flow;
7. Win64 ABI/frame/GC;
8. full x64 instruction coverage;
9. runtime image/cache;
10. H0/H1/H2 and suite closure.

Each commit includes the narrowest meaningful tests and must keep the hybrid
source closure free of the legacy emitter, machine IR, and retired wire path.
