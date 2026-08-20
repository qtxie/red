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
| Integer, character, hex, binary, string and null literals | Dense literal forms and constant bytes; null remains typeless until native codegen consumes it at a declared sink | compiler/int-literals-test.r, units/integer-test.reds, byte-test.reds, null-test.reds, x64-codegen-reds-test.reds | replace |
| #define and parameterized macros | Existing loader expansion before declaration scan | compiler/define-test.reds, compiler/regression-test-rsc.r | audit |
| #enum | Loader assigns labels; frontend keeps labels and resolved integer type | compiler/enum-test.r, units/enum-test.reds | audit |
| #include, #if, #either and #switch | Existing source-order loader expansion with source positions | namespace include tests, compiler/regression-test-rsc.r, focused directive probes | audit |
| #verbose | Loader/compiler diagnostic state only; no RSIR operation | focused positive and invalid-level probes | pending |
| Global, function, use and context scopes | Source-order IDs plus hash! lookup and lexical scope chain; every USE declaration owns one source slot until native lifetime optimization proves reuse | compiler/namespace-test.r, units/namespace-test.reds, use-test.reds | replace |
| with scopes and path-qualified symbols | Resolved frontend scope chain; direct symbol IDs | complete compiler corpus and focused namespace fixtures | replace |
| Aliases and type inference | Frontend binds alias names and slots; codegen canonicalizes aliases and infers local/value types | compiler/alias-test.r, inference-test.r, units/alias-test.reds | replace |
| Global and local variables | Global records and function slots; codegen derives types for address/load/set | compiler/compiles-ok-test.r, x64-local-smoke.reds | replace |
| Protected constant data | Read-only global plus flat initializer stream; codegen rejects writes | units/protect-test.reds, array-test.reds | pending |
| logic!, byte!, integer! | Built-in logical types and generic scalar operations | units/logic-test.reds, byte-test.reds, integer-test.reds | pending |
| Signed and unsigned fixed-width integers | Logical producer/sink types plus one codegen-owned lossless widening rule at typed boundaries; generic integer operations | units/fixed-int-test.reds, int64-test.reds, rsir-frontend-test.red, rsir-fixed-integer-exit.reds | replace |
| float! and float32! | Exact IEEE literal payloads and ordinary typed operations; native codegen derives math and sink widths, performs operand or permitted direct-literal conversion, and selects XMM forms | units/float-test.reds, float32-test.reds, math-mixed-test.reds, rsir-float-scalar-exit.reds, x64-codegen-reds-test.reds | pending |
| c-string! | Pointer-to-byte semantics, one-based index, string constant object | units/c-string-test.reds, length-test.reds, lib-test.reds | pending |
| pointer! and get-path | Pointee-preserving type and generic address/index/load/set/cast; native INDEX validates the original dynamic index value and derives stride | compiler/pointer-test.r, units/pointer-test.reds, get-pointer-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | pending |
| Pointer and struct arithmetic | Generic binary operation plus native stride from logical layout | pointer tests, x64-pointer-parity-smoke.reds | replace |
| Literal and binary arrays | Fixed-array logical type and initializer nodes | units/array-test.reds, protect-test.reds | pending |
| struct! reference and value forms | Logical members, type-use flags, aggregate load/set/copy | units/struct-x64-test.reds, x64-struct-*.reds | pending |
| union! raw form | Shared logical variants and maximum native layout | units/union-test.reds, x64-union-by-value-smoke.reds | pending |
| Tagged unions and variant? | Frontend resolves literal variant names; native TAG validates tagged-versus-raw input using variant metadata and native tag layout | units/union-test.reds, x64-tagged-union-smoke.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | pending |
| Type casts and size? | One dense explicit CAST; native codegen owns the dynamic compatibility matrix, `keep`, alias categories, null rejection and conversion, while source-typed static addresses use a separate relocation-representation check; codegen queries native layout | compiler/cast-test.r, units/cast-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds, size-x64-test.reds | replace |
| Left-to-right expressions | Dense postfix syntax in exact source order; codegen derives stack types | compiler/cond-expr-test.r, infix-test.r, units/conditional-test.reds | replace |
| Math, shifts and bitwise operations | One dense binary operation plus lexical overflow metadata; native codegen owns operand legality, result type, coercion, and instruction selection | integer, fixed-int, modulo and math-mixed unit tests, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| Comparisons and not | Dense binary/unary operations with a parser-only shadow result; native codegen owns operand legality and selects integer signedness or IEEE unordered behavior | compiler/not-test.r, units/not-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds, rsir-fixed-integer-exit.reds, rsir-float-scalar-exit.reds | replace |
| Predeclared runtime functions and predicates | Frontend-known typed signatures; ordinary calls or semantic native operations | compiler/print-test.r, units/integer-test.reds, lib-test.reds | pending |
| Function declarations and returns | Declared signature, slots and instruction range; value RETURN keeps its producer type, while EXIT remains a void RETURN, and native codegen checks both against the declared result | compiler/return-test.r, units/function-test.reds, return-test.reds, x64-codegen-reds-test.reds | replace |
| Infix functions | Frontend parse rule; ordinary call operation | compiler/infix-test.r, units/infix-test.reds | pending |
| Direct and imported calls | One stack call with target, signature and actual count; native codegen checks parameter sinks and performs required scalar ABI conversion | units/function-test.reds, x64-function-smoke.reds, x64-import-smoke.reds, x64-codegen-reds-test.reds | replace |
| Function pointers and variables | Function signature type, symbol address and indirect call; native sink compatibility compares complete return, parameter, and target call-shape records | compiler/callback-test.r, x64-function-pointer-smoke.reds, x64-function-variable-smoke.reds, x64-codegen-reds-test.reds | pending |
| cdecl, stdcall and callback | Signature attributes and target ABI classifier; fixed default/stdcall/cdecl signatures share the Win64 sink shape required by C callbacks, while packed and C variadic shapes remain distinct | compiler/callback-test.r, units/lib-test.reds, fixed-int ABI cases, dylib tests, x64-codegen-reds-test.reds | pending |
| Variadic, typed and custom calls | Actual stack types/count plus signature attributes; codegen applies C default `float32!` promotion to variadic extras | units/vararg-test.reds, x64-typed-variadic-smoke.reds, x64-variadic-smoke.reds, x64-codegen-reds-test.reds | pending |
| Win64 scalar call ABI | Argument-ordinal GPR/XMM selection, shared stack slots, scalar results, sink-width conversion and variadic float duplication | x64-register-arg, stack-arg, wide-stack-arg and mixed-arg smokes, rsir-float-scalar-exit.reds, x64-codegen-reds-test.reds | pending |
| Win64 aggregate call ABI | Native value classification, copies and hidden result storage | x64-struct-by-value, union-by-value and hidden-return smokes | pending |
| if, either, any and all | Generic branch/jump; every predicate reaches native BRANCH and the frontend retains only syntax, targets, and parser shadow state. O0 lowers an unshared logic identity diamond directly to `test`/`setne`; shared short-circuit targets retain control flow | units/conditional-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds, isolated native-rejection sources | replace |
| loop, until and while | Generic branch/jump loops with explicit break/continue targets; native BRANCH validates conditions and the ordinary typed SET sink validates hidden loop counters | units/conditional-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| case | Ordered condition blocks and non-returning fail on no match; native branch and target merge own predicate/result legality without frontend repair | units/case-test.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| switch | Typed literal/target slice with explicit default or fail semantics; native selector and target-merge validation plus x64 comparison-chain lowering | units/switch-test.reds, enum and tagged-union tests, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| exit, return, break and continue | Direct function or loop terminators through the shared jump/return core; native RETURN owns EXIT/result compatibility | compiler/exit-test.r, return-test.r, units/exit-test.reds, return-test.reds, x64-codegen-reds-test.reds | replace |
| Subroutines | Function-local entry targets and subroutine call/return | units/subroutine-test.reds, x64-subroutine-smoke.reds | pending |
| throw and catch statement | Catch regions and non-local transfer state; native CATCH owns filter type, native THROW consumes the original ID plus thrown place, and explicit system/thrown assignment remains an ordinary native-validated SET | units/exceptions-test.reds, x64-catch-*.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| catch function attribute | Signature flag and resume point after a throwing call; no-return fallthrough is cut only in non-catch callers | units/exceptions-test.reds, x64-catch-runtime.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | pending |
| overflow? and CPU overflow state | Native arithmetic flags tracked as an explicit effect | units/overflow-test.reds, x64-overflow and mixed-overflow smokes | pending |
| push, pop and stack controls | Native-operation IDs with explicit stack effects; codegen validates stack allocation/free operands while the frontend retains only argument shape and result shadow | units/push-pop-test.reds, x64-stack-smoke.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
| args, environment, CPU, FPU, I/O and image | Native-operation IDs plus symbolic target leaf names; target mapping and runtime operand checks, including CPU-register assignment, live in codegen/runtime | units/system-test.reds, x64-cpu-register and image-info smokes, rsir-frontend-test.red | pending |
| system/alias and system/words | Frontend semantic aliases and direct resolved symbol paths | units/system-test.reds, namespace tests and complete runtime corpus | pending |
| Atomic load/store/CAS/math/fence | Typed native operations with ordering semantics; the frontend resolves operation/refinement/arity and codegen validates the original pointer, values, and result | units/atomic-test.reds, queue-test.reds, x64-atomic-direct.reds, rsir-atomic-exit.reds, rsir-frontend-test.red, x64-codegen-reds-test.reds | replace |
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
explicit truncation, lossless assignment/call/return widening without implicit
CAST records, mixed-width comparison, scalar cdecl/callback returns, and eight
Win64 integer arguments. The native codegen fixture additionally executes
subroutine-return widening and isolates invalid SET, CALL, RETURN, and BINARY
type pairs.
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

The focused cast ownership gate keeps invalid source casts in dense RSIR until
native codegen consumes them. Raw native fixtures cover function, integer,
byte, fixed-width, logic, pointer, c-string, float, float32, null and alias
categories, including numeric and bit-preserving conversion plus independently
validated static function-address initializers. H43 also rejects isolated
pointer-to-byte, float-to-byte, null-to-function, binary-to-byte, static
function-to-byte and invalid static `keep` source programs in native codegen.
The formal Red/System unit cast executable passes all 158 assertions. This
proves dynamic ownership, direct-relocation validation and the unit language
matrix, not completion: computed static conversions, compiler diagnostic cases
and non-x64 targets remain required.

The focused control ownership gate leaves invalid predicates and incompatible
selection results unchanged until native BRANCH, SWITCH, SET, or target-merge
validation consumes them. H45 independently rejects ten source programs for
invalid if/case/while/until/any/all predicates, a logic switch selector, a
logic loop count, and incompatible either/case results. The formal conditional,
case, switch, and logic executables pass 274 assertions in total. This proves
the shared x64 mechanism and formal unit behavior; precise compiler diagnostics,
source locations, fail dispatch, jump-table selection, and non-x64 targets
remain incomplete.

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

The native-consumer ownership gate leaves invalid CATCH, atomic, stack,
CPU-register, and LOG-B operands unchanged until native codegen consumes them.
H47 independently rejects eight invalid source programs in that owning layer;
raw fixtures separately cover every atomic STORE, LOAD, and CAS input and result
position plus stack allocation/free counts and allocation result metadata. The
formal atomic, system, push/pop, exceptions, and integer executables pass 1,656
assertions in total. H47 then builds the same-source H48 with identical total
and `.text` sizes. This proves the ownership boundary and self-hosting closure,
not completion of the broader system rows: queue/thread behavior, remaining
CPU/FPU/I/O/image forms, and non-x64 targets remain required.

The direct THROW gate extends that boundary over the exception state itself:
the frontend emits the original ID, the existing thrown place, and one OP_THROW;
native codegen validates both slots, performs the scalar store, emits tagged
variant writes when needed, and then unwinds. H49 and H50 both pass the native
codegen fixture, the 33-test/67-assertion exception suite, and ordinary plus
tagged-place executable probes. This proves direct THROW ownership and
self-hosting closure. The following H51/H52 gate proves that the separate
`system/thrown:` assignment needs no exception-specific operation: it keeps the
producer plus resolved place and lets ordinary native SET validate them.

The same H51/H52 gate moves three other existing consumers to that boundary:
dynamic INDEX validates its original index value, TAG distinguishes tagged and
raw unions after the frontend resolves a literal member name, and RETURN checks
whether a void EXIT matches the enclosing function. Both generations reject
four isolated invalid sources in native codegen, rebuild and pass the native
fixture, and pass the pointer, union, exit, return, and exception formal
executables: 152 tests and 296 assertions per generation. H51 and H52 are both
6,329,856 bytes with `SizeOfCode` `584C00h`, 1,024 bytes below H50.

The H53-H57 gate removes the remaining Red runtime-compatibility mini-engine.
Every ANY/ALL value now reaches native BRANCH, debug ASSERT uses that same
consumer, ordinary release ASSERT follows the legacy ignored-expression rule,
and each lexical USE declaration retains a distinct source slot. H57 rejects
an invalid final condition in native codegen, passes the native fixture, and
passes the conditional, use, logic, exit, and return executables: 143 tests
and 176 assertions. Final-source H56 and H57 are both 6,303,744 bytes with
`SizeOfCode` `57F200h` and `.text` raw size `580000h`; H56 built H57 in 62.520
seconds. This proves the x64 ownership and self-hosting fixed point.

The H58-H60 gate adds the corresponding O0 simplification wholly inside native
codegen. The existing structural scan records saturated incoming-edge counts;
a generic `BRANCH`, opposite logic literal, `JUMP`, logic literal diamond is
collapsed only when none of its three interior instructions has another entry
and all four instructions remain at the same catch depth. The consumer then
normalizes the value with `test`/`setne` in the same postfix slot. This adds no
frontend rule, RSIR form, CFG, adapter, or third codegen pass. A source probe
reduces both one-value ANY and ALL functions from 76 to 58 bytes while identity
remains 44 bytes, and disassembly contains no conditional jump. H57 built H58
in 66.047 seconds, H58 built H59 in 58.981 seconds, and H59 built H60 in 63.314
seconds. H58-H60 are all 6,315,008 bytes with `SizeOfCode` and `.text` raw size
`581E00h`; H60 rebuilds and passes the native fixture and the same 143-test,
176-assertion formal gate. Complete formal families remain required.

The H61-H63 gate adds the first generic O0 value-location selector wholly inside
native codegen. It tracks only the top postfix slot as a lazy frame address,
indirect frame address, live address, `RAX`, or `XMM0`, and only across the
immediately adjacent instruction when there is no incoming control edge, catch
transition, or ENTRY. LOAD, REFERENCE, MEMBER, DROP, scalar RETURN/SUB_RETURN,
and the existing boolean fold consume a matching location directly; every other
consumer materializes it into the existing frame slot before that instruction.
There is no new RSIR field, scratch allocation, frontend rule, adapter, CFG, or
extra pass. Focused execution covers integer and binary64 local return paths and
both sides of an incoming-edge merge.

H60 built H61 in 61.166 seconds. H61 then built the optimized H62 in 61.596
seconds, and H62 built H63 in 59.961 seconds. H62 and H63 are both 5,215,232
bytes with `SizeOfCode` `475600h`, `.text` virtual size `4755E9h`, and `.text`
raw size `476000h`; they differ in only four PE timestamp/checksum bytes. Against
H61, total image size falls by 1,123,840 bytes (17.73%) and `SizeOfCode` by
19.38%. H63 rebuilds and passes the native and frontend fixtures. H62 passes the
complete Windows x64 Red/System runner (10,582 tests, 12,647/12,647 assertions),
and H63 passes the complete current non-View Red runner (8,730 tests,
16,755/16,755 assertions). The sink regression exposed by `lib-test.reds` is
also fixed at the general ABI boundary: fixed cdecl/default/stdcall function
values share one Win64 call shape, while packed and C variadic values remain
distinct at SET, CALL, and RETURN.

The H64-H66 gate extends that same one-slot selector to the scalar operator
family without changing its architecture. An adjacent UNARY consumes `RAX`;
BINARY moves its live right operand from `RAX` to the existing `RDX`/`RCX`
operation register, or from `XMM0` to `XMM1`, before loading the left operand.
Mixed floating widths convert during the XMM move, and operator results remain
in `RAX` or `XMM0` for the next adjacent consumer. GPR locations are canonical
typed values: 1/2-byte results receive register-only sign/zero extension before
they propagate. There is still no location stack, new RSIR field, allocation,
frontend rule, adapter, CFG, or extra pass.

H63 built H64 in 62.263 wall seconds; H64 built H65 in 61.802 seconds; and H65
built H66 in 65.649 seconds. H64, the generation emitted by the previous
backend, is 5,225,472 bytes with `SizeOfCode` `477E00h`. H65 and H66 are both
5,139,968 bytes with `SizeOfCode` and `.text` raw size `463000h` and `.text`
virtual size `462E0Ch`; their complete files differ only at three PE
timestamp/checksum bytes and their `.text` is identical. Against H63, total
image and code both fall by 75,264 bytes (1.443% of the image). H66 rebuilds and
passes the encoder, native codegen, and frontend fixtures, the complete Windows
x64 Red/System runner (10,582 tests, 12,647/12,647 assertions, no compile
failures), and the complete current non-View Red runner (8,730 tests,
16,755/16,755 assertions). The fixed runtime DLL SHA256 is
`96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`.

The H67-H69 gate extends the same one-slot selector to assignment without a new
stack model. SET consumes its adjacent PLACE directly: a frame PLACE computes
its address in `RDX`, an indirect-frame PLACE loads that address, and a live
member address moves from `RAX` to `RDX`. The intervening target construction
has already materialized the source VALUE in its existing postfix slot. An
untagged linear scalar result remains in `RAX` or `XMM0`; aggregate and
variant-tagged results remain frame-backed because aggregate values preserve
pointer semantics and tag emission uses the work registers. There is no new
RSIR field, allocation, frontend rule, adapter, CFG, or extra pass. Focused
execution covers integer and binary64 local assignment chains, scalar widening,
aggregate member copies, and variant-tagged member assignment.

H66 built H67 in 58.799 wall seconds. H67, emitted by the previous backend, is
5,140,480 bytes with `SizeOfCode` `463200h`. H67 built the first optimized H68
in 66.085 seconds, and H68 built H69 in 60.986 seconds. H68 and H69 are both
4,901,888 bytes with `SizeOfCode` and `.text` raw size `428E00h` and `.text`
virtual size `428D94h`; their `.text` SHA256 is identically
`68FCFE12EF3C1ACAD79F796E74778F3EA6D87B787F4493B2836552E1D503EA7A`, and
their complete files differ only at two PE timestamp/checksum bytes. Against
the preceding H66 fixed point, image and code both fall by 238,080 bytes
(4.632%). H69 rebuilds and passes the encoder, native codegen, and frontend
fixtures, the complete Windows x64 Red/System runner (10,582 tests,
12,647/12,647 assertions, no compile failures), and the complete current
non-View Red runner (8,730 tests, 16,755/16,755 assertions). The fixed runtime
DLL SHA256 remains
`96C8A603A021FDBAFBAC715966DDB1CB5D98375375A8CB4863F084322B04958B`.

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
