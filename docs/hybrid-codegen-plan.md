# Direct Hybrid Red/System Compiler Plan

Status: architecture reset in progress.

The stable outer path is:

    Red/System source
        -> rs-compiler (Red)
        -> dense machine-independent RSIR binary!
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
left to right. A dense postfix instruction stream represents that rule
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

A branch consumes only its condition, which native codegen requires to be a
logic value. Both successors retain the same common stack prefix, which is
required when control appears in an assignment, call argument, or right
operand. Value-producing conditional arms leave their result at the same
virtual stack depth, so no phi object, hidden local, or native move is needed.
Codegen records and validates the depth, type, flags, and place/value kind at
each branch target, then restores them when linear decoding enters a
non-fallthrough block. The frontend never repairs an incompatible merge by
inserting DROP operations; statement-context values are dropped while their
own blocks are lowered.

The frontend retains only enough selection shape to continue parsing: whether
an arm can fall through, whether every reachable arm has a value, and the
first reachable value type as a non-authoritative shadow. A non-exhaustive
tagged switch may use an arm type for that shadow, but its real empty edge is
unchanged in RSIR and native merge validation rejects it in value context.

The frontend does not infer whether a direct call or local subroutine returns.
It lowers each function once in source order, keeps the complete postfix suffix,
and serializes neither a no-return function flag nor a subroutine effect bit.
Native codegen computes one least fixed point over ordinary control edges,
direct calls, catch callers, and local subroutine calls. Two effects are kept:
`RETURNS` exits the enclosing function, while `RESUMES` reaches a local
`SUB_RETURN`. This distinction is required because an ordinary `RETURN` inside
a subroutine exits its enclosing function rather than resuming the local
caller. A forward walk over the same edges then marks the exact instructions
used by layout, frame planning, ABI result storage, and machine selection.

The general control operations are:

- jump;
- branch;
- switch, referencing a compact literal/target slice;
- fail, a non-returning language/runtime error terminator;
- return;
- catch-region entry and exit;
- throw;
- subroutine call and return.

if, either, loops, any, all, and case lower to these operations. Branches own
the predicates of if, either, case, while, until, and every any/all item. ANY
and ALL rebuild their result from the two short-circuit identity literals, so
even the final predicate reaches the same native BRANCH validator. The loop
counter reaches the ordinary typed SET sink. switch remains explicit so native
codegen validates its selector and may choose a comparison chain or jump table
from density without changing frontend semantics.

THROW is a two-input semantic operation: the frontend resolves the existing
thrown storage place, while codegen validates the original integer ID and
place, writes the ID, updates any variant tag chain, and emits the non-local
unwind. There is no intermediate SET or source-shaped coercion in this path.

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

The Red frontend resolves the language facility to a semantic native operation.
It also preserves the source-defined argument boundary and the shallow result
type needed to continue parsing. It does not coerce or validate the runtime
operand combination. Codegen consumes the original postfix values, validates
their pointer, scalar, and result types while deriving the stack effect, and
then emits the target instruction. Value presence remains a frontend shape
check because dense postfix RSIR has no explicit argument delimiter; without
it, a valueless operand could accidentally consume an enclosing expression's
value.

Debug ASSERT lowers through the same branch/fail core, so native BRANCH owns
its predicate. Ordinary release ASSERT follows the existing language compiler
rule and removes its unevaluated expression entirely. The existing statically
false tail/inferred form remains an explicit FAIL terminator for the native
effect fixed point; the frontend does not run a second compatibility check for
either form.

Target-independent leaf names stay symbolic. For example, `system/cpu/rax`
stores the register name in RSIR; only x64 codegen maps it to a physical
register number. Codegen switches only on distinctions made by the language
specification, never on a source-specific special case.

#inline references a literal byte slice and an optional logical return type.

## Logical Types

The frontend owns source syntax, declarations, lexical scopes, and binding
names to source-order IDs. Red/System codegen owns expression inference, type
compatibility, implicit conversion, legality checks, and result-type merging.
RSIR contains the declared logical type graph and syntax-resolved operations
needed to do that work without retaining a Red AST.

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

A type use records explicit source annotations and reference/value syntax where
Red/System permits both, notably struct and union fields, arguments, and
returns. Alias names, enum labels, member names, and local names are bound by
the frontend; canonical aliases, inferred local types, and expression types
are derived once by codegen. Names remain frontend data unless a later
operation, diagnostic, export, or link requires them.

Each USE declaration receives one source-order local slot and leaves the
active name environment at the end of its lexical body. The frontend does not
reuse slots by spelling or compare their runtime types; later native lifetime
analysis may coalesce non-overlapping storage without changing RSIR identity.
Repeated scalar DECLARE syntax compares canonical declared identity only.
Runtime value compatibility has no parallel Red implementation.

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
codegen derives its operand and result types, checks the cast matrix and
narrowing rules, inserts required coercions in native working state, then
selects integer, pointer, or XMM instructions. Those rules have one production
owner: codegen.

The frontend may encode a direct floating-point literal in its final target
width when the source spelling alone proves the conversion. Every other
runtime cast remains one ordinary cast instruction. Static symbol addresses
retain their source type and are accepted by codegen only when the target can
hold the relocation representation unchanged. Static conversions that require
computation belong to initializer lowering; they are not approximated by
writing an address or source bit pattern into the target slot.

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
The frontend validates only source and IR shape that it must know to parse.
Codegen performs semantic checks while deriving stack and control-flow facts;
the same rule is not retained as a production check in Red. Source positions
cross the boundary as compact indexes where backend diagnostics need them.
Debug builds may additionally assert internal pass invariants.

There is no magic value, section-name directory, reader object, field getter,
compatibility adapter, or canonical name remapping.

## Red Frontend

The frontend is one Red context with direct data ownership:

1. expand includes, macros, enums, and conditional directives;
2. scan declarations and contexts, assigning source-order IDs;
3. retain body positions in the expanded source block without copying bodies;
4. encode declared type syntax and bind lexical names to IDs;
5. parse each body directly into a dense left-to-right RSIR instruction binary;
6. record source control structure and symbolic targets, retaining only the
   shallow value-presence/type shadow needed to continue parsing, without
   checking or repairing branch merges;
7. append only required literals, symbols, target-leaf names, and diagnostics;
8. call the native routine.

Name-to-value lookup uses map! tables; hash! is reserved for actual sets.
Qualified names are constructed once at declaration or scope entry. Hot paths
never search pair blocks with select.

The frontend does not infer authoritative expression or local types, enforce
operand, dynamic cast, call, assignment, return, branch-predicate, or branch-
merge compatibility, fold runtime expressions, calculate layout, build CFG
state, classify ABI arguments, allocate registers, or construct linker objects.
Its parser shadow is not serialized as a second type system and never rewrites
an incompatible producer to make it pass native validation.

The loader may be reused where it already implements Red/System semantics
directly. It should be simplified when old emitter-facing output or duplicate
normalization is found; compatibility adapters are not retained merely to
reuse a file unchanged.

## Red/System Codegen

The native routine owns all target-dependent work:

1. cast the direct tables after the outer bounds walk;
2. canonicalize declared types and infer unresolved local and value types;
3. check operations, calls, casts, assignments, returns, and branch merges;
4. resolve and cache logical layouts and derive basic-block entries;
5. create compact native value, slot, branch-entry, and offset arrays in one
   allocation;
6. classify Win64 arguments and returns from signatures;
7. perform the selected optimization level in place;
8. assign registers, stack slots, shadow space, and unwind state;
9. select primitive x64 instructions and relax branches;
10. reserve the linker image once and emit into it directly.

The x64 encoder exposes primitive encodings and addressing forms. It must not
grow combined semantic forms such as "call with first literal argument" or
"return current parameter". Argument movement, calls, loads, stores, and
returns are composed by the selector from ordinary primitives.

There are exactly two optimization levels:

- O0 is the default bootstrap and development path. It performs only linear
  analysis and inexpensive selector work: direct immediates and addresses,
  short encodings, zero-cost coercions, obvious move elimination, and a fast
  value-location stack. It must compile quickly and produce code at least as
  good as the old pure Red compiler's default O1 path.
- O2 enables a small Pareto set of high-value cross-instruction analyses:
  constant and copy propagation, local and temporary register promotion,
  redundant load/store elimination, address folding, call-argument move
  coalescing, branch simplification, and unreachable-block removal.

O1 is invalid, not an alias. O2 is exposed only with a real native
transformation and must never silently run the O0 path. Its first enabled
transform resolves an adjacent literal logic branch when no control edge can
enter after the literal, removes the literal and unselected successor from the
native CFG, and emits only the selected edge. It reuses the codegen effect
arrays and adds no serialized field or frontend rule. Global SSA, aggressive
inlining, complex loop transforms, and vectorization are outside the initial
O2 scope.

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

- Keep only preprocessing, declaration parsing, lexical binding, static
  initializer encoding, and final linking in Red.
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

1. interpreted Red frontend tests for parsing, binding, and exact dense RSIR;
2. pure Red/System decoder/layout/selector tests;
3. one focused native executable for the changed semantic family;
4. the corresponding formal suite group;
5. complete self-host source lowering only at batch milestones;
6. all Red/System and Red suites only at release candidates.

This cadence keeps feedback fast without weakening the final gate.

Normal work must use the designated existing bootstrap executable or the latest
proven hybrid generation, never an intermediate Stage1 executable. The retired
Rebol Stage0 path is not part of verification.
Ordinary native checks use development mode: omit `-r`, keep the designated
bootstrap's `libRedRT.dll` beside the output, and use the default `-O0` feedback
path. Release mode is reserved for gates that specifically require a standalone
artifact. O2 has a separate performance build and never participates in normal
Hn-to-Hn+1 feedback measurement.

Self-compilation timing uses one known-good matching `libRedRT.dll`,
`libRedRT-defs.red`, and `libRedRT-include.red` set. Rebuilding libRedRT and
measuring the compiler are separate gates, so runtime image-layout regressions
cannot contaminate compiler-speed results.

## Current Baseline

Already retained:

- the direct hybrid entry and small routine! bridge;
- direct output reservation and linker consumption;
- source-order declaration discovery;
- initial name/scope/import/global/function traversal;
- target layout ownership in Red/System, with one module-owned native cache for
  inline/reference size and alignment plus direct member offsets;
- proof that the existing compiler can build and execute the boundary.
- dense postfix values and places with backend-derived types and assignment results;
- one contiguous, source-order parameter/local declaration table. The frontend
  keeps only the shallow local type inference needed while parsing. An
  unreferenced untyped local remains type `0` inside the local slice; native
  codegen reuses its existing instruction scan to mark `LOCAL_ADDRESS` slots,
  and `plan-storage` assigns frame offsets only to referenced locals. Parameters,
  import parameters, and referenced locals must have concrete types. This
  removes the frontend's recursive syntax-tree pruning scan without adding an
  IR operation, adapter, allocation, bitmap, or optimization pass;
- one source-order slot per lexical USE declaration, without name-based
  frontend reuse or runtime compatibility checks;
- pointee-preserving pointer nodes and a distinct c-string logical type;
- one semantic function compiler used for size measurement and emission;
- primitive x64 encodings with no call/argument/source-shape combinations.
- primary/prefix parsing followed by strict left-to-right postfix folding;
- one dense unary operation and one dense binary operation for all scalar
  families; the Red frontend records syntax plus lexical overflow metadata and
  keeps only the shallow result projection needed to continue parsing, while
  native codegen alone validates runtime operands, derives the authoritative
  result type, performs coercion, and selects integer, pointer, or XMM code;
- native codegen runs for both linked and no-link jobs, so omitting the linker
  cannot bypass backend semantic validation;
- function-local jump/branch targets with fixed near x64 forms, native offset
  tables, and matching target-entry stack depths and top types;
- if, either, any, all, loop, while, until, early return/exit, break, and
  continue lowered through that shared control core. Native BRANCH validates
  logic predicates, native SET validates the loop count, and native target
  merging validates reachable value depth and type. The frontend emits no
  merge-repair DROP and retains only parser shadow state. Every any/all value,
  including the final one, is consumed by BRANCH and the result is rebuilt from
  short-circuit identity literals;
- ordered case selection lowered to branch/jump plus a non-returning fail
  terminator, and switch selection represented by a compact typed literal/target
  table with fixed-width integer limbs;
- switch comparison-chain emission with target-relative offsets, including
  byte, integer, and 64-bit scalar execution paths;
- one fixed-width integer rule for lossless widening at assignments, calls,
  ordinary and subroutine returns: RSIR keeps the producer and declared sink
  types, while codegen validates the pair and fuses extension into the native
  load; no implicit cast operation or source-shaped adapter is emitted;
- assignments, direct/imported/indirect calls, ordinary/subroutine returns,
  and system stack writes now keep producer values unchanged in RSIR. Native
  codegen alone checks the declared sink, compares complete function
  signatures using the target call shape (fixed default/stdcall/cdecl are one
  Win64 shape, while packed and C variadic remain distinct),
  applies contextual null and direct-literal rules, and selects the target-width
  load or XMM conversion. One negative native stack tag marks a direct float
  literal; positive tags remain union-variant write chains;
- CDECL variadic `float32!` promotion is derived from the signature and actual
  argument ordinal in codegen, including both Win64 register mirrors and stack
  arguments; the frontend emits no promotion CAST;
- the frontend emits the complete postfix expression after every declared call
  result and does not guess a call or subroutine termination effect. Native
  codegen derives function return, local subroutine resume, and forward
  reachability effects over one direct edge graph. A `[catch]` caller retains
  its continuation because a throw resumes immediately after that call;
  unreachable suffixes consume no frame, call-result, or machine-code planning;
- CATCH filters and semantic native-operation operands cross RSIR unchanged.
  The Red frontend resolves operation spelling, refinement, argument count, and
  target-independent leaf names, while native codegen alone validates CATCH,
  atomic load/store/CAS/math, stack allocation/free, CPU-register assignment,
  PUSH, and LOG-B operand and result types. THROW additionally consumes the
  original ID and place directly, so native codegen owns its source/destination
  compatibility, storage write, variant tags, and unwind. The frontend retains
  only structural value presence and parser result shadow. Explicit
  `system/thrown:` assignment is an ordinary typed SET:
  its original producer and resolved integer place cross RSIR unchanged, and
  the existing native SET consumer owns their compatibility without a marker;
- dynamic pointer indexing preserves the original index value for native INDEX
  validation. VARIANT? resolves only its literal member name in Red and leaves
  tagged-versus-raw legality to native TAG. EXIT emits the ordinary void RETURN,
  whose compatibility with the enclosing function signature is checked by
  native codegen;
- common integer comparison width and signedness selected from logical types,
  with native loads performing the required sign or zero extension;
- one dense explicit CAST whose complete dynamic compatibility matrix,
  `keep` restrictions, alias classification, null rejection, width conversion,
  and machine selection are owned by native codegen. The frontend always emits
  the cast after parsing and retains only warning and shadow-result work;
  `byte!` remains distinct from `uint8!`, and representation-preserving static
  symbol-address casts retain their source type for separate native validation;
- an executable fixed-integer gate covering every scalar width, arithmetic,
  casts, mixed comparisons, scalar calling-convention returns, and eight Win64
  integer arguments through the direct linker path;
- exact IEEE binary32/binary64 literals, ordinary numeric and bit-preserving
  casts, common-width XMM arithmetic including both mixed operand orders,
  parity-correct unordered comparisons, globals, scalar returns, and
  argument-ordinal Win64 GPR/XMM lowering;
- an executable floating-point gate covering 50 scalar results through the
  same frontend, RSIR, codegen, linker, and generated-PE path;
- one signature-driven Win64 aggregate classifier shared by internal and
  imported direct calls, with 1/2/4/8-byte register values, caller-owned copies
  for other parameter sizes, hidden result pointers, and stable nested-call
  results; internal executable coverage spans structs and unions from one to
  forty bytes, register and stack boundaries, and source-copy isolation;
- H41 built the complete current H42 compiler in the normal development O0
  path in 63.859 seconds using the known-good runtime DLL set (frontend 23.887,
  native 32.759, link 7.060 seconds). H42 then built the 55-check
  floating-point/ABI executable in 0.521 seconds and it returned the expected
  exit code 73. H42 is 13,312 bytes smaller than H41, with `.text` raw size
  reduced by 9,728 bytes rather than duplicated;
- H42 built H43 with the native CAST ownership in the normal development O0
  path in 68.032 seconds (frontend 25.970, backend 41.965, native codegen
  0.650, link build 6.999 seconds) using the same known-good runtime DLL set.
  H43 is 19,456 bytes smaller than H42 and its `.text` raw size is 17,408 bytes
  smaller. H43 rebuilt and passed the native codegen suite, built the 50-check
  floating-point executable which returned 73, passed all 158 assertions in
  the formal Red/System unit cast suite, and independently rejected six invalid
  source casts in native codegen;
- H43 then built the same-source H44 in 65.777 seconds (frontend 24.351,
  backend 41.336, native codegen 0.651, link build 5.716 seconds). H44 has the
  same 6,372,864-byte size as H43 and starts successfully with only O0/O2,
  proving that the compiler containing this ownership change can build its
  next generation;
- H44 built H45 with native control-predicate and selection-merge ownership in
  61.706 seconds (frontend 23.424, backend 38.281, native codegen 0.682, link
  build 6.038 seconds). H45 is 6,345,728 bytes, 27,136 bytes smaller than H44,
  and its `.text` raw size fell by 24,576 bytes to `588200h`. Ten isolated
  invalid source programs reached and were rejected by native codegen, while
  the formal conditional, case, switch, and logic executables passed all 274
  assertions;
- H45 then built the same-source H46 in 65.521 seconds (frontend 23.976,
  backend 41.545, native codegen 0.651, link build 6.930 seconds). H46 has the
  same size and `.text` size as H45, exposes only O0/O2, and rebuilds and passes
  the native codegen suite;
- H46 built H47 with native intrinsic operand ownership in 66.348 seconds
  (frontend 22.857, backend 43.382, native codegen 0.648, link build 6.953
  seconds). H47 is 6,327,808 bytes, 17,920 bytes smaller than H46, and its
  `.text` raw size fell by 15,872 bytes to `584400h`. Eight isolated invalid
  CATCH, atomic, stack, CPU, and LOG-B source programs reached and were rejected
  by native codegen. The formal atomic, system, push/pop, exceptions, and
  integer executables passed all 1,656 assertions;
- H47 then built the same-source H48 in 69.058 seconds (frontend 26.097,
  backend 42.841, native codegen 0.690, link build 6.352 seconds). H48 has the
  same total and `.text` sizes as H47, exposes only O0/O2, and rebuilds and
  passes the native codegen suite;
- H48 built H49 with direct THROW value/place ownership in 64.295 seconds
  (frontend 24.768, backend 39.297, native codegen 0.675, link build 5.827
  seconds). H49 is 6,330,880 bytes, 3,072 bytes larger than H48, with `.text`
  raw size `585000h` (`C00h` larger). Its native suite passed, the formal
  exceptions executable passed all 67 assertions, and both ordinary and
  tagged-place THROW probes exited successfully; an invalid boolean ID reached
  and was rejected by native codegen;
- H49 then built the same-source H50 in 69.353 seconds (frontend 24.625,
  backend 44.496, native codegen 0.662, link build 6.672 seconds). H50 has the
  same 6,330,880-byte image and `.text` raw size as H49, exposes only O0/O2,
  and rebuilt and passed the native codegen and 67-assertion exception gates;
- H50 built H51 after moving dynamic INDEX, VARIANT?, explicit
  `system/thrown:`, and EXIT legality to their existing native consumers. Its
  compiler profile totals 68.728 seconds (frontend 24.943, backend 43.785,
  native codegen 1.439, link build 5.892 seconds). H51 is 6,329,856 bytes,
  1,024 bytes smaller than H50; `SizeOfCode` fell from `585000h` to `584C00h`
  while the file-aligned `.text` raw size remains `585000h`. Four isolated
  invalid sources reach native rejection, and the pointer, union, exit, return,
  and exception executables pass all 296 assertions;
- H51 built the unchanged source into H52 in 68.729 wall seconds (frontend
  26.754, backend 41.878, native codegen 1.271, link build 6.383 seconds).
  H52 has the same image size, `SizeOfCode`, and `.text` raw size as H51,
  exposes only O0/O2, rejects the same four invalid sources, and rebuilds and
  passes the native fixture plus the same 296-assertion formal gate;
- H52 built H53 after removing the Red runtime-compatibility mini-engine,
  routing every ANY/ALL predicate through native BRANCH, and assigning each
  lexical USE declaration its own source slot. The development O0 build took
  68.835 seconds (frontend 24.999, backend 43.692, native codegen 0.647, link
  build 6.778 seconds). H53 is 6,290,432 bytes, 39,424 bytes smaller than H52;
  `SizeOfCode` fell to `57BE00h` and `.text` raw size to `57C000h`;
- H53 built the same source into H54 in 66.045 seconds (frontend 23.343,
  backend 42.587, native codegen 0.647, link build 7.445 seconds). H54 is
  6,303,744 bytes because the new frontend now compiles its own source;
  H54 then built H55 in 64.845 seconds (frontend 25.393, backend 39.342,
  native codegen 0.652, link build 5.525 seconds). H54 and H55 have identical
  total size, `SizeOfCode` `57F200h`, and `.text` raw size `580000h`;
- after making USE slot numbering one linear pass, H55 built final-source H56
  in 65.696 seconds (frontend 25.063, backend 40.523, native codegen 0.636,
  link build 7.194 seconds), and H56 built H57 in 62.520 seconds (frontend
  22.321, backend 40.088, native codegen 0.696, link build 5.950 seconds).
  H56 and H57 retain the same 6,303,744-byte total, `SizeOfCode` `57F200h`,
  and `.text` raw size `580000h`. H57 exposes only O0/O2, rejects an invalid
  final ANY/ALL predicate in native codegen, passes the native fixture, and
  passes 143 formal tests with all 176 assertions;
- H57 built H58 after adding the native O0 identity-boolean fold in 66.047
  seconds (frontend 26.453, backend 39.595, native codegen 0.650, link build
  6.791). The fold uses saturated incoming-edge counts gathered by the existing
  structural scan and consumes the generic `BRANCH/literal/JUMP/literal` shape
  only when its interior has no other entry. It adds no frontend rule, new RSIR,
  CFG, adapter, or codegen pass;
- H58 built H59 in 58.981 seconds (frontend 22.259, backend 36.722, native
  codegen 0.667, link build 6.282), and H59 built H60 in 63.314 seconds
  (frontend 24.461, backend 38.853, native codegen 0.696, link build 5.927).
  H58-H60 are all 6,315,008 bytes with `SizeOfCode` and `.text` raw size
  `581E00h`. A DLL probe keeps `identity` at 44 bytes and reduces both
  one-value ANY and ALL from 76 to 58 bytes; their body is branchless
  `test/setne` code. H60 rebuilds and passes the native fixture and the
  conditional, use, logic, exit, and return gate: 143 tests, 176 assertions;
- H60 built H61 after adding a one-slot O0 value-location selector in 61.166
  seconds. The selector holds only the top postfix slot, recognizes lazy frame,
  indirect-frame, address, `RAX`, and `XMM0` locations, and forwards them only
  to an adjacent consumer with no incoming edge, catch transition, or ENTRY.
  Unsupported consumers materialize the value into its existing frame slot.
  LOAD, REFERENCE, MEMBER, DROP, scalar RETURN/SUB_RETURN, and the boolean fold
  consume matching locations directly. This adds no RSIR field, allocation,
  frontend rule, adapter, CFG, or pass;
- H61 built H62 in 61.596 wall seconds (frontend 22.586, RSIR frontend 27.519,
  native codegen 0.739, link build 4.935), and H62 built H63 in 59.961 seconds
  (frontend 22.990, RSIR frontend 23.802, native codegen 0.622, link build
  6.707). H62 and H63 are both 5,215,232 bytes with `SizeOfCode` `475600h`,
  `.text` virtual size `4755E9h`, and `.text` raw size `476000h`; their complete
  files differ only at four PE timestamp/checksum bytes. Relative to H61, total
  size falls 1,123,840 bytes (17.73%) and `SizeOfCode` falls 19.38%;
- H63 rebuilds and passes the native fixture and the frontend fixture. H62
  passes the complete Windows x64 Red/System runner (10,582 tests and all
  12,647 assertions), while H63 passes the complete current non-View Red runner
  (8,730 tests and all 16,755 assertions). The same gate corrects contextual
  function sinks according to the specified C callback model: fixed
  cdecl/default/stdcall signatures share the Win64 call shape, but packed and C
  variadic signatures remain distinct and are rejected independently by SET,
  CALL, and RETURN;
- the same one-slot selector now consumes adjacent integer and floating right
  operands at BINARY and integer values at UNARY. Before loading the left
  operand, the live right value moves directly from `RAX` to the existing
  `RDX`/`RCX` operation register, or from `XMM0` to `XMM1`; a mixed floating
  width converts directly during that move. Results remain in `RAX` or `XMM0`
  for the next adjacent consumer. One invariant keeps every GPR location
  canonical for its declared type, so 1/2-byte results use register-only
  sign/zero extension before propagation. This adds no location stack, RSIR
  field, allocation, frontend rule, adapter, CFG, or pass;
- H63 built H64, which contains the new backend but was emitted by the previous
  backend, in 62.263 wall seconds (compiler profile 62.131, frontend 24.447,
  RSIR frontend 26.057, native codegen 0.602, link build 4.860). H64 is
  5,225,472 bytes with `SizeOfCode` `477E00h`;
- H64 then built the first compiler emitted through the new operator paths,
  H65, in 61.802 wall seconds (compiler profile 61.666, frontend 23.931, RSIR
  frontend 24.864, native codegen 0.615, link build 5.396). H65 is 5,139,968
  bytes with `SizeOfCode` and `.text` raw size `463000h`, 85,504 bytes smaller
  than H64. Relative to the previous H63 fixed point, both total image and code
  fall by 75,264 bytes (1.443% of the image);
- H65 built H66 in 65.649 wall seconds (compiler profile 65.501, frontend
  25.020, RSIR frontend 27.883, native codegen 0.568, link build 4.756). H65
  and H66 have identical size, `SizeOfCode`, `.text` virtual size `462E0Ch`,
  and `.text` bytes; their complete files differ only at three PE
  timestamp/checksum bytes. All three builds reuse runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- H66 rebuilds and passes the primitive encoder, native codegen, and thin
  frontend fixtures. It passes the complete Windows x64 Red/System runner in
  71.700 seconds (10,582 tests, 12,647/12,647 assertions, no compile failures)
  and the complete current non-View Red runner in 250.145 seconds (8,730 tests,
  16,755/16,755 assertions). Both suite stderr logs are empty;
- the same one-slot selector now lets SET consume its adjacent PLACE directly.
  A frame PLACE becomes an address in `RDX`, an indirect-frame PLACE loads its
  address into `RDX`, and a live member address moves from `RAX` to `RDX`.
  Constructing that target has already materialized the source VALUE in its
  existing postfix slot, so no second location or location stack is required.
  An untagged linear scalar result remains in `RAX` or `XMM0`; aggregate and
  variant-tagged results remain frame-backed because aggregate copies preserve
  pointer semantics and tag emission uses the same work registers. This adds no
  frontend rule, RSIR field, allocation, adapter, CFG, or pass;
- H66 built H67, which contains the new backend but was emitted by the previous
  backend, in 58.799 wall seconds (compiler profile 58.668, frontend 23.751,
  RSIR frontend 23.878, native codegen 0.574, link build 4.842). H67 is
  5,140,480 bytes with `SizeOfCode` `463200h`;
- H67 built the first compiler emitted through the new SET paths, H68, in
  66.085 wall seconds (compiler profile 65.958, frontend 23.715, RSIR frontend
  31.523, native codegen 0.571, link build 4.665). H68 is 4,901,888 bytes with
  `SizeOfCode` and `.text` raw size `428E00h` and `.text` virtual size
  `428D94h`. It is 238,592 bytes smaller than H67 and 238,080 bytes (4.632%)
  smaller than the preceding H66 fixed point;
- H68 built H69 in 60.986 wall seconds (compiler profile 60.859, frontend
  23.847, RSIR frontend 25.142, native codegen 0.493, link build 5.193). H68
  and H69 have identical image size, `SizeOfCode`, `.text` layout, and `.text`
  SHA256 `68FCFE12EF3C1ACAD79F796E74778F3EA6D87B787F4493B2836552E1D503EA7A`;
  their complete files differ only at two PE timestamp/checksum bytes. All
  three builds reuse the fixed runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- H69 rebuilds and passes the primitive encoder, native codegen, and thin
  frontend fixtures. It passes the complete Windows x64 Red/System runner in
  70.870 seconds (10,582 tests, 12,647/12,647 assertions, no compile failures)
  and the complete current non-View Red runner in 250.399 seconds (8,730 tests,
  16,755/16,755 assertions). Both suite stderr logs are empty;
- ordinary BRANCH now consumes a canonical logic value already live in `RAX`.
  The backend keeps the existing `test`/conditional-jump lowering, skips only
  the redundant frame store/load, and clears the one-slot location after the
  branch. The boolean-diamond fold remains independent: a non-folded branch
  has the same stack-depth and merge behavior as before, while a branch with an
  incoming edge still materializes through the existing frame path. This adds
  no RSIR field, allocation, frontend rule, adapter, CFG, or pass;
- H69 built H70 in 102.335 wall seconds and H70 built H71 in 99.261 seconds;
  H71 built H72 in 105.712 seconds. These three clocks are correctness runs,
  not performance measurements: a stale offline RSIR parser process was found
  consuming the host CPU during them and was terminated after the H72 suite.
  H70 remains 4,901,888 bytes, while H71 and H72 are 4,865,536 bytes with
  `SizeOfCode` and `.text` raw size `420000h` and `.text` virtual size
  `41FEE9h`, a 36,352-byte reduction from H70/H69;
- after that process was stopped, H72 built H73 in 73.014 wall seconds and H73
  built H74 in 63.386 seconds (H74 compiler profile 63.258, frontend 25.574,
  RSIR frontend 25.552, native codegen 0.453, link build 5.269). H73 and H74
  have identical image size and `.text` SHA256
  `5EDBB39C666A7B9562F0B59D3834265F683FB059751F5FC8D4D613A459C90CF1`;
  their complete files differ only at PE timestamp/checksum bytes. The direct
  BRANCH fixture locks the generated function at 46 bytes and executes both
  truth paths;
- H72 (whose `.text` is identical to clean H74) rebuilds and passes the
  primitive encoder, native codegen, and thin frontend fixtures. It also passes
  the complete Windows x64 Red/System runner (10,582 tests, 12,647/12,647
  assertions, no compile failures) and the complete current non-View Red runner
  (8,730 tests, 16,755/16,755 assertions); those two wall times are retained
  only as correctness-run metadata because of the verified host contention.
  All H70-H74 builds reuse the fixed runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- a scalar CALL result now enters the same one-slot selector directly from its
  Win64 ABI register. A linear continuation keeps an integer/reference result
  in `RAX` or a floating result in `XMM0`; an existing DROP, scalar operation,
  RETURN, MEMBER, or BRANCH consumer can use it without a frame round-trip.
  One- and two-byte integer returns are sign/zero extended before publication,
  preserving the canonical GPR invariant even for foreign callees. Aggregate
  returns keep their dedicated result storage, and a concrete no-return call
  never publishes a result. Calls whose next instruction has an incoming edge
  still materialize through the existing frame path. No call argument rule,
  ABI shape, frontend rule, RSIR field, allocation, adapter, CFG, or pass is
  added;
- H74 built H75, which contains the new backend but was emitted by the previous
  backend, in 64.641 wall seconds (compiler profile 64.525, frontend 22.477,
  RSIR frontend 30.767, native codegen 0.452, link build 4.544). H75 is
  4,866,560 bytes with `SizeOfCode` and `.text` raw size `420400h` and `.text`
  virtual size `42025Ah`;
- H75 built the first compiler emitted through the new CALL-result path, H76,
  in 60.749 wall seconds (compiler profile 60.620, frontend 23.975, RSIR
  frontend 24.831, native codegen 0.492, link build 4.418). H76 is 4,574,208
  bytes with `SizeOfCode` and `.text` raw size `3D8E00h` and `.text` virtual
  size `3D8D01h`, 292,352 bytes smaller than H75. Relative to the clean H74
  fixed point, the image is 291,328 bytes (5.988%) smaller;
- H76 built H77 in 60.032 wall seconds (compiler profile 59.917, frontend
  23.620, RSIR frontend 24.353, native codegen 0.426, link build 5.157). H76
  and H77 have identical image size, `.text` layout, and `.text` SHA256
  `853FAB4D7CBB8271BAA66F3093E431621F7D2001D838BC37593024CE7ACECD80`;
  their complete files differ only at three PE timestamp/checksum bytes. The
  focused fixtures execute direct CALL-to-BRANCH, CALL-to-DROP, floating
  CALL-to-RETURN, and a narrow signed result in caller bodies of 46, 31, 26,
  and 29 bytes respectively; existing indirect and variadic execution fixtures
  pass through the same result path;
- H77 rebuilds and passes the primitive encoder, native codegen, and thin
  frontend fixtures. It passes the complete Windows x64 Red/System runner in
  68.718 seconds (10,582 tests, 12,647/12,647 assertions, no compile failures)
  and the complete current non-View Red runner in 255.140 seconds (8,730 tests,
  16,755/16,755 assertions). Both suite stderr logs are empty. H75-H77 reuse
  the fixed runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- scalar CAST now consumes and republishes the existing one-slot location
  directly. Representation-preserving casts emit no instruction, numeric
  conversions stay in `RAX` or `XMM0`, and only a control-flow boundary writes
  the target value back to its postfix slot. Narrow integer targets are
  canonicalized before publication. Bit-preserving `integer!`/`float32!`
  transitions use direct `MOVD` register transfers, or load the same four-byte
  slot directly into the target register class when the source is already
  materialized. The encoder exposes the corresponding 32/64-bit GPR/XMM move
  primitives. No frontend rule, RSIR field, adapter, allocation, CFG, or pass
  is added;
- H77 built H78, which contains the CAST backend but was emitted by the previous
  backend, with a 62.794-second compiler profile (frontend 22.971, RSIR frontend
  28.630, native codegen 0.613, link build 4.445). H78 is 4,576,768 bytes with
  `.text` raw size `3D9800h` and virtual size `3D96B1h`;
- H78 built the first CAST-forwarded compiler, H79, in 58.710 wall seconds
  (compiler profile 58.462, frontend 23.063, RSIR frontend 24.213, native
  codegen 0.544, link build 4.504). H79 built H80 in 57.499 wall seconds
  (compiler profile 57.241, frontend 23.187, RSIR frontend 22.944, native
  codegen 0.429, link build 5.008). H79 and H80 are both 4,567,040 bytes with
  `.text` raw size `3D7200h`, virtual size `3D70BEh`, and `.text` SHA256
  `30888C2AA7E895F4D82057F933011DC07F8C471400EB8F09A14945171E49A5CC`;
  their complete files differ only at three PE timestamp/checksum bytes. The
  new backend removes 9,728 bytes from H78 and is a net 7,168 bytes smaller
  than the H77 fixed point. A final whitespace-only style correction was
  rebuilt as H81; H81 has the same image size, `.text` layout, and `.text` hash
  and differs from H80 only in PE timestamp/checksum metadata;
- the focused CAST fixtures execute narrowing, signed widening, 64-to-32-bit
  truncation, both bit-preserving GPR/XMM directions, both numeric float
  directions, branch-merge materialization, and integer/floating CALL-to-CAST
  paths. Representative caller bodies are 29 bytes for integer CALL-to-CAST
  and 30 bytes for floating CALL-to-CAST. H80 rebuilds and passes the primitive
  encoder, native codegen, and thin frontend fixtures, the complete Windows x64
  Red/System runner in 68.149 seconds (10,582 tests, 12,647/12,647 assertions,
  no compile failures), and the complete current non-View Red runner in 243.720
  seconds (8,730 tests, 16,755/16,755 assertions). H78-H81 reuse the same fixed
  runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- CALL argument marshaling now consumes the same one-slot location directly
  when it is the last logical scalar argument. This is a backend consequence
  of postfix order, not a new frontend convention: for every nonempty CALL the
  final argument is the stack top. Fixed and C-variadic calls move or convert
  that value from `RAX`/`XMM0` into its Win64 register or outgoing stack slot;
  packed calls write it directly into the packed list. A volatile `R11` or
  `XMM4` holds it only when marshaling an earlier argument would overwrite its
  ABI register. Typed/custom calls and aggregate values materialize through
  the existing frame path. C-vararg floating register mirrors now use a direct
  XMM-to-GPR transfer. No RSIR field, frontend rule, adapter, allocation, CFG,
  or extra pass is introduced;
- the canonical compiler RSIR contains 454,640 instructions and 116,970 CALLs.
  Of the nonempty calls, 72,846 have an adjacent producer and 72,844 of those
  producers are scalar. Their immediate producers are 36,313 LOADs, 27,703
  LITERALs, 4,020 REFERENCEs, 2,779 CALLs, 1,082 CASTs, 947 BINARYs, and two
  NATIVEs. The corresponding call modes are 70,640 fixed, 2,191 packed, eight
  typed, and seven C variadic. This distribution selected the general last
  argument boundary; no source name or fixture shape selects it;
- H81 built the source-bearing H82 in 58.180 wall seconds (compiler profile
  58.043, frontend 22.509, RSIR frontend 24.645, native codegen 0.435, link
  build 4.605). H82 is 4,574,208 bytes. H82 built the first argument-forwarded
  H83 in 67.701 seconds, and H83 built H84 in 61.540 seconds. Final packed and
  floating stack-argument refinements produced H87/H88 in 58.441 and 66.450
  seconds. H87 and H88 are both 4,296,192 bytes with `.text` raw size
  `395000h`, virtual size `394F11h`, and `.text` SHA256
  `DCCB49F3BA3615C97A7A3E706D0B2E573BBBBAABABD4361738DD745D60AF1563`;
  their complete files differ only in PE metadata. Against the H81 fixed point,
  both image and raw code fall by 270,848 bytes: 5.93% of the image and 6.73%
  of `.text`;
- H88 rebuilds and passes the primitive encoder, native codegen, and thin
  frontend fixtures. Focused callers cover a signed fixed argument, a fifth
  stack argument, floating values protected across earlier arguments, a fifth
  floating stack argument locked at 87 bytes, two packed arguments, and a
  one-value packed call whose caller is locked at 52 bytes. H88 passes the
  complete Windows x64 Red/System runner in 72.157
  seconds (10,582 tests, 12,647/12,647 assertions, no compile failures) and the
  complete current non-View Red runner in 270.657 seconds (8,730 tests,
  16,755/16,755 assertions). H82-H88 reuse the fixed runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- unused-local storage planning now belongs to native codegen. The frontend
  preserves every declared local in source order and no longer recursively
  walks each function body before lowering just to remove unused declarations.
  The existing native instruction scan marks referenced local slots, so unused
  typed or untyped declarations consume neither frame space nor initialization
  code. A representative compiler-source profile reduced `prepare-functions`
  from about 1.427 seconds to 0.375 seconds, a roughly 1.05-second phase
  reduction. The end-to-end samples remain too variable to claim the same wall
  reduction;
- H88 built source-bearing H89 in 60.836 wall seconds, and H89 built H90 in
  63.770 seconds. H89 and H90 are both 4,289,024 bytes with `.text` raw size
  `393800h`, virtual size `393660h`, and identical `.text` SHA256
  `79753D89E595B1790D30CBA365DE1F34F2A2EBD4DC461B8D2F427607D43FCD80`;
  their complete files differ only at three PE metadata bytes. Against H88 the
  image is 7,168 bytes smaller and raw `.text` is 6,144 bytes smaller;
- H90 rebuilds and passes the native codegen and thin frontend fixtures. It
  passes the complete Windows x64 Red/System runner in 70.578 seconds (10,582
  tests, 12,647/12,647 assertions, no compile failures) and the complete current
  non-View Red runner in 242.563 seconds (8,730 tests, 16,755/16,755 assertions).
  H89/H90 use the same fixed runtime DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- function lowering no longer recursively scans source blocks to order callees
  or infer a wire no-return bit. It lowers each source-order function once and
  preserves every parsed postfix suffix. Native codegen builds direct reverse
  edges, computes the least fixed point for enclosing-function `RETURNS` and
  local-subroutine `RESUMES`, then performs one forward reachability walk.
  Function flag 1024 and subroutine ENTRY/CALL effect fields are rejected or
  reserved rather than treated as frontend authority. The work is O(V + E),
  uses compact integer arrays in the existing scratch allocation, and feeds
  frame, call-result, and machine-code planning directly;
- H96 built H97 through this native effect path in 52.515 wall seconds. H96 and
  H97 are both 4,289,536 bytes with `.text` raw size `394200h`, virtual size
  `394140h`, and identical `.text` SHA256
  `A80B0DFA7334C6C44B9DD68B2D5CD23D11EAEB7553A726649ED98EA100735517`.
  The frontend and native codegen fixtures pass, as do the complete O0
  Red/System and Red runners at 12,647/12,647 and 16,755/16,755 assertions;
- O2 is now a real backend level rather than an accepted spelling or O0 alias.
  When an adjacent canonical logic literal dominates a BRANCH, native codegen
  marks only the selected successor live, elides the literal/condition pair,
  and removes the unreachable arm. A standalone Windows probe executes
  correctly in both modes and reduces virtual `.text` from `38EDh` at O0 to
  `3895h` at O2. O1 remains rejected by the hybrid command line and native
  entry;
- H97 built source-bearing H98 at O0 in 55.023 wall seconds, and H98 built H99
  at O0 in 52.607 seconds. H98/H99 are both 4,295,168 bytes with `.text` raw
  size `395A00h`, virtual size `395818h`, and identical `.text` SHA256
  `4BC47CC9FF575973694629F469F1907A64241B8A4AE652C0BA8B933DDD815070`.
  H99 at O2 passes the complete Windows x64 Red/System runner (10,582 tests,
  12,647/12,647 assertions, no compile failures) and the complete current
  non-View Red runner (8,730 tests, 16,755/16,755 assertions);
- the separate H100 O2 performance build completes in 56.814 wall seconds,
  starts, and compiles and runs the O2 probe. It is 4,293,632 bytes with
  `.text` raw size `395400h` and virtual size `395343h`: 1,536 raw code
  bytes and 1,237 virtual code bytes below H99 O0. H96-H100 all reuse runtime
  DLL SHA256
  `96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`;
- a final O2 location refinement materializes an existing stack-prefix value
  before eliding its following constant condition. Focused execution covers
  both selected successors, a direct edge which bypasses the adjacent literal,
  and a value-producing branch merge. H99 built source-bearing H101 at O0 in
  55.232 wall seconds, and H101 built H102 at O0 in 59.419 seconds. H101/H102
  are both 4,295,168 bytes with `.text` raw size `395A00h`, virtual size
  `395818h`, and identical final `.text` SHA256
  `4F015A7E2DA3C2550984217A7DA7FE09D591209F3E86C27E8187FBB88C68F466`;
- final H102 at O2 passes the complete Windows x64 Red/System runner (10,582
  tests, 12,647/12,647 assertions, no compile failures) and the complete
  current non-View Red runner (8,730 tests, 16,755/16,755 assertions). H102
  builds the final H103 O2 performance compiler in 63.070 wall seconds. H103
  is 4,293,632 bytes with `.text` raw size `395400h`, virtual size
  `395343h`, and `.text` SHA256
  `3237A5179E9134A07B83FFE75A32EAB641A7381D4CEE8A2C892B5DEB2567EC2F`.
  The O2 build remains a code-size gate, not evidence of a build-time speedup;
  H101-H103 reuse the same fixed runtime DLL;
- the separate Red/System compiler-diagnostic runner remains an explicit H0
  gap: H88 reports 124 assertions and 38 failures. H81 reports the same totals,
  and the ordered set of all 38 failed test labels is identical, so this batch
  introduces no diagnostic regression but does not claim that gate as passed;
- this batch proves a code-quality and footprint improvement, not a
  self-compilation wall-time improvement. Fixed-point builds span the observed
  58-66 second band, while native codegen remains below 0.8 seconds;
  the variation is still concentrated in the Red frontend, RSIR frontend, and
  their GC cycles. Further compiler-evolution speedups must reduce those two
  Red phases or their allocation pressure rather than infer speed from `.text`
  size alone;
- the retired wire/schema/driver/adapter experiment and its generated test
  closure have been removed from the repository.

Still incomplete and therefore not an H0:

- the specified float32 remainder operation, complete float aggregate/pointer
  paths, computed static cast initializers, compiler diagnostic cast cases,
  and remaining float/float32 coverage;
- the remaining non-local control operations;
- complete fixed-int/int64 formal coverage for aggregate fields and
  typed/variadic ABI paths;
- compiler diagnostic and source-location coverage for control errors, runtime
  diagnostic dispatch for fail, and dense switch jump-table selection;
- remaining aggregate and array initializers and function-pointer nodes;
- complete Win64 imported/variadic aggregate, indirect-call, callback, and
  formal ABI coverage;
- system facilities, directives, output kinds, runtime image, and Red routines;
- repeating the complete Red/System and Red correctness gates after the
  remaining feature families, followed by the H0/H1/H2 fixed-point gates.

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
