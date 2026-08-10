# Hybrid Compiler Wire Protocol

Status: design draft. Version 1 is not frozen and no compatibility promise is
made until every Red/System semantic feature has an owner and a wire encoding.

See also [the execution plan](hybrid-codegen-plan.md) and
[the backend ownership audit](compiler-backend-ownership.md).

This protocol is the in-process boundary between the Red implementation of the
Red/System semantic frontend, the Red/System native code generator, and the
existing Red linker. It defines four message kinds:

| Magic | Name | Producer | Consumer |
| --- | --- | --- | --- |
| `RSIR` | semantic module IR | Red frontend | Red/System codegen |
| `RSCF` | codegen configuration | Red driver | Red/System codegen |
| `RSCG` | relocatable code object | Red/System codegen | Red merger/linker adapter |
| `RSDG` | structured diagnostics | Red/System codegen | Red driver |

The current `system/machine-ir.red` graph is an optimization prototype and a
behavioral oracle. It is not the wire schema: it contains optimizer-derived
state and still reads semantic and layout information from the legacy compiler
and emitter.

## Ownership

The boundary is useful only if each fact has exactly one authoritative owner.

| Concern | Authoritative owner |
| --- | --- |
| loading, preprocessing, names, namespaces, type checking | Red frontend |
| nominal types, target data layout, typed CFG, constants, imports, exports | RSIR |
| typed expression temporaries, mutable slots, explicit stack operations | RSIR |
| scalar/memory SSA, phi nodes, stack-state propagation, liveness | codegen internal MIR |
| instruction selection, ABI classification, register allocation | codegen |
| frame layout, spill roots, GC bitmap construction, unwind encoding | codegen |
| section bytes, symbols, relocations, function extents | RSCG |
| object merging, final addresses, image imports/exports, resources | Red linker |

RSIR is backend-independent but target-parametric. Red/System struct layout and
some language semantics depend on the selected target, so one RSIR message is
valid only for the target and ABI recorded in its header. It contains no
physical register, encoded argument location, frame offset, or legacy emitter
byte range. The only target-machine escape is an explicitly tagged `#inline`
fragment because the source language itself permits raw target bytes.

## Common container

### Scalar rules

- Container metadata and table fields are always little-endian, independent of
  target endianness. The target-endian header field describes generated data.
- Offsets are zero-based from the first byte of the containing message.
- Record IDs are one-based. Zero means absent.
- Every offset, size, count, ID, enum, and flag value is below `80000000h`.
  A message is therefore smaller than 2 GiB and checked arithmetic can use the
  signed 32-bit Red/System `integer!` type.
- Fields explicitly named `raw-lo` and `raw-hi` are bit containers, not scalar
  integers. Their high bit may be set. Readers copy or combine their bytes and
  must not validate them with signed range comparisons.
- Host pointers, Red series handles, words, blocks, objects, and implementation
  addresses are forbidden.
- Variable-length values live in byte sections and use `(offset, size)` slices.

### Header

Every message starts with this 64-byte header.

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | ASCII magic |
| 4 | 2 | major version |
| 6 | 2 | minor version |
| 8 | 4 | header size, 64 in v1 |
| 12 | 4 | container flags |
| 16 | 4 | total message size |
| 20 | 4 | section count |
| 24 | 4 | section directory offset, 64 in v1 |
| 28 | 4 | directory record size, 32 in v1 |
| 32 | 4 | target ID |
| 36 | 4 | ABI ID |
| 40 | 4 | target endian ID |
| 44 | 4 | target pointer size |
| 48 | 4 | enabled target feature mask, low word |
| 52 | 4 | enabled target feature mask, high word |
| 56 | 4 | producer build ID |
| 60 | 4 | schema fingerprint |

Target IDs start with `1 x86-64`, `2 ARM64`, `3 ARM32`, and `4 x86`. ABI IDs
start with `1 Win64`, `2 SysV-x64`, `3 AAPCS64`, `4 AAPCS32`, and `5 Win32`.
Endian IDs are `1 little` and `2 big`.

`RSIR`, `RSCF`, and `RSCG` require a nonzero target and ABI. `RSDG` may use
zero when the input failed before target validation. The RSIR and RSCF target,
ABI, pointer size, and both feature-mask words must match exactly.

The schema fingerprint is generated from the checked-in enum and record-layout
manifest. It detects a compiler built with mismatched Red and Red/System schema
constants; it is not a content checksum.

### Section directory

Each directory record is 32 bytes.

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 4 | section kind |
| 4 | 4 | section flags |
| 8 | 4 | payload offset, or zero when empty |
| 12 | 4 | payload size in bytes |
| 16 | 4 | record count |
| 20 | 4 | record size |
| 24 | 4 | payload alignment, a power of two |
| 28 | 4 | reserved, zero |

Flag bit 0 is OPTIONAL, bit 1 is SORTED, and bit 2 is DEDUPLICATED. Section
kinds are unique within a message. Unknown required sections are rejected;
unknown optional sections may be ignored.

For every section, checked multiplication must prove that
`record-count * record-size == payload-size`. Byte sections use record size 1.
The directory and all nonempty payloads fit inside the declared message size,
meet alignment, and do not overlap. Padding bytes are zero.

A major-version mismatch is fatal. A reader may accept an older or equal minor
version only when it understands all required sections and flags. Producers
emit tables in their specified stable order and zero every reserved field, so
identical inputs and options produce byte-identical messages.

## RSCF configuration

RSCF has exactly one required `config` section containing one 64-byte record:

| Word | Field |
| ---: | --- |
| 0 | optimization level |
| 1 | flags: debug, PIC, deterministic, runtime module |
| 2 | code model |
| 3 | relocation model |
| 4 | debug format |
| 5 | CPU baseline |
| 6 | enabled CPU features low mask |
| 7 | enabled CPU features high mask |
| 8 | maximum output bytes |
| 9 | maximum diagnostic bytes |
| 10 | worker count; v1 requires 1 |
| 11 | deterministic seed; v1 requires 0 |
| 12-15 | reserved, zero |

Limits are checked before allocation. Optimization level selects a pass
pipeline, not a different RSIR schema.

## RSIR semantic module

An RSIR message represents one complete relocatable module. Runtime and user
code may be separate modules and are joined later as RSCG objects. This is
required for a statically embedded, precompiled release runtime.

### Deliberately absent state

The following current machine-IR fields are derived in Red/System and are not
serialized:

- memory version/state in and out;
- optimizer scalar SSA, phi nodes, and dominance sets;
- propagated dynamic stack state;
- CPU condition-flag values;
- liveness, safepoint root lists, intervals, and allocations;
- local/frame offsets and spill locations;
- direct emitter bytes, fallback reasons, and selected-byte ranges.

RSIR instead carries typed operations, effect flags, alias identities, explicit
stack operations, and GC kinds. The codegen verifier constructs and checks the
derived state before optimization.

### Required section model

The numeric IDs and exact layouts below remain draft until the semantic coverage
matrix is complete. All listed records consist only of 32-bit words.

| Kind | Section | Bytes | Purpose |
| ---: | --- | ---: | --- |
| 1 | module | 32 | module lifecycle and entry symbols |
| 2 | data-layout | 32 | target sizes and alignments |
| 3 | strings | 8 | slices into string-data |
| 4 | string-data | 1 | UTF-8 bytes, no terminators |
| 5 | files | 16 | source path and optional checksum slice |
| 6 | types | 40 | nominal and representation types |
| 7 | fields | 32 | aggregate members and offsets |
| 8 | signatures | 32 | return type, convention, attributes |
| 9 | parameters | 32 | ordered signature parameters |
| 10 | symbols | 32 | named declarations and definitions |
| 11 | constants | 32 | scalar, byte, aggregate, address, or zero |
| 12 | constant-data | 1 | raw scalar and aggregate bytes |
| 13 | constant-parts | 32 | nested values and symbolic address parts |
| 14 | globals | 32 | storage class and initializer |
| 15 | imports | 24 | library/external name/symbol mapping |
| 16 | exports | 16 | external name/symbol/ordinal mapping |
| 17 | functions | 40 | signature and owned record ranges |
| 18 | locals | 32 | arguments, locals, temporaries, GC kind |
| 19 | blocks | 32 | instruction and outgoing-edge ranges |
| 20 | edges | 24 | source, target, edge kind, case value |
| 21 | values | 24 | typed single-definition temporary results |
| 22 | instructions | 48 | opcode, results, operands, effects, source |
| 23 | operands | 16 | typed references with opcode-specific aux |
| 24 | calls | 32 | callee, signature, call attributes |
| 25 | target-fragments | 32 | target-bound `#inline` byte slices |
| 26 | source-locations | 16 | file, line, column, byte offset |
| 27 | exception-regions | 24 | protected set, handler, and semantics |
| 28 | exception-blocks | 8 | region-to-block membership |

The important record shapes are:

- `module`: name string, flags, initializer function, finalizer function, entry
  function, initialization priority, source location, reserved. Runtime, user,
  and startup-glue modules therefore expose composable lifecycle functions.
- `types`: kind, flags, size, alignment, name string, element type, element
  count, first field, field count, GC kind. Signedness is a type flag.
- `signatures`: calling convention, flags, return type, first parameter,
  parameter count, logical arity, source location, reserved.
- `parameters`: signature, name string, type, flags, ordinal, runtime debug type
  code, source location, reserved.
- `symbols`: name string, kind, linkage, visibility, type/signature, flags,
  owner symbol, source location.
- `constants`: type, kind, flags, data offset, data size, first part, part count,
  auxiliary value. Integer and float bits live in `constant-data`.
- `constant-parts`: parent constant, byte offset, type, part kind, child constant,
  target symbol, raw-addend data offset, flags.
- `functions`: symbol, signature, flags, first block, block count, entry block,
  first local, local count, source location, reserved.
- `locals`: function, name string, type, kind, flags, alignment, source location,
  ordinal. There is no frame-offset hint.
- `edges`: source block, target block, edge kind, selector constant, ordinal,
  flags. Edge kinds cover normal, true, false, switch case, default, exception,
  and unreachable continuation.
- `values`: definition kind, definition record ID, result ordinal, type, owning
  function, flags. Definition kinds include parameter and instruction. Values
  are single-definition expression temporaries, but mutable locals and synthetic
  merge slots remain explicit loads/stores in RSIR. Codegen promotes them and
  constructs scalar SSA.
- `instructions`: block, opcode, subopcode, flags, first result, result count,
  first operand, operand count, effect flags, alias kind, alias ID, source
  location.
- `operands`: kind, referenced ID, auxiliary ID/value, flags. Immediates name
  constants; opcode-specific auxiliary fields never contain host values.
- `calls`: instruction, signature, callee kind, callee symbol/value, flags,
  first logical argument operand, argument count, reserved.
- `target-fragments`: target, ABI, byte offset, byte size, return type, effect
  flags, clobber class, source location. Bytes live in `constant-data`.

Core instruction families include constants and copies, conversions, integer
and floating arithmetic, comparisons, aggregate construction/copy, address
calculation, typed loads/stores, atomics, calls, branches, switch, returns,
exception control, keepalive, explicit stack push/pop, custom calls, port I/O,
and a target-fragment escape. ABI aggregate classes and physical argument
locations are computed from types and signatures by codegen and never appear in
RSIR.

`#inline` fragments are valid only when their target and ABI equal the message
header. With the current source syntax they are conservatively modeled as an
opaque memory/control barrier with caller-clobbered registers, unchanged stack
depth, and an optional conventional return value. Codegen spills live allocated
values around the fragment. A future source-level clobber/effect declaration may
narrow this behavior, but v1 never infers safety by decoding arbitrary bytes.

### RSIR semantic verification

After structural verification, both implementations enforce at least these
invariants:

- every ID exists, has the expected record kind, and belongs to the stated
  function/module;
- owned record ranges are contiguous, nonoverlapping, and agree in both
  directions;
- every block has exactly one final terminator and its edge set matches that
  terminator;
- temporary values have one definition and each direct use is dominated by that
  definition; cross-edge values pass through typed mutable/merge slots;
- instruction operands/results and constant parts satisfy opcode type rules;
- call arguments match the signature, including variadic, typed, custom,
  callback, indirect-call, and aggregate-return attributes;
- aggregate fields and initializer parts fit their type layout without overlap;
- effect/alias annotations agree with the opcode and cannot understate a call,
  volatile access, atomic, trap, throw, or safepoint;
- explicit stack operations are balanced on all ordinary exits, with dynamic
  counts represented by typed values;
- managed pointer and handle types retain their GC kind through conversions;
- target fragments match the target/ABI, remain in bounds, and carry the
  conservative effect and clobber contract required by their instruction.

## RSCG relocatable code object

RSCG is not an executable image. It is a target-specific object designed to be
merged with other RSCG objects and then adapted to the current Red linker.

| Kind | Section | Bytes | Purpose |
| ---: | --- | ---: | --- |
| 1 | data-layout | 32 | target identity and layout |
| 2 | strings | 8 | slices into string-data |
| 3 | string-data | 1 | UTF-8 bytes |
| 4 | output-sections | 32 | code/data/rodata/bss/platform sections |
| 5 | output-data | 1 | concatenated initialized section bytes |
| 6 | symbols | 40 | definitions and unresolved declarations |
| 7 | relocations | 32 | typed source-to-symbol fixups |
| 8 | imports | 24 | library/external name/symbol mapping |
| 9 | exports | 16 | external name/symbol/ordinal mapping |
| 10 | functions | 40 | code/frame/debug extents |
| 11 | files | 16 | source files |
| 12 | debug-lines | 20 | function-relative code positions |
| 13 | debug-parameters | 16 | runtime argument type metadata |
| 14 | gc-frames | 24 | final frame bitmap location and flags |
| 15 | unwind-functions | 24 | optional platform unwind record ranges |

Record shapes:

- `output-sections`: name string, class, flags, alignment, data offset, file
  size, memory size, reserved. BSS has file size zero. Platform sections allow
  later `.pdata`, `.xdata`, `.eh_frame`, and similar data without changing the
  container model.
- `symbols`: name string, kind, binding, visibility, output section, section
  offset, size, alignment, flags, origin-module ID. Section zero denotes an
  absolute or unresolved symbol as determined by flags.
- `relocations`: source section, source offset, relocation kind, target symbol,
  raw-addend-lo, raw-addend-hi, encoded width, flags.
- `functions`: symbol, code section, code offset, code size, frame size, flags,
  first debug line, debug line count, first debug parameter, parameter count.
- `debug-lines`: function, function-relative code offset, file, line, column.
- `gc-frames`: function, bitmap section, bitmap offset, bitmap size, flags,
  reserved. The actual bitmap is already in output data and is also reachable
  through the compatibility symbol expected by the runtime.

The codegen emits final GC bitmap bytes and all prolog/data relocations needed
to reference them. Structured GC records do not replace those runtime bytes.
Unwind sections are optional until the corresponding target and linker support
exists; v1 must match current Windows x64 behavior rather than invent metadata
the linker silently drops.

### Multi-object merge

The Red merger accepts an ordered list of verified RSCG objects. It aligns and
concatenates output sections, remaps local IDs, resolves symbols by binding and
name, adjusts relocation source offsets, rejects duplicate strong definitions,
and preserves unresolved imports. Runtime, generated Red/System, user modules,
and optional support modules therefore use the same object model.

The release runtime cache key includes at least schema fingerprint, compiler
build, target, ABI, pointer size, output kind, runtime/debug/PIC flags,
optimization level, CPU feature set, and a digest of all runtime preprocessor,
GUI, module-set, and job configuration inputs. A mismatch is a hard cache miss,
never best-effort reuse.

An RSCG runtime object is not enough to skip runtime source loading: the runtime
prolog also seeds the Red frontend's types, functions, aliases, globals, managed
handle kinds, namespaces, enumerations, and preprocessor definitions. The
runtime cache bundle therefore also carries a versioned Red-only frontend
interface manifest. It is declarative rather than a snapshot of Red series or
bindings, is keyed and fingerprinted with the RSCG object, and is imported before
user semantic analysis. The routine protocol does not consume this manifest.

Existing startup generation opens a target-specific root frame around runtime
and user global code. Cached modules cannot preserve an open byte range. Runtime
and user global code are therefore lowered to explicit lifecycle functions, and
the Red frontend emits a small startup-glue RSIR module that calls them in the
declared order and owns the final `***_start`/DLL entry symbol.
Program-specific Redbin boot payload and `red/sys-global` data/code belong to a
generated user or glue object and are never baked into the shared runtime cache.

### Existing linker adapter

The first adapter deliberately supports the current linker instead of replacing
it. It converts verified RSCG data as follows:

- code, rodata, and data output sections become `job/sections` buffers;
- defined symbols become legacy `native`, `native-ref`, `global`, or `constant`
  entries as required;
- zero-based code relocations become the linker's one-based code reference
  positions;
- data and rodata pointer relocations become the legacy fourth symbol field,
  including its negative-rodata convention;
- import relocations rebuild each library's callsite list and distinguish
  function from variable imports;
- exports rebuild the current internal-symbol/external-name pairs;
- debug lines and function argument metadata populate `job/debug-info` without
  consulting `system-dialect/compiler/functions`;
- final image resources and external C object processing remain linker-owned.

Every supported relocation kind has a documented mapping test. The adapter
rejects a relocation it cannot represent; it never drops one. A later typed
linker ingestion path may remove these legacy encodings without changing RSCG.

## RSDG diagnostics

RSDG contains `strings`, `string-data`, and 40-byte `diagnostics` records. A
diagnostic record contains status code, severity, phase, message string, file,
line, column, function symbol, instruction ID, and flags. IDs unavailable due to
early validation failure are zero.

Routine return statuses are coarse and stable: success, invalid arguments,
invalid configuration, invalid RSIR, unsupported target/feature, codegen
failure, and invalid generated artifact. Detailed failures belong in RSDG.
Out-of-memory remains a host runtime failure if the Red runtime cannot append
the completed native arena.

## Routine bridge

The initial entry point is status-returning and buffer-mutating:

```red
codegen-module: routine [
    ir          [binary!]
    config      [binary!]
    artifact    [binary!]
    diagnostics [binary!]
    return:     [integer!]
]
```

A `binary!` argument is passed as a `red-binary!` cell, not as raw bytes. The
routine obtains the current head with `binary/rs-head` and the visible length
with `binary/rs-length?`.

Bridge preconditions and memory rules are:

1. All four series nodes are distinct. Artifact and diagnostics are empty and
   at head zero. Aliasing is rejected before either output is cleared.
2. The routine snapshots input heads and lengths, validates both headers, and
   checks RSIR/RSCF target equality.
3. While a pointer into a Red series is live, codegen calls no Red runtime API
   that can allocate or trigger GC. Decode tables are zero-copy where useful;
   derived state and output use Red/System native arenas only.
4. The complete RSCG or RSDG message is built and self-verified in a native
   arena. The input pointer is no longer used before committing output.
5. Success performs one `binary/rs-append` to artifact and leaves diagnostics
   empty. Failure leaves artifact empty and performs at most one append of a
   complete RSDG message. Native arenas are then released.
6. No pointer into any Red series or native arena survives the routine return.

The routine is compiled into the release compiler. It does not introduce a
`libRedRT.dll` dependency; development builds follow the compiler's existing
runtime arrangement.

## Freeze criteria

Version 1 can be frozen only after all of the following are true:

- every legacy frontend-to-emitter call is classified in the semantic coverage
  matrix and represented in RSIR or explicitly linker-owned;
- Win64 scalar, aggregate, callback, variadic, typed/custom call, atomic,
  import-variable, target-fragment, GC, debug, and exception probes pass without
  legacy state;
- Red and Red/System structural/semantic verifiers agree on valid and malformed
  fixture corpora;
- one RSCG object can be serialized, reloaded, merged, and linked with no access
  to frontend/compiler objects;
- the schema constants and fingerprint are generated reproducibly and checked
  during bootstrap;
- no `rsir` execution path can invoke or copy bytes from the legacy emitter.
