# Red/System Feature Matrix

This matrix is the completeness ledger for the direct hybrid compiler. It maps
the implemented Red/System specification to semantic mechanisms and tests.
Semantic dependencies determine implementation order; tests reveal missing
rules and prove coverage, but never create a test-shaped IR operation.

Status describes the new direct semantic core:

- retained: the implementation already has the right ownership and shape;
- audit: reusable code exists but must be checked independently of the old
  emitter;
- replace: a narrow prototype exists and must be replaced by the general core;
- pending: the new path does not implement the complete feature.

The first target is Windows x64. Language completeness means every applicable
specified feature works on that target. Target-specific facilities and ABI
rules remain in Red/System codegen.

## Semantic Matrix

| Specification family | Direct mechanism | Primary repository evidence | Status |
| --- | --- | --- | --- |
| Source header, delimiters, comments, free-form syntax | Loader normalization followed by direct token cursor | compiler/compiles-ok-test.r, compiler/output-test.r, compiler/regression-test-rsc.r | audit |
| Integer, character, hex, binary, string and null literals | Dense literal forms and constant bytes; codegen derives contextual types | compiler/int-literals-test.r, units/integer-test.reds, byte-test.reds, null-test.reds | replace |
| #define and parameterized macros | Existing loader expansion before declaration scan | compiler/define-test.reds, compiler/regression-test-rsc.r | audit |
| #enum | Loader assigns labels; frontend keeps labels and resolved integer type | compiler/enum-test.r, units/enum-test.reds | audit |
| #include, #if, #either and #switch | Existing source-order loader expansion with source positions | namespace include tests, compiler/regression-test-rsc.r, focused directive probes | audit |
| #verbose | Loader/compiler diagnostic state only; no RSIR operation | focused positive and invalid-level probes | pending |
| Global, function, use and context scopes | Source-order IDs plus hash! lookup and lexical scope chain | compiler/namespace-test.r, units/namespace-test.reds, use-test.reds | replace |
| with scopes and path-qualified symbols | Resolved frontend scope chain; direct symbol IDs | complete compiler corpus and focused namespace fixtures | replace |
| Aliases and type inference | Frontend binds alias names and slots; codegen canonicalizes aliases and infers local/value types | compiler/alias-test.r, inference-test.r, units/alias-test.reds | replace |
| Global and local variables | Global records and function slots; codegen derives types for address/load/set | compiler/compiles-ok-test.r, x64-local-smoke.reds | replace |
| Protected constant data | Read-only global plus flat initializer stream; codegen rejects writes | units/protect-test.reds, array-test.reds | pending |
| logic!, byte!, integer! | Built-in logical types and generic scalar operations | units/logic-test.reds, byte-test.reds, integer-test.reds | pending |
| Signed and unsigned fixed-width integers | Logical width/sign plus one lossless widening rule at typed boundaries; generic integer operations | units/fixed-int-test.reds, int64-test.reds, rsir-frontend-test.red, rsir-fixed-integer-exit.reds | replace |
| float! and float32! | Exact IEEE literal payloads, ordinary typed casts/binary operations, and target XMM selection | units/float-test.reds, float32-test.reds, math-mixed-test.reds, rsir-float-scalar-exit.reds | pending |
| c-string! | Pointer-to-byte semantics, one-based index, string constant object | units/c-string-test.reds, length-test.reds, lib-test.reds | pending |
| pointer! and get-path | Pointee-preserving type, address/index/load/set/cast | compiler/pointer-test.r, units/pointer-test.reds, get-pointer-test.reds | pending |
| Pointer and struct arithmetic | Generic binary operation plus native stride from logical layout | pointer tests, x64-pointer-parity-smoke.reds | replace |
| Literal and binary arrays | Fixed-array logical type and initializer nodes | units/array-test.reds, protect-test.reds | pending |
| struct! reference and value forms | Logical members, type-use flags, aggregate load/set/copy | units/struct-x64-test.reds, x64-struct-*.reds | pending |
| union! raw form | Shared logical variants and maximum native layout | units/union-test.reds, x64-union-by-value-smoke.reds | pending |
| Tagged unions and variant? | Variant metadata, native tag layout, generic member access and switch | x64-tagged-union-smoke.reds | pending |
| Type casts and size? | Explicit cast intent; codegen checks the cast matrix and queries native layout | compiler/cast-test.r, units/cast-test.reds, size-x64-test.reds | replace |
| Left-to-right expressions | Dense postfix syntax in exact source order; codegen derives stack types | compiler/cond-expr-test.r, infix-test.r, units/conditional-test.reds | replace |
| Math, shifts and bitwise operations | Generic unary/binary operations selected by operand types | integer, fixed-int, modulo and math-mixed unit tests | replace |
| Comparisons and not | Generic compare/unary operations; operand types select integer signedness or IEEE unordered behavior | compiler/not-test.r, units/not-test.reds, rsir-fixed-integer-exit.reds, rsir-float-scalar-exit.reds | replace |
| Predeclared runtime functions and predicates | Frontend-known typed signatures; ordinary calls or semantic native operations | compiler/print-test.r, units/integer-test.reds, lib-test.reds | pending |
| Function declarations and returns | Declared signature, slots, instruction range, and backend-checked return | compiler/return-test.r, units/function-test.reds, return-test.reds | replace |
| Infix functions | Frontend parse rule; ordinary call operation | compiler/infix-test.r, units/infix-test.reds | pending |
| Direct and imported calls | One stack call with target, signature and actual count | units/function-test.reds, x64-function-smoke.reds, x64-import-smoke.reds | replace |
| Function pointers and variables | Function signature type, symbol address, indirect call | compiler/callback-test.r, x64-function-pointer-smoke.reds, x64-function-variable-smoke.reds | pending |
| cdecl, stdcall and callback | Signature attributes and target ABI classifier | compiler/callback-test.r, fixed-int ABI cases, dylib tests | pending |
| Variadic, typed and custom calls | Actual stack types/count plus signature attributes | units/vararg-test.reds, x64-typed-variadic-smoke.reds, x64-variadic-smoke.reds | pending |
| Win64 scalar call ABI | Argument-ordinal GPR/XMM selection, shared stack slots, scalar results and variadic float duplication | x64-register-arg, stack-arg, wide-stack-arg and mixed-arg smokes, rsir-float-scalar-exit.reds | pending |
| Win64 aggregate call ABI | Native value classification, copies and hidden result storage | x64-struct-by-value, union-by-value and hidden-return smokes | pending |
| if, either, any and all | Generic branch/jump; codegen derives common stack prefixes and merges compatible results | units/conditional-test.reds, focused frontend/bridge/linked-PE control tests | replace |
| loop, until and while | Generic branch/jump loops with explicit break/continue targets and ordinary hidden counters | integer and function units, focused frontend/bridge/linked-PE control tests | replace |
| case | Ordered condition blocks, typed result merge, and non-returning fail on no match | units/case-test.reds, compiler conditional tests | pending |
| switch | Typed literal/target slice with explicit default or fail semantics; x64 comparison-chain lowering | units/switch-test.reds, enum and tagged-union tests | pending |
| exit, return, break and continue | Direct function or loop terminators through the shared jump/return core | compiler/exit-test.r, return-test.r, units/exit-test.reds, return-test.reds | replace |
| Subroutines | Function-local entry targets and subroutine call/return | units/subroutine-test.reds, x64-subroutine-smoke.reds | pending |
| throw and catch statement | Catch regions and non-local transfer state | units/exceptions-test.reds, x64-catch-*.reds | pending |
| catch function attribute | Signature flag and resume point after throwing call | units/exceptions-test.reds, x64-catch-runtime.reds | pending |
| overflow? and CPU overflow state | Native arithmetic flags tracked as an explicit effect | units/overflow-test.reds, x64-overflow and mixed-overflow smokes | pending |
| push, pop and stack controls | Native-operation IDs with explicit stack effects | units/push-pop-test.reds, x64-stack-smoke.reds | pending |
| args, environment, CPU, FPU, I/O and image | Native-operation IDs plus symbolic target leaf names; target mapping and checks in codegen/runtime | units/system-test.reds, x64-cpu-register and image-info smokes | pending |
| system/alias and system/words | Frontend semantic aliases and direct resolved symbol paths | units/system-test.reds, namespace tests and complete runtime corpus | pending |
| Atomic load/store/CAS/math/fence | Typed native operations with ordering semantics | units/atomic-test.reds, queue-test.reds, x64-atomic-direct.reds, rsir-atomic-exit.reds | pending |
| #import functions and variables | Direct import records and generic address/call operations | dylib compiler/unit tests, x64-import-var-*.reds | replace |
| #syscall | Syscall declaration plus typed syscall operation | x64-syscall-smoke.reds and focused diagnostics | pending |
| #call | Red callback operation supplied only by embedded Red compilation | focused Red #system/routine probes | pending |
| #export | Linkage flags and direct linker export records | static-link/test-exports.reds, dylib tests | pending |
| #u16 | UTF-16LE constant object with terminal zero | focused byte-exact and runtime probes | pending |
| #inline | Literal code slice and optional typed stack result | focused statement/expression probes | pending |
| Global code flow | Ordinary module-body function preserving source order | compiler/output-test.r and complete source corpus | replace |
| Executable, DLL, object and library output | Direct linker image plus PE/COFF policy | compiler/dylib-test.r, static-link Windows cases | pending |
| Windows driver entry/output | Target output policy and specified on-load entry signature | focused driver build/header diagnostics | pending |
| Runtime startup, GC and callbacks | Relocatable runtime image and direct linker merge | Red runtime tests, x64 runtime/catch/callback smokes | pending |
| Red routine/#system integration | Same frontend and RSIR through the Red compiler | complete compiled and interpreted Red suites | pending |
| Compile-time diagnostics | Syntax/binding diagnostics in frontend; semantic diagnostics in codegen using compact source positions; no retry | compiler/comp-err-test.r and negative focused probes | pending |

## Formal Suite Inventory

The formal Red/System runner is system/tests/run-all.r. Its compiler group is:

- alias-test.r;
- cast-test.r;
- comp-err-test.r;
- exit-test.r;
- int-literals-test.r;
- output-test.r;
- return-test.r;
- cond-expr-test.r;
- inference-test.r;
- callback-test.r;
- infix-test.r;
- not-test.r;
- print-test.r;
- enum-test.r;
- pointer-test.r;
- namespace-test.r;
- compiles-ok-test.r;
- dylib-test.r;
- define-test.reds;
- regression-test-rsc.r.

Its unit groups cover:

- data: array, logic, byte, c-string, struct, union, pointer, cast, alias,
  length, null, enum, protect, float, float32, library, get-pointer and
  float-pointer;
- scope: namespace and use;
- functions: not, size, integer, fixed integer, int64, function, case, switch
  and subroutine;
- non-local control: exit, return and exceptions;
- math: modulo, mixed math and overflow;
- calls: variadic and infix;
- conditionals;
- system operations: system, atomic, queue and push/pop;
- generated dynamic-library coverage.

Passing only a small smoke set does not complete a matrix row. The complete
corresponding formal files must compile, link, execute, and report no
assertion failures.

## Windows x64 ABI Gate

The repository contains direct x64 sources beyond the formal runner. They are
grouped by the mechanism they verify:

- control and locals: x64-branch-smoke.reds, x64-local-smoke.reds,
  x64-secondary-operand-smoke.reds and x64-log-b-call-state-smoke.reds;
- scalar and fixed integer: x64-int64-smoke.reds, x64-fixed-int-smoke.reds,
  x64-fixed-int-op-smoke.reds and x64-fixed-int-path-smoke.reds;
- floating point: x64-float-smoke.reds, x64-float-arg-smoke.reds,
  x64-float-stack-arg-smoke.reds, x64-float-comparison-smoke.reds and
  x64-float32-comparison-smoke.reds;
- calls: x64-argument-count-smoke.reds, x64-register-arg-smoke.reds,
  x64-stack-arg-smoke.reds, x64-wide-stack-arg-smoke.reds,
  x64-mixed-arg-smoke.reds and x64-secondary-call-smoke.reds;
- functions: x64-function-smoke.reds, x64-function-arg-smoke.reds,
  x64-function-pointer-smoke.reds, x64-function-variable-smoke.reds and
  x64-function-nested-path-smoke.reds;
- aggregates: x64-struct-smoke.reds, x64-nested-struct-smoke.reds,
  x64-struct-pointer-index-smoke.reds, x64-struct-by-value-smoke.reds,
  x64-union-by-value-smoke.reds, x64-hidden-return-smoke.reds and
  x64-tagged-union-smoke.reds;
- imports: x64-import-smoke.reds, x64-dylib-import-smoke.reds,
  x64-import-var-smoke.reds, x64-import-var-logic-smoke.reds and
  x64-plt-import-smoke.reds;
- exceptional/system behavior: x64-catch-cleanup.reds,
  x64-catch-global.reds, x64-catch-runtime.reds, x64-overflow-smoke.reds,
  x64-mixed-overflow-smoke.reds, x64-atomic-direct.reds,
  x64-cpu-register-smoke.reds, x64-image-info-smoke.reds,
  x64-stack-smoke.reds and x64-syscall-smoke.reds;
- remaining native forms: x64-pointer-smoke.reds,
  x64-pointer-parity-smoke.reds, x64-not-smoke.reds,
  x64-size-smoke.reds, x64-subroutine-smoke.reds,
  x64-typed-print-smoke.reds, x64-typed-variadic-smoke.reds,
  x64-variadic-smoke.reds and x64-write.reds.

The old PowerShell ABI runner is evidence for the intended cases, not the final
driver, because it invokes the retired Stage0 path. A hybrid-native
runner must execute every applicable x64 source directly.

The direct `rsir-fixed-integer-exit.reds` gate currently executes 49 scalar
checks through frontend, RSIR, native codegen, linker, and the generated PE. It
covers all eight fixed widths, signed and unsigned arithmetic, 64-bit division
and shifts, direct binary-logarithm selection at every logical integer width,
explicit truncation, lossless assignment/call/return widening, mixed-width
comparison, scalar cdecl/callback returns, and eight Win64 integer arguments.
This is mechanism evidence, not row completion: aggregate field paths,
typed/variadic calls, and the complete fixed-int/int64 formal families remain
required.

The direct `rsir-float-scalar-exit.reds` gate executes another 50 checks
through the same path. It covers exact binary32/binary64 constants, arithmetic,
all six comparisons including unordered NaN results, numeric and `keep` casts,
globals, scalar returns, an imported scalar call, and mixed Win64 register/stack
arguments. This proves the shared scalar mechanism, not completion of the float
row. Float aggregate and pointer paths, typed/variadic calls, the specified
float32 remainder operation, and the complete float/float32/cast formal
families remain required.

The direct `rsir-address-index-exit.reds` gate executes 29 address checks
through frontend, RSIR, native codegen, linker, and the generated PE. One
`REFERENCE` conversion turns an existing place into a first-class pointer
without machine work; one type-driven `INDEX` operation handles static and
dynamic one-based indexing for pointers and c-strings. The gate covers local
and global addresses, generic pointer slots, integer-left raw address
arithmetic, pointer-left scaled arithmetic, zero/static/dynamic indexes,
integer, byte and floating pointees, c-string constants, member get-paths, and
nested pointer members. This is mechanism evidence, not completion of the
address/aggregate rows: `declare` storage, literal arrays, protected data,
inline aggregates, aggregate copy, unions, and the complete formal families
remain required.

The direct `rsir-declare-storage-exit.reds` gate exercises the ownership rule
behind `declare`: each aggregate occurrence owns one zeroed object, function
objects live in the native frame, module objects live in static data, and the
language variable remains an ordinary reassignable reference. Structs and raw
unions use the same recursive layout and address operations; the union case
also verifies maximum-size layout and offset-zero overlap. This is mechanism
evidence only. Literal arrays, aggregate copy, tagged-union tags and payloads,
by-value aggregate ABI, and the complete struct/union formal families remain
required.

The direct `rsir-atomic-exit.reds` gate covers the complete specified atomic
operation family through frontend, RSIR, native codegen, linker, and the
generated PE: sequentially consistent fence/load/store, CAS success and
failure, add/sub/or/xor/and with both new-value and `/old` results, and a
struct-member address. Primitive encoder tests additionally require the x64
`LOCK`, `XADD`, `CMPXCHG`, and `MFENCE` bytes. This proves the direct target
mechanism, not row completion: the multithreaded atomic and queue formal
families still require the runtime/thread source closure and must pass intact.

## Windows Linker Gate

Applicable tests in system/tests/static-link include:

- trivial object and archive linkage;
- alignment and split/rdata sections;
- memcpy and miniz libraries;
- stdcall symbols and alternate names;
- exports and static-link flags;
- bigobj;
- COMDAT folding and initialization;
- CRT initialization;
- TLS and TLS COMDAT;
- weak/default symbol handling;
- relocation after constant data.

ELF, Mach-O, ARM and Darwin cases remain later target gates. They must not
distort the Windows x64 semantic core, but the logical RSIR cannot embed a
Windows layout assumption that prevents those backends.

## Required Focused Probes

Some specified features do not have a clearly isolated formal test. Add small
positive, negative, and byte-exact probes for:

- #verbose range and source-local effect;
- #call argument typing and resume into Red/System;
- #u16 UTF-8 conversion, UTF-16LE bytes and terminal zero;
- #inline as a statement and typed expression;
- #syscall declaration diagnostics;
- case without a true catch-all;
- switch literal-only keys and default behavior;
- one-based pointer, c-string and array indexing;
- pointer scaling for every allowed pointee width;
- recursive by-value rejection and recursive pointer acceptance;
- protected path writes and read-only section placement;
- all stack/CPU/FPU/I/O/image operations named by the specification;
- each output kind and required header/export diagnostic.

These probes validate a specification rule. They do not authorize a dedicated
IR operation unless the rule itself is semantically distinct.

## Row Completion

A row changes to retained only when all of the following hold:

1. the feature lowers through the general mechanism named in the matrix;
2. positive tests compile, link and execute;
3. negative tests fail in the single owning layer with the intended diagnostic class;
4. target layout or ABI cases match the Windows x64 rule;
5. no legacy emitter, compatibility adapter or source-name special case is
   reachable;
6. the corresponding complete formal test family passes.

At each implementation batch, update statuses and record the exact commands
and elapsed times in the commit message or benchmark log. Do not mark a feature
complete because the self-host corpus happened not to exercise its remaining
forms.
