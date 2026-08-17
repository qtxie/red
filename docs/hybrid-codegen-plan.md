# Direct Hybrid Red/System Compiler Plan

Status: architecture reset in progress.

The stable outer path is:

    Red/System source
        -> rs-compiler (Red)
        -> typed RSIR binary!
        -> codegen-module routine! (Red/System)
        -> direct linker image binary!
        -> linker (Red)
        -> PE/COFF output

The current implementation proves that this boundary works, but its function
body IR and x64 selector are a narrow prototype. They are not the base on which
the rest of the language will be accumulated.

## Completion Rule

There is one complete hybrid compiler source set, S.

1. The designated existing compiler builds S into H0.
2. H0 builds the unchanged S into H1.
3. H1 builds the unchanged S into H2.
4. H1 and H2 pass the complete applicable Red/System and Red test suites.
5. H1 and H2 compiler-owned output is deterministic.
6. Existing-compiler-to-H0 and H1-to-H2 build times are measured separately.

An incomplete executable is a prototype, not H0. There is no reduced bootstrap
compiler that later acquires missing language features.

Both seed compilation and self-compilation are performance requirements. The
Red source closure must therefore stay small throughout development; it is not
work postponed until after feature completeness.

## Sources Of Truth

Design and completeness follow this order:

1. the implemented language described by
   docs/red-system/red-system-specs.txt;
2. the formal compiler and unit suites in system/tests/run-all.r;
3. the applicable Windows x64 ABI and COFF/static-link tests;
4. the complete compiler/runtime source corpus;
5. focused regression fixtures.

The specification and semantic dependency graph determine the architecture and
implementation batches. Formal suites define the acceptance surface. The
complete source corpus checks closure and timing, and may expose an omission,
but it does not define a new operation. A source identifier, a particular
argument position, or the shape of one initializer must never become an RSIR
operation or an x64 encoding form.

The Possible Evolutions section of the specification is not part of H0 unless
the repository already implements and consumes a listed feature.

The detailed mapping is maintained in
docs/red-system-feature-matrix.md.

## Non-Negotiable Shape

The production source closure has:

- no legacy emitter or machine-IR fallback;
- no shadow compilation or verify-current path;
- no direct-code escape field;
- no event sink, builder protocol, adapter, or middleware pipeline;
- no public wire format, schema registry, version negotiation, or runtime
  field lookup;
- no second Red backend representation between the frontend and routine!;
- no target sizes, offsets, registers, frames, or ABI classifications in
  RSIR.

Frontend, codegen, and linker are rebuilt together. RSIR is their private
in-process data layout and can change directly when its semantics change.

## Language-Shaped Core

The architecture follows Red/System semantics rather than C compiler
conventions.

### Left-To-Right Evaluation

Red/System has no normal operator precedence and evaluates expressions from
left to right. A typed postfix instruction stream represents that rule
directly:

- operands are emitted in source evaluation order;
- an operation consumes its operands from the typed value stack;
- parentheses recurse into the same emitter;
- an infix function is handled by the parser rule that gives it its specified
  precedence, then becomes an ordinary call;
- no expression tree or precedence-recovery pass is required.

The frontend therefore does not serialize an AST or SSA graph. Native codegen
creates only the derived value and control-flow facts needed for machine code.

### Values And Places

Every read or write is expressed with the same small set of concepts:

- a value is a typed scalar, pointer, function pointer, or aggregate value;
- a place is a typed addressable storage location;
- address identifies a local, global, import, constant, or function symbol;
- member and index transform an address;
- load turns a place into a value;
- set writes a value and leaves that value as the language assignment result;
- duplicate and drop express grouped assignments and unused results.

All variable words, paths, get-paths, members, imported variables, pointer
dereferences, and one-based indexes lower through this model. There are no
separate global-load, import-member, pointer-arg1, or similar operations.

Pointer and struct arithmetic carry logical pointee types. Codegen obtains the
target stride from native layout, so the frontend never embeds a Windows size.

For example, a casted call initializer has the semantic form:

    address global ts
    literal 1707
    call get-root
    cast red-typeset!
    set
    drop

Nothing in that sequence depends on the names get-root or ts.

### Structured Control

Branches use instruction indexes as direct targets. Basic blocks are derived
from entry points, branch targets, and terminators; no block directory is
serialized.

A branch consumes only its condition. Both successors retain the same common
stack prefix, which is required when control appears in an assignment, call
argument, or right operand. Compatible conditional arms leave their result at
the same virtual stack depth, so no phi object, hidden local, or native move is
needed. A value-less merge trims the unused arm value on its incoming edge;
that changes only the abstract stack depth and emits no machine instruction.
Codegen records the depth, type, flags, and place/value kind at each branch
target and restores them when linear decoding enters a non-fallthrough block.

The general control operations are:

- jump;
- branch;
- switch, referencing a compact literal/target slice;
- fail, a non-returning language/runtime error terminator;
- return;
- catch-region entry and exit;
- throw;
- subroutine call and return.

if, either, loops, any, all, and case lower to these operations. switch remains
explicit so native codegen may choose a comparison chain or jump table from
density without changing frontend semantics.

In a runtime-free module, fail lowers to a native trap. Once the runtime image
is present, the same terminator transfers to its diagnostic service; source
constructs do not encode either policy.

### Calls

Arguments are already on the value stack in source evaluation order. One call
operation contains:

- a direct, imported, or indirect target;
- a logical function signature;
- the actual argument count.

The signature supplies fixed parameter types and attributes. The actual stack
types supply variadic arguments. The same call mechanism handles zero or many
arguments, nested calls, callbacks, function variables, scalar and aggregate
results, and hidden return buffers.

Syscalls and Red callbacks remain distinct semantic operations because their
runtime transitions are genuinely different. They still consume ordinary
typed stack arguments.

### Native Operations

Language-defined native facilities use one native-operation family with stable
semantic identifiers. It covers size?, length?, overflow state, stack,
CPU/FPU, I/O, atomics, image information, push, pop, and assert.

This is not a list keyed by source spelling in codegen. The Red frontend
resolves spellings and paths to semantic native identifiers. Codegen switches
only on operations that the language specification itself distinguishes.

#inline references a literal byte slice and an optional logical return type.

## Logical Types

The frontend owns names, lexical scopes, inference, and type checking. RSIR
contains only the logical structure native layout and ABI lowering require.

Built-in scalar references distinguish:

- logic and byte;
- signed and unsigned fixed-width integers;
- platform integer;
- float32 and float64;
- c-string;
- untyped/null pointer forms.

User type nodes represent:

- pointer plus pointee type;
- fixed literal array plus element type and count;
- struct plus ordered member slice;
- raw or tagged union plus ordered variant slice;
- function signature plus return and parameter slices.

A type use also records reference/value semantics where Red/System permits
both, notably struct and union fields, arguments, and returns. Aliases, enum
labels, member names, and local names remain frontend data unless a name must
be exported or linked.

Tagged-union metadata records logical variants and anonymous payload
structure. Native codegen chooses tag width, payload offset, total alignment,
and member offsets.

Recursive pointers are legal. Recursive by-value layout is rejected while
walking the logical type graph. The result of that walk is cached in native
arrays allocated once per module.

Scalar instructions are type-polymorphic rather than duplicated by datatype.
One literal operation carries a logical type and two raw value limbs, so
binary32 and binary64 constants preserve their exact IEEE payload without a
float-only representation. One cast operation carries its target type and the
specified `keep` bit. One binary operation carries the language operation;
the native selector chooses integer, pointer, or XMM instructions from the
operand types. The frontend enforces the cast matrix, same-type floating
arithmetic, and explicit narrowing rules before RSIR reaches codegen.

## Direct RSIR Order

RSIR uses fixed-size records in one known sequence:

    counts and module properties
    logical types
    members and variants
    imports
    globals
    functions
    parameter and local type uses
    static initializer items
    switch cases
    fixed-width instructions
    literal and linker-visible name bytes

Counts locate each successive table. Source-order IDs index records directly.
Import parameters are followed by each function's parameters and locals in
one type-use table. A function's parameter and local slices are adjacent, so
one storage index addresses both without an adapter or a second instruction
family. Slices store their first index and count only when random access is
required.

Each instruction is four 32-bit words: operation and up to three direct
operands. Stack values do not need result IDs or operand lists. Calls consume
their arguments from the stack; branches name instruction indexes; switch
cases use one shared compact table.

Static initializer items form a flat preorder stream consumed together with
the logical type. Scalar bits, symbol addresses with addends, byte slices,
selected union variants, zero runs, and repetition are explicit; aggregate
shape comes from the type graph rather than child pointers or another tree.
Items contain no target padding or relocation kind. Dynamic initializers are
ordinary module-body instructions and preserve source order.

Only names needed by imports, exports, linker symbols, or requested debug data
cross the boundary.

The binary length is the outer bound. Production code performs one table-bound
walk before casting table starts. Dynamic slice and ID checks are fused into
the first decode that already consumes them; there is no verifier pass.
Frontend type rules are not re-run in production codegen. Debug builds assert
stack shape, branch targets, and internal pass invariants.

There is no magic value, section-name directory, reader object, field getter,
compatibility adapter, or canonical name remapping.

## Red Frontend

The frontend is one Red context with direct data ownership:

1. expand includes, macros, enums, and conditional directives;
2. scan declarations and contexts, assigning source-order IDs;
3. retain body positions in the expanded source block without copying bodies;
4. resolve aliases and complete the logical type graph;
5. parse each body directly into the RSIR instruction binary;
6. patch forward branch targets in place;
7. append linker-visible names and literals;
8. call the native routine.

Name lookup uses hash! tables. Qualified names are constructed once at
declaration or scope entry. Hot paths never search pair blocks with select.

The frontend does not calculate layout, classify ABI arguments, build an AST,
allocate registers, or construct linker objects.

The loader may be reused where it already implements Red/System semantics
directly. It should be simplified when old emitter-facing output or duplicate
normalization is found; compatibility adapters are not retained merely to
reuse a file unchanged.

## Red/System Codegen

The native routine owns all target-dependent work:

1. cast the direct tables after the outer bounds walk;
2. resolve and cache logical layouts;
3. derive basic-block entries and typed stack effects;
4. create compact native value, slot, branch-entry, and offset arrays in one
   allocation;
5. classify Win64 arguments and returns from signatures;
6. perform the selected optimization level in place;
7. assign registers, stack slots, shadow space, and unwind state;
8. select primitive x64 instructions and relax branches;
9. reserve the linker image once and emit into it directly.

The x64 encoder exposes primitive encodings and addressing forms. It must not
grow combined semantic forms such as "call with first literal argument" or
"return current parameter". Argument movement, calls, loads, stores, and
returns are composed by the selector from ordinary primitives.

O0 prioritizes complete, linear, correct lowering. O1 adds local constant
folding, dead-value removal, slot promotion, and simple block cleanup. O2 is
implemented only after O0 and O1 pass the complete suites; it is not a
bootstrap dependency.

Derived native arrays are codegen working memory, not a serialized second IR.
They exist only where layout, control flow, ABI lowering, or allocation
requires them.

## Direct Linker Image

Codegen emits the exact tables the Red linker consumes:

- functions and their code/reference ranges;
- mutable, read-only, and TLS globals;
- imports grouped by library;
- exports;
- symbol and data relocations;
- unwind and exception ranges;
- code, constant, data, and metadata bytes.

Every symbol owns a contiguous reference slice. The linker does not rescan all
relocations per symbol and does not rebuild a generic object model.

The linker remains responsible for PE/COFF policy, libraries, resources,
subsystems, section placement, and final image writing. Its interface may be
changed directly when the codegen image grows; no adapter preserves an
obsolete shape.

## Compile-Speed Rules

- Keep only parsing, binding, type checking, and final linking in Red.
- Traverse expanded source twice, without an AST copy.
- Assign source-order IDs and use direct indexing.
- Reserve large binaries and native scratch areas from counts or measured
  estimates, then grow geometrically only when necessary.
- Build table starts once; advance typed pointers in native loops.
- Compute each target layout and ABI classification once.
- Do not serialize facts that codegen can derive in one linear pass.
- Do not repeatedly validate a trusted private IR.
- Do not run a complete self-host corpus after each small change.
- Record frontend, codegen, linker, total time, peak memory, and output size
  separately.

Release self-compilation must not depend on libRedRT.dll. A relocatable runtime
image produced by the same backend is linked directly and cached by compiler
generation, target, ABI, build mode, and runtime source identity. Development
DLL mode remains useful for debugging, not as the release performance
solution.

## Implementation Order

Each batch implements one orthogonal semantic mechanism through frontend,
RSIR, codegen, linker where needed, and its complete associated test families.
No batch is chosen because a particular self-host identifier happens to be
next.

### 1. Replace The Prototype Core

- replace the scalar-only type records with the complete logical type graph;
- replace the 14 current body operations with the typed stack operations;
- replace combined x64 encoder forms with primitive encodings;
- retain the direct binary! -> routine! -> linker image boundary;
- port current exact-image and executable fixtures to the new semantics;
- delete the old selector state machine in the same change, with no dual path.

Gate: literals, locals, globals, imports, casts, generic loads/stores, direct
and imported calls, and returns work without any operation that describes
argument position or value origin.

### 2. Scalar Expressions And Control

- logic, byte, integer, every fixed-width integer, float32, and float64;
- literal rules, casts, inference, left-to-right math, shifts, bitwise and
  comparison operations;
- locals, assignment results, if, either, loops, any, all, case, switch, break,
  continue, exit, and return;
- general block and stack analysis in native codegen.

Gate: the matching compiler/unit suites and scalar x64 smokes pass.

### 3. Addresses And Aggregate Values

- c-strings, pointers, one-based indexing, pointer arithmetic, and get-paths;
- literal arrays, binary data, protected data, and UTF-16 constants;
- structs, raw/tagged unions, inline/reference fields, aggregate copy, and
  anonymous variant payloads;
- recursive layout, declare, member paths, size?, and symbolic static
  initializers.

Gate: pointer, array, c-string, protect, struct, union, cast, size, layout, and
tagged-union suites pass.

### 4. Complete Calls And Win64 ABI

- shared argument types, signatures, inference, function variables and
  pointers;
- internal, imported, indirect, callback, cdecl/stdcall, variadic, typed, and
  custom calls;
- integer, int64, floating, mixed, register, stack, aggregate-by-value, and
  hidden-return ABI paths;
- callee-save state, shadow space, alignment, stack frames, GC maps, and
  unwind data.

Gate: function/callback/variadic suites and every applicable x64 ABI smoke
pass.

### 5. Non-Local Control And System Facilities

- subroutines, catch regions, catch functions, throw propagation, and
  system/thrown;
- overflow state, explicit push/pop, stack/CPU/FPU/I/O/image facilities;
- atomics with required ordering and target instructions;
- syscalls and inline machine code.

Gate: exception, subroutine, overflow, system, atomic, queue, push/pop, syscall,
and inline probes pass.

### 6. Source And Output Semantics

- all loader/preprocessor directives and diagnostics;
- imports, exports, DLL callbacks, executable/DLL/object/static-library modes;
- Windows driver entry and output mode;
- read-only data, TLS, resources, static libraries, alternate names, COMDAT,
  CRT initialization, and applicable COFF relocations;
- Red callback directives supplied by the Red compiler.

Gate: compiler tests, DLL tests, Windows static-link tests, and focused
directive probes pass.

### 7. Runtime And Red

- generate and cache the relocatable runtime image;
- compile routines, #system, and #system-global through the same RSIR;
- link startup, initializer, finalizer, GC, exceptions, callbacks, and View
  resources;
- run compiled and interpreted Red suites.

Gate: all applicable Red tests pass in release and development configurations.

### 8. H0, H1, H2

- freeze the complete source set S;
- build H0 with the designated existing compiler;
- build H1 with H0 and H2 with H1;
- run all correctness gates on H1 and H2;
- compare deterministic artifacts;
- publish stage timings and sizes.

## Test Cadence

Use the cheapest gate that can disprove the current change:

1. interpreted Red frontend tests for parsing, binding, types, and exact RSIR;
2. pure Red/System decoder/layout/selector tests;
3. one focused native executable for the changed semantic family;
4. the corresponding formal suite group;
5. complete self-host source lowering only at batch milestones;
6. all Red/System and Red suites only at release candidates.

This cadence keeps feedback fast without weakening the final gate.

Normal work must use Stage1 or the designated existing bootstrap executable.
The retired Rebol Stage0 path is not part of verification.
Ordinary native checks use development mode: omit `-r`, keep the Stage1-built
`libRedRT.dll` beside the output, and use at most `-O1` when an optimized build
is needed. Release mode is reserved for gates that specifically require a
standalone artifact; `-O2` is not part of bootstrap feedback.

## Current Baseline

Already retained:

- the direct hybrid entry and small routine! bridge;
- direct output reservation and linker consumption;
- source-order declaration discovery;
- initial name/scope/import/global/function traversal;
- target layout ownership in Red/System, with one module-owned native cache for
  inline/reference size and alignment plus direct member offsets;
- proof that the existing compiler can build and execute the boundary.
- typed postfix values and places with assignment results;
- one contiguous parameter/local storage model with local type inference;
- pointee-preserving pointer nodes and a distinct c-string logical type;
- one semantic function compiler used for size measurement and emission;
- primitive x64 encodings with no call/argument/source-shape combinations.
- primary/prefix parsing followed by strict left-to-right postfix folding;
- generic integer unary, math, shift, bitwise, comparison, and pointer-stride
  lowering selected from logical operand types.
- function-local jump/branch targets with fixed near x64 forms, native offset
  tables, and matching target-entry stack depths and top types;
- if, either, any, all, loop, while, until, early return/exit, break, and
  continue lowered through that shared control core;
- ordered case selection lowered to branch/jump plus a non-returning fail
  terminator, and switch selection represented by a compact typed literal/target
  table with fixed-width integer limbs;
- switch comparison-chain emission with target-relative offsets, including
  byte, integer, and 64-bit scalar execution paths;
- one fixed-width integer rule for lossless widening at assignments, calls,
  explicit returns, and tail returns, represented by the ordinary cast
  operation rather than a source-shaped adapter;
- common integer comparison width and signedness selected from logical types,
  with native loads performing the required sign or zero extension;
- an executable fixed-integer gate covering every scalar width, arithmetic,
  casts, mixed comparisons, scalar calling-convention returns, and eight Win64
  integer arguments through the direct linker path;
- exact IEEE binary32/binary64 literals, ordinary numeric and bit-preserving
  casts, XMM arithmetic, parity-correct unordered comparisons, globals, scalar
  returns, and argument-ordinal Win64 GPR/XMM lowering;
- an executable floating-point gate covering 50 scalar results through the
  same frontend, RSIR, codegen, linker, and generated-PE path;
- one signature-driven Win64 aggregate classifier shared by internal and
  imported direct calls, with 1/2/4/8-byte register values, caller-owned copies
  for other parameter sizes, hidden result pointers, and stable nested-call
  results; internal executable coverage spans structs and unions from one to
  forty bytes, register and stack boundaries, and source-copy isolation;
- the retired wire/schema/driver/adapter experiment and its generated test
  closure have been removed from the repository.

Still incomplete and therefore not an H0:

- the specified float32 remainder operation, complete float aggregate/pointer
  paths and formal float/float32/cast coverage;
- the remaining non-local control operations;
- complete fixed-int/int64 formal coverage for aggregate fields and
  typed/variadic ABI paths;
- complete formal case/switch suite coverage, runtime diagnostic dispatch for
  fail, and dense switch jump-table selection;
- remaining aggregate and array initializers and function-pointer nodes;
- complete Win64 imported/variadic aggregate, indirect-call, callback, and
  formal ABI coverage;
- system facilities, directives, output kinds, runtime image, and Red routines;
- the full Red/System and Red correctness gates followed by H0/H1/H2.

The next source changes continue by semantic family from the feature matrix.
No self-host identifier or isolated test shape defines an operation.

## Commit Boundaries

Make one reviewable commit after each completed batch or independently useful
sub-batch. Every commit must:

- compile with the designated existing compiler when native files changed;
- pass its focused tests;
- leave no fallback to the removed representation;
- report timing when it materially changes the compiler source closure;
- exclude user-owned unrelated worktree changes.
