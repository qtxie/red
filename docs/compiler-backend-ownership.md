# Compiler Backend Ownership Audit

Status: executable migration audit. The dependency families below are backed by
`compiler/backend-ownership-spec.red`. Its structural source test currently
classifies all 145 emitter APIs and all 302 executable references in
`system/compiler-core.red`; any added, removed, or unclassified reference fails
the test. The remaining emitter, target, and linker implementation audit still
controls whether the RSIR schema may freeze.

See [the wire protocol](compiler-wire-format.md) and
[the execution plan](hybrid-codegen-plan.md) for the resulting contracts.

## Why this audit exists

The current compiler does not have a clean frontend/backend boundary. Semantic
analysis asks emitter and target objects for type layout, argument placement,
temporary register state, stack offsets, and symbol addresses while it emits
bytes. The experimental machine IR records part of the same work in parallel and
then uses the direct byte chunk for prolog, GC, layout, debug, and fallback.

The migration is complete only when `rsir` mode can poison all emitter buffers
and target emit functions and still compile. Merely wrapping existing calls or
serializing `machine-ir.red` would preserve the coupling.

Run the coverage gate without compiling a test executable:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\backend-ownership-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\tests\backend-feature-test.red
```

The manifest records a replacement contract and an expected occurrence count
for every normalized emitter path. Counting occurrences matters: adding another
use of an already-known API is new coupling and must not pass unnoticed. Red
loads the source as data before the recursive scan, so comments and strings are
not counted, while ordinary, get, set, and lit paths share one canonical key.

The separate feature gate loads `system/tests/run-all.r` without executing it,
classifies every Windows x64 unit file through
`compiler/backend-feature-spec.red`, and proves that every wire enum value and
record belongs to at least one feature. `blocked` is deliberate audit state, not
an implementation fallback: each blocked entry carries the exact schema or
ownership decision required before it can become `specified`.

## Dependency families

| Current dependency | Current use | New owner/representation | Required proof |
| --- | --- | --- | --- |
| `emitter/datatypes`, `datatype-ID` | base-type tests and runtime debug type IDs | frontend type registry; parameter debug code in RSIR/RSCG | all types map without emitter object |
| `ptr-size`, `stack-width`, default/struct alignment | pointer typing, layout, slot calculations | pure Red target-layout module; sizes serialized and recomputed by codegen | frontend/codegen layout hashes agree |
| `size-of?`, struct/union size/slots, `member-offset?` | paths, literals, aggregate validation | pure type-layout service plus RSIR type/field records | exhaustive aggregate layout fixtures |
| SysV aggregate classes and Win64 call slot fields | frontend rewrites physical arguments | removed from frontend; logical call/signature records | ABI classifier probes in codegen |
| `store`, `store-value`, protected store, data/rodata buffers | global/literal materialization | RSIR constants/globals; RSCG output sections | nested/address initializer fixtures |
| emitter symbols and `add-native` | definitions, addresses, code/data refs | RSIR symbols; RSCG symbols/relocations | object reload links with no compiler state |
| emitter import/import-var reference blocks | import callsite patching | RSIR/RSCG imports plus typed relocations | function and variable import probes |
| chunks, merge, branch/over/back, jump lists | control-flow construction and patching | RSIR blocks/edges/terminators | CFG verifier and differential control tests |
| loads, stores, casts, arithmetic, paths | instruction encoding during semantic walk | typed RSIR operations and values | no target emit call in rsir semantic path |
| save/restore last, signed state, last math state | implicit register-stack-machine state | absent from RSIR; native MIR scheduling/allocation | poison legacy state during rsir tests |
| call argument index/types/pad/shadow/temp fields | target ABI state while evaluating calls | callee descriptor plus logical arguments; codegen ABI classifier | nested/mixed/aggregate call matrix |
| `enter`, `leave`, prolog/epilog, emitter stack | frame layout and function bytes | signatures/locals in RSIR; frame/encoding in codegen | frame and unwind/stack alignment probes |
| pointer bitmap encode/store and bitmap buffer | GC argument/local frame description | GC kinds in RSIR; final bitmap after allocation in codegen | forced GC with spills/callee-saves |
| tail pointer in debug records | source line to current code address | source location on RSIR instruction; final offset in RSCG | debug line/function tests |
| `reloc-native-calls`, native-ref duplicate symbols | final internal references | typed RSCG relocations; adapter mapping | each relocation applied exactly once |
| global prolog/epilog and `last-red-frame` | root frame spans runtime and user global code | explicit module init/fini plus generated startup glue | release exe/DLL startup equivalence |
| target `on-finalize` | literal pools and target cleanup | codegen module finalization | empty/nonempty pool and range tests |
| runtime `compiler/functions`, aliases, globals, definitions | seeds user semantic/preprocessor environment | cached frontend interface manifest | normalized cached/fresh state equality |
| linker debug lookup of `compiler/functions` | arity and argument type arrays | complete RSCG debug parameters in `job/debug-info` | fresh-process RSCG link with debug |
| linker magic runtime symbols | image info and GC bitmap patches | ordinary named RSCG symbols with required-role validation | missing/duplicate role diagnostics |

## Structured semantic operations

These current target calls become ordinary backend-neutral RSIR operations or
control records:

- integer and floating arithmetic, comparison, conversion, bitcast, overflow,
  and boolean materialization;
- local/global/indirect loads and stores, addresses, pointer arithmetic, field
  access, explicit union tag loads, and variant updates;
- direct, indirect, imported, syscall, callback, variadic, typed, custom, and
  runtime resolver calls;
- if/either/case/switch, loops, break/continue, return/exit, throw/catch, and
  unreachable continuations;
- stack allocate/free, stack push/pop, explicit stack align regions, and
  subroutine calls/returns;
- atomics with operation, ordering, old/new result behavior, and effect flags;
- keepalive, runtime error PC capture, port I/O, and aggregate copy/build/return.

The frontend emits logical values and mutable slots. It does not decide register
locations, shadow space, aggregate register classes, spill slots, jump widths,
or instruction encodings.

Control-flow ownership follows the same boundary. The frontend chooses semantic
blocks, ordered branch/switch targets, and explicit mutable or merge locals.
RSIR owns those blocks, edges, and terminators. The independent CFG verifiers
check edge partitioning, terminator correspondence, virtual unreachable roots,
and direct-value dominance without consulting `machine-ir/verify-current` or
emitter patch lists. Predecessor arrays, dominator trees, phi construction, and
merge-slot promotion are derived later inside native MIR and are never
serialized or copied from the legacy optimizer.

Address paths have one backend-neutral form: scalar `ADD` performs pointer
indexing, each member step is `ADDRESS_FIELD`, and indirect loads/stores carry no
fused displacement. Tagged-union activation is an explicit operation rather
than an `ADDRESS_FIELD` side effect. Aggregate copy has overlap-safe `memmove`
semantics and carries no frontend size, frame, or ABI hint. These choices keep
target folding and placement in codegen without serializing direct code.

## Target-bound escape operations

Some Red/System constructs are inherently machine-specific and must be explicit
rather than mislabeled as portable:

| Construct | RSIR treatment | Conservative codegen rule |
| --- | --- | --- |
| `#inline` binary | ordered target-fragment record plus instruction | exact target/ABI and source match; spill live values; opaque read/write/trap/control barrier; Win64 volatile clobbers; unchanged stack |
| `system/io/read` and `write` | typed port-I/O operations | Windows x64 accepts byte and signed-i32 widths; unsupported shapes are diagnostics |
| `system/stack/push-all` and `pop-all` | paired opaque stack operations | verify pairing/state; prevent motion across region |
| stack top/frame address | explicit stack-address operations | return `pointer! [integer!]`; codegen derives RSP/RBP after final frame layout |
| get current PC | semantic intrinsic returning `pointer! [byte!]` | codegen emits target sequence/relocation |
| x64 CPU-register access | register-ID subopcode plus pointer-shaped value | reads allow RAX through R15; writes reject RSP/RBP so stack state stays codegen-owned |
| syscall number | syscall call kind | nonnegative signed-i32 number; zero through six Win64 logical arguments |

Current `#inline` syntax supplies only bytes and an optional return type. It has
no declared clobber or memory effect. Version 1 must therefore use the full
conservative contract above. Optimization may narrow it only after the language
gains explicit declarations; decoding arbitrary bytes is not a verifier.
Clobber ID `WIN64_VOLATILE` means RAX, RCX, RDX, R8-R11, XMM0-XMM5, and
arithmetic condition codes; all nonvolatile registers and the entry RSP value
must be preserved.

The constant initializer owns a gap-free prefix of `constant-data`; ordered
target-fragment records own the complete remaining suffix. Each nonempty slice
is referenced exactly once, in record order, by a `TARGET_FRAGMENT`
instruction. The descriptor and instruction agree on source and optional
scalar/pointer/function result type. Validation never copies these bytes into a
code buffer; only Phase 5 codegen may emit a verified fragment.

## Global lifecycle and runtime caching

The current release flow is stateful:

1. runtime startup opens the global/root frame;
2. runtime sources populate compiler and preprocessor state;
3. generated/user global code is appended inside that frame;
4. runtime epilog closes the frame and creates the final entry behavior.

A cached runtime machine-code blob cannot leave a frame open for later bytes,
and it cannot seed frontend semantic state. The replacement is:

1. bootstrap generates a declarative frontend interface manifest;
2. bootstrap codegens runtime lifecycle functions into relocatable RSCG;
3. a compile imports the manifest, then builds user RSIR with runtime symbols as
   external definitions owned by the runtime object;
4. user global code becomes a user initializer function;
5. a small glue RSIR module calls runtime and user lifecycle functions in stable
   priority order and defines the final entry symbol;
6. the RSCG merger resolves all cross-module calls and data references.

Program-specific Redbin boot payload and `red/sys-global` output remain generated
user/glue inputs. Runtime cache identity includes a digest of output kind, GUI
and module selection, runtime/compiler flags, and every target preprocessor job
value that can affect loaded source.

Packaging is a two-stage self-host operation: canonical Stage1 first builds a
cacheless hybrid compiler, that compiler generates the external runtime bundle,
and a subsequent build embeds the verified bundle. The packaged compiler must
regenerate the same schema and bundle fingerprints in the next generation. No
Stage0/Rebol invocation is part of this path.

The interface manifest must cover at least loader/compiler definitions, function
specifications and attributes, globals, nominal/aliased types, enumerations,
namespaces/contexts, managed handle kinds, and any compile-time constants used
by later sources. It contains declarative values, never live Red bindings or
series nodes.

## Linker compatibility obligations

The initial RSCG adapter must reconstruct or replace every current encoding:

- function definitions use one-based legacy entry addresses, while RSCG is
  zero-based;
- a referenced function may require both `native` and `native-ref` legacy
  entries;
- x64 code references are PC-relative 32-bit patch positions;
- data and rodata pointer slots use a fourth symbol field, with negative values
  identifying rodata positions;
- import lists group external names and callsite blocks by library, and import
  variables use a distinct issue-like legacy form;
- debug function records need names, entry offsets, arity, and runtime argument
  type bytes;
- runtime image setup requires `***-ptr-bitmaps`, `***-exec-image`, and related
  named roles;
- resources and external C objects remain existing linker inputs outside RSCG.

Each mapping is reject-by-default and has a focused fixture. The adapter cannot
silently ignore an optional-looking record when it affects generated code.

## Freeze blockers

The schema cannot freeze until these questions have executable answers:

- root-frame lifecycle for exe, DLL, driver, no-runtime, Red pass, and PIC modes;
- full list of frontend state required by a cached runtime interface;
- aggregate layout and call classification agreement for every Win64 case;
- GC bitmap rules for hidden return slots, callbacks, dynamic stack, spills, and
  library-runtime frame flags;
- typed relocation mapping for code/data/rodata/import variables and magic
  runtime symbols;
- debug function and source-line behavior after multi-object merging.

Resolving a blocker means adding its representation, verifier rule, focused
fixture, and differential expected behavior. A prose-only assumption does not
close it.
