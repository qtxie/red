# Hybrid Compiler Wire Protocol

Status: design draft. Version 1 is not frozen and no compatibility promise is
made until every Red/System semantic feature has an owner and a wire encoding.

See also [the execution plan](hybrid-codegen-plan.md) and
[the backend ownership audit](compiler-backend-ownership.md).

The authoritative draft schema is `compiler/wire-schema-spec.red`.
`tools/self_hosting/generate-wire-schema.red` validates it and generates the
checked-in Red constants at `compiler/wire-schema.red` and Red/System constants
at `system/codegen/wire-schema.reds`. Regenerate and test it with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-schema.red
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-schema-test.red
```

The test rejects generated-file drift and malformed schema definitions. A
separate Stage1-built Red/System smoke fixture includes the generated `#enum`
and checks its version, magic, common layout, and fingerprint at runtime.

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
| canonical representation types, target data layout, typed CFG, constants, imports, exports | RSIR |
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
| 12 | 4 | container flags, zero in v1.0 |
| 16 | 4 | total message size, exactly the input binary length |
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

`RSIR`, `RSCF`, and `RSCG` require a nonzero target and ABI. `RSDG` may use an
all-zero target/ABI/endian/pointer/features tuple when the input failed before
target validation. A partially zero tuple is invalid. The RSIR and RSCF target,
ABI, pointer size, and both feature-mask words must match exactly.

The schema fingerprint is generated from the complete checked-in schema
manifest, including enums, records, and message section profiles. It detects a
compiler built with mismatched Red and Red/System schema constants; it is not a
content checksum. The generator takes the first 32 SHA-256 bits and clears the
high bit so the value is always representable as a Red/System `integer!`. It
constructs that signed-31-bit value bytewise and never passes through an
overflowed or floating-point intermediate.

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
An empty section has offset, byte size, and record count zero while retaining
its profile-defined record size and alignment. Known word-record sections have
alignment 4 and known byte sections alignment 1. Unknown optional sections use
a nonzero power-of-two alignment and nonzero record size.

Directory records are in strictly increasing kind order. Nonempty payloads
occur in that same order after the complete directory; each fits inside the
declared message size and begins at its declared alignment. Payloads cannot
overlap or move backwards. Every byte between the directory and payloads,
between payloads, or after the final payload is zero padding.

In v1.0, all 30 listed RSIR sections are required even when empty. RSCF requires
its config section. RSCG requires kinds 1 through 16, including a nonempty
`modules` table; kind 17 `unwind-functions` is known optional and carries the
OPTIONAL flag when present. RSDG requires all three listed sections to be
nonempty, including at least one string, one byte of string data, and one
diagnostic record. Its smallest valid v1 message is therefore 212 bytes.

A major-version mismatch is fatal. A reader may accept an older or equal minor
version only when it understands all required sections and flags. Producers
emit tables in their specified stable order and zero every reserved field, so
identical inputs and options produce byte-identical messages.

### Checked implementations

`compiler/wire-container.red` and `system/codegen/wire-reader.reds` implement
the common-container checks independently. The native reader performs no
unaligned integer loads: it reads bytes only after the header or directory range
has been proved, uses checked signed-31-bit addition and multiplication, and
exposes `find-verified-section` only for a buffer that has already passed the
full verifier. This layer validates container structure, not RSIR graph/type
semantics.

The Red corpus builds and pins minimal RSCF, RSIR, RSCG, and RSDG byte streams,
two forward-compatibility positives, 39 directed malformed cases, and every
proper truncation of the four core messages. Its generated Red/System test
embeds exactly those bytes and compares error code, byte offset, and section
ordinal from the independent native verifier. Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-container-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-container-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-container-reds-test.exe `
    tools\self_hosting\tests\wire-container-reds-test.reds
build\self-hosting\wire-container-reds-test.exe
```

The generated test carries a SHA-256 over its Red corpus source, generator, and
schema fingerprint. The ordinary Red test rejects a stale cross-language
fixture before it can silently lose a newly added malformed case.

## RSCF configuration

RSCF has exactly one required `config` section containing one 64-byte record:

| Word | Field |
| ---: | --- |
| 0 | optimization level |
| 1 | flags: debug, PIC, deterministic |
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

The first v1 backend accepts only this target configuration:

- header tuple `X86_64`, `WIN64`, `LITTLE`, pointer size 8;
- optimization level `O0`, `O1`, or `O2`;
- the three defined config flag bits and no others;
- code model `SMALL`, relocation model `STATIC` or `PIC`, and debug format
  `NONE` or `RED`;
- CPU baseline `X86_64_BASE`.

The config feature masks must equal the header feature masks. Both masks are
zero in v1 until individual x86-64 feature bits and their legality rules are
specified; a matching nonzero pair is therefore unsupported rather than
silently ignored. `DEBUG` is set exactly when the debug format is `RED`, and
`PIC` is set exactly when the relocation model is `PIC`. `DETERMINISTIC` is the
only remaining independent config flag. Worker count is 1, deterministic seed
is 0, and all four reserved words are zero. Runtime-module identity is carried
by the RSIR/RSCG module records, not by a configuration bit.

`max-output-bytes` is at least `WIRE_RSCG_MINIMUM_SIZE` (currently 640).
`max-diagnostic-bytes` is either zero, which disables a detailed RSDG result,
or at least `WIRE_RSDG_MINIMUM_SIZE` (currently 212). These minima are derived
from the schema profiles by the generator rather than duplicated in either
verifier.

`compiler/wire-rscf.red` and `system/codegen/wire-rscf.reds` implement the
RSCF semantic checks independently. Validation is deterministic and stops at
the first error: arguments, common container, target tuple, all 16 signed
31-bit config words in record order, enum/flag domains, baseline and feature
masks, allocation limits, worker/seed/reserved words, then debug and PIC
consistency. A common-container failure becomes `RSCF_ERROR_INVALID_CONTAINER`
while retaining its container error and exact location. Header errors use
section 0; config errors use section ordinal 1 and the exact field byte offset.
The output config is written only after complete success.

The Red test covers four valid configurations and 28 directed semantic
failures. Its generated Red/System test embeds the same bytes, compares RSCF
and nested container errors plus byte locations, checks invalid pointers, and
proves that failures do not modify the output config. Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-rscf-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-rscf-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-rscf-reds-test.exe `
    tools\self_hosting\tests\wire-rscf-reds-test.reds
build\self-hosting\wire-rscf-reds-test.exe
```

## Windows x64 data layout

RSIR and RSCG each contain one required 32-byte `data-layout` record. It is a
target contract, not a per-type layout table:

| Word | Field | Windows x64 v1 |
| ---: | --- | ---: |
| 0 | address unit in bytes | 1 |
| 1 | pointer size | 8 |
| 2 | pointer alignment | 8 |
| 3 | external call-stack alignment | 16 |
| 4 | maximum natural scalar alignment | 8 |
| 5 | maximum natural aggregate alignment | 8 |
| 6 | integer register width | 8 |
| 7 | flags | 0 |

The scalar and aggregate values are maxima, not a requirement that every value
be 8-byte aligned. For example, the current Windows x64 layout keeps a
one-byte-only struct at size/alignment 1 while pointers, `int64!`, and
`float64!` reach alignment 8. The independent 16-byte value is the Win64 call
stack constraint. This distinction is why the earlier placeholder tuple with
`max-scalar-alignment = 16` was rejected rather than frozen.

The containing header is `X86_64`, `WIN64`, `LITTLE`, pointer size 8, with both
feature masks zero. The record pointer size must equal the header pointer size.
All eight payload words are decoded as signed-31-bit scalars before field
semantics are checked, and flags are zero in v1. `compiler/wire-data-layout.red`
and `system/codegen/wire-data-layout.reds` implement this contract independently
for both message types. The output layout is published only after complete
success. Payload failures report the verified directory ordinal, which is 2
for RSIR and 1 for RSCG, plus the absolute byte offset.

The Red corpus covers three valid messages (RSIR, RSCG, and RSCG with its known
optional section) and 26 directed failures. Its generated Red/System test uses
the same bytes and also proves that failures do not modify the output layout.
Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-data-layout-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-data-layout-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-data-layout-reds-test.exe `
    tools\self_hosting\tests\wire-data-layout-reds-test.reds
build\self-hosting\wire-data-layout-reds-test.exe
```

## Canonical strings and source metadata

RSIR, RSCG, and RSDG use the same canonical string-table contract. String IDs
are one-based and zero means absent. The `strings` section carries exactly the
SORTED and DEDUPLICATED flags; `string-data` has zero flags. Every record is an
`(offset, size)` slice relative to `string-data`, and the slices cover that byte
section from offset zero to its end without a gap, overlap, or unreferenced
trailing byte.

String bytes are strict UTF-8 without terminators or embedded NUL bytes. Readers
reject overlong encodings, UTF-16 surrogate code points, code points above
`U+10FFFF`, bare continuation bytes, invalid lead bytes, and truncated 2-, 3-,
or 4-byte sequences. Strings are strictly increasing by their raw canonical
UTF-8 bytes. An explicit empty string is optional; when present it is the sole
zero-length record, ID 1, with slice `(0, 0)`. An entirely empty string table is
also valid for RSIR and RSCG. RSDG is the profile exception: both its `strings`
and `string-data` sections are nonempty because every diagnostic must carry a
nonempty message.

RSIR and RSCG use the same file table. The `files` section carries exactly the
SORTED and DEDUPLICATED flags and is strictly ordered by path string ID. A path
ID is nonzero, in range, and names a nonempty canonical string. Duplicate paths
are invalid. `file-checksum-data` is a zero-flag raw byte section. Checksum kind
0 is NONE and requires offset and size zero. Kind 1 is SHA-256 and requires a
32-byte slice. SHA-256 slices occur contiguously in file-record order and cover
the checksum byte section exactly. The verifier checks representation and
coverage, not the digest against source bytes that are not part of the message.

RSIR source-location IDs are one-based and zero means absent at reference
sites. Every actual 16-byte source-location record names a valid file, has line
and column at least 1, and has a zero-based byte offset. The section carries
exactly the SORTED and DEDUPLICATED flags and is strictly ordered by
`(file ID, byte offset, line, column)`. RSCG has no source-location table;
its final debug-line records reference file IDs directly.

`compiler/wire-string-table.red` and
`system/codegen/wire-string-table.reds` independently enforce string
canonicalization. `compiler/wire-file-source.red` and
`system/codegen/wire-file-source.reds` independently enforce files, checksums,
and source locations. Both native readers are allocation-free, expose views
only after complete success, and preserve exact nested errors and absolute byte
locations. The Red corpora currently cover four valid string tables with 30
malformed cases and four valid file/source messages with 34 malformed cases.
Run the cross-language suites with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-string-table-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-string-table-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-string-table-reds-test.exe `
    tools\self_hosting\tests\wire-string-table-reds-test.reds
build\self-hosting\wire-string-table-reds-test.exe

D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-file-source-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-file-source-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-file-source-reds-test.exe `
    tools\self_hosting\tests\wire-file-source-reds-test.reds
build\self-hosting\wire-file-source-reds-test.exe
```

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
| 6 | file-checksum-data | 1 | raw source checksum bytes |
| 7 | types | 40 | canonical representation types |
| 8 | fields | 32 | aggregate members and offsets |
| 9 | signatures | 32 | return type, convention, attributes |
| 10 | parameters | 32 | ordered signature parameters |
| 11 | symbols | 32 | named declarations and definitions |
| 12 | constants | 32 | scalar, byte, aggregate, address, or zero |
| 13 | constant-data | 1 | constant-owned prefix followed by target-fragment bytes |
| 14 | constant-parts | 32 | nested values and symbolic address parts |
| 15 | constant-bindings | 8 | named constant symbol to constant mapping |
| 16 | globals | 32 | storage class and initializer |
| 17 | imports | 24 | library/external name/symbol mapping |
| 18 | exports | 16 | external name/symbol/ordinal mapping |
| 19 | functions | 40 | signature and owned record ranges |
| 20 | locals | 32 | arguments, locals, temporaries, merge slots |
| 21 | blocks | 32 | instruction and outgoing-edge ranges |
| 22 | edges | 24 | source, target, edge kind, case value |
| 23 | values | 24 | typed single-definition temporary results |
| 24 | instructions | 48 | opcode, results, operands, effects, source |
| 25 | operands | 16 | typed references with opcode-specific aux |
| 26 | calls | 32 | callee, signature, call attributes |
| 27 | target-fragments | 32 | ordered target-bound `#inline` descriptors |
| 28 | source-locations | 16 | file, line, column, byte offset |
| 29 | exception-regions | 24 | protected set, handler, and semantics |
| 30 | exception-blocks | 8 | region-to-block membership |
| 31 | subroutines | 32 | host-owned subroutine declarations |
| 32 | subroutine-blocks | 8 | subroutine-to-block membership |

The important record shapes are:

- `module`: optional name string, module kind, image kind, initializer function,
  finalizer function, entry function, source location, and zero flags. Module
  kind is one of `RUNTIME`, `USER`, `SUPPORT`, or `GLUE`; image kind is one of
  `EXECUTABLE` or `DYNAMIC_LIBRARY`. A zero function ID means absent. RSIR has
  exactly one module record. A non-glue module must not have an entry function;
  a glue module must have exactly one entry and must not also declare an
  initializer or finalizer. A non-glue initializer and finalizer may each be
  absent or present. Anonymous modules use name ID zero; nonzero names must be
  nonempty canonical strings. There is no implicit initialization priority.
  Lifecycle fields declare module-owned functions for validation and object
  discovery; the startup glue's explicit call graph is the authority for actual
  initialization and finalization order.
- `types`: kind, flags, size, alignment, reserved, kind-specific detail ID,
  reserved, first field, field count, GC kind. Signedness is a type flag;
  source names and aliases are not part of a representation record.
- `signatures`: calling convention, flags, return type, first parameter,
  parameter count, logical arity, source location, reserved.
- `parameters`: signature, name string, type, flags, ordinal, runtime debug type
  code, source location, reserved.
- `symbols`: name string, kind, linkage, visibility, type/signature, flags,
  owner symbol, source location.
- `globals`: symbol, type, initializer constant, alignment, storage class,
  flags, source location, reserved.
- `imports`: library string, external-name string, local symbol, effective
  calling convention, flags, source location.
- `exports`: external-name string, local symbol, ordinal, flags.
- `constants`: type, kind, flags, data offset, data size, first part, part count,
  auxiliary value. Integer and float bits live in the constant-owned prefix of
  `constant-data`.
- `constant-parts`: parent constant, byte offset, type, part kind, child constant,
  target symbol, raw-addend data offset, flags.
- `constant-bindings`: constant symbol and its value constant.
- `functions`: symbol, signature, flags, first block, block count, entry block,
  first local, local count, source location, reserved.
- `locals`: function, name string, type, kind, flags, alignment, source location,
  ordinal. There is no frame-offset hint.
- `edges`: source block, target block, edge kind, selector constant, ordinal,
  flags. V1 accepts normal, true, false, switch case, default, and exception
  edges. The `UNREACHABLE` enum value is reserved but rejected; unreachable
  continuations use blocks and terminators rather than a synthetic edge kind.
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
- `calls`: instruction, signature, callee kind, callee descriptor operand, flags,
  first logical argument operand, argument count, reserved.
- `target-fragments`: target, ABI, byte offset, byte size, return type, effect
  flags, clobber class, source location. Their ordered byte slices form the
  complete suffix of `constant-data` after the constant-owned prefix.
- `exception-regions`: function, first membership record, membership count,
  handler block, region kind, flags. Region kinds are `FILTER` and `FUNCTION`;
  `CATCH_ALL` is the sole flag.
- `exception-blocks`: exception region and protected block. These records form
  the contiguous membership slices owned by `exception-regions`.
- `subroutines`: host function, nonempty name string, effective signature,
  entry block, first block-membership record, block-member count, source
  location, and zero flags.
- `subroutine-blocks`: subroutine and member block. These records form the
  contiguous membership slices owned by `subroutines`.

Core instruction families include constants and copies, conversions, integer
and floating arithmetic, comparisons, aggregate construction/copy, address
calculation, typed loads/stores, atomics, calls, branches, switch, returns,
exception control, keepalive, explicit stack push/pop, custom calls, port I/O,
stack/frame address reads, current-PC capture, x64 CPU-register access, and a
target-fragment escape. ABI aggregate classes and physical argument locations
are computed from types and signatures by codegen and never appear in RSIR.

### Canonical type and aggregate layout

The v1 `types` table carries backend representation identity, not Red/System
source syntax. Type IDs are one-based wire identities. The producer interns a
source type to one canonical ID and later `TYPE` symbols map source alias names
to that ID. The verifier does not attempt recursive structural deduplication or
graph isomorphism. In particular, transparent scalar aliases share their
representation type, while the nominal `node-handle!` property is preserved by
using a signed 4-byte integer record whose GC kind is `HANDLE`.

There are exactly eight type kinds:

| Kind | Flags | Size/alignment | Detail ID | Fields | GC kind |
| --- | --- | --- | --- | --- | --- |
| `VOID` | 0 | 0 / 0 | 0 | none | `NONE` |
| `LOGIC` | 0 | 4 / 4 | 0 | none | `NONE` |
| `INTEGER` | 0 or `SIGNED` | 1, 2, 4, or 8; alignment equals size | 0 | none | `NONE`, or `HANDLE` only for signed size 4 |
| `FLOAT` | 0 | 4 / 4 or 8 / 8 | 0 | none | `NONE` |
| `POINTER` | 0 or `C_STRING` | 8 / 8 | required type ID | none | `POINTER` |
| `FUNCTION` | 0 | 8 / 8 | required signature ID | none | `POINTER` |
| `STRUCT` | 0 | recomputed natural layout | 0 | nonempty owned range | `NONE` |
| `UNION` | 0 or `TAGGED` | recomputed natural layout | tag type ID only when tagged | nonempty owned range | `NONE` |

Both reserved type words are zero. `first-field` and `field-count` are zero for
nonaggregates. Every struct or union owns a nonempty contiguous range. A pointer
detail may refer to itself or a later type, which permits recursive reference
graphs, but it is never zero, out of range, or `VOID`. `C_STRING` is the
semantic distinction between a NUL-terminated byte string and an ordinary byte
stream; its detail names an unsigned one-byte integer. Function detail names a
signature record. Full signature semantics are verified by the later
function/signature contract rather than duplicated here.

Source `struct!` and `union!` values are references unless their type
specification ends in `value`. The RSIR producer therefore serializes a
reference as `POINTER` to the canonical aggregate type and serializes only the
by-value representation as `STRUCT` or `UNION`. Every by-value aggregate field
whose type is itself `STRUCT` or `UNION` must name a smaller type ID than its
owner. Pointer edges may point forward. This single ordering rule rejects every
by-value cycle and lets the native reader recompute all aggregate layouts in one
forward, allocation-free pass.

Each 32-byte field record contains owner type, nonempty canonical name string,
type, byte offset, flags, zero-based ordinal, optional source location, and
reserved. Flags and reserved are zero in v1. Field records are contiguous in
owner and ordinal order, and ownership agrees in both directions. The frontend
already rejects duplicate source member names; the backend verifier checks
field-name representation but deliberately does not repeat name resolution.
This keeps verification linear in the number of types and fields.

Windows x64 struct layout starts at cursor zero. For each field in ordinal
order, its offset is the cursor rounded up to the field alignment, then its size
advances the cursor. Aggregate alignment is the maximum field alignment and
final size is the cursor rounded up to that alignment. Windows x64 raw-union
fields all have offset zero; size is the largest payload size rounded up to the
largest payload alignment.

A tagged union uses an unsigned tag of 1, 2, or 4 bytes for at most 255, 65535,
or more variants respectively. The runtime tag for field ordinal `n` is
`n + 1`, leaving zero as no active variant. The payload begins at the tag size
rounded up to the largest payload alignment; every variant has that same byte
offset. As in the existing Red/System ABI, the tag does not independently raise
union alignment. Thus a 256-variant union containing only one-byte payloads has
tag size 2, payload offset 2, alignment 1, and total size 3.

Literal Red/System blocks/binaries currently described internally as `array!`
are constant storage plus a pointer value, not fixed by-value array types; their
length and bytes belong in the constant tables. `packed` is an old emitter data
placement option, while `volatile` and `opaque` are instruction effect facts.
None is a type flag. Source custom struct alignment is not encoded in v1 and
requires an explicit future schema extension before it can be supported. These
facts must not be smuggled into either reserved type word.

`compiler/wire-type-layout.red` and
`system/codegen/wire-type-layout.reds` independently validate this contract.
The native reader performs no allocation or recursion and publishes string,
file, layout, and type views only after complete success. The shared corpus
covers three valid messages and 56 directed failures, including every error
code, all signed-31-bit fields, poisoned native outputs, recursive pointer and
by-value ordering, natural struct/raw/tagged-union layout, managed handles,
`c-string!`, and the 255-to-256 tag-width boundary. Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-type-layout-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-type-layout-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-type-layout-reds-test.exe `
    tools\self_hosting\tests\wire-type-layout-reds-test.reds
build\self-hosting\wire-type-layout-reds-test.exe
```

### Function signatures, parameters, definitions, and locals

`compiler/wire-function-signature.red` and
`system/codegen/wire-function-signature.reds` independently validate the
declaration and ownership layer needed before CFG and call verification. A
signature is a reusable semantic interface. A function record is only a body
definition; imports and bodyless declarations are represented by the later
symbol/import contract and never by a zero-block function record.

The effective calling convention is one of `RED_SYSTEM`, `CDECL`, `STDCALL`,
or `SYSCALL`. Source attribute `red-internal` is deliberately absent from the
wire format: it is legacy frontend state used while resolving an effective
interface, not a second calling-convention authority. A runtime-private export
therefore serializes as `RED_SYSTEM` without `CALLBACK`; a real external entry
callback serializes as `CDECL` or `STDCALL` with `CALLBACK`.

Signature flags are `VARIADIC`, `TYPED`, `CUSTOM`, `CALLBACK`, `NO_RETURN`, and
`MAY_THROW`. At most one of the first three is set. `CALLBACK` cannot be
combined with a variable-arity mode and is valid only with `CDECL` or
`STDCALL`. `SYSCALL` cannot be variable-arity or a callback. `NO_RETURN` and
`MAY_THROW` are declaration facts consumed by later control-flow and exception
verification; this layer validates their bits but does not infer them from a
partial function body.

Every signature owns a contiguous slice of the global parameter table. Empty
slices use `(first-parameter, parameter-count) = (0, 0)`; nonempty slices
partition the table in signature order. Parameter ordinals are zero-based
within the slice. Every parameter has a nonempty canonical name, a non-`VOID`
type, zero flags and reserved word, an optional valid source location, and a
runtime debug type code compatible with its canonical type.

`logical-arity` counts source-level arguments rather than physical ABI
operands:

| Signature mode | Logical arity |
| --- | ---: |
| fixed ordinary signature | parameter count |
| `CDECL VARIADIC` | named fixed-parameter count |
| `TYPED` | 0 |
| non-`CDECL VARIADIC` | 0 |
| `CUSTOM` | 0 |

The actual argument count for a variable call belongs to its later `RSIR_CALL`
record. `CUSTOM` always declares zero parameters: its one source expression is
the dynamic call-site count, not a callee formal. This remains true for JNI's
`CDECL`/`STDCALL CUSTOM` function pointers; the calling convention selects the
physical target ABI while `CUSTOM` selects the dynamic forwarding operation.

For packed calls, a definition may expose any leading prefix of the receiver
slots that the current targets pass. `TYPED` allows at most signed i32 `count`,
then any pointer `list`, independently of whether its effective convention is
`RED_SYSTEM`, `CDECL`, or `STDCALL`. Private `VARIADIC` allows at most signed
i32 `count`, any pointer `list`, then signed i32 `byte-size`. Omitted trailing
slots are legal because existing receivers do not always name every value.
`CDECL VARIADIC` is the sole exception: it is not a packed protocol, and its
parameter slice is the ordinary named C prefix. In particular, the new backend
does not preserve the legacy x64 emitter's accidental flat `CDECL TYPED`
triple expansion. The verifier checks representation types but does not encode
register, stack, or shadow-space locations.

Aggregate return types remain the semantic return type. A hidden ABI return
pointer is derived later by codegen and is never serialized as a parameter or
argument local, and it never changes `logical-arity`. This prevents frontend
ABI lowering from becoming a second source of physical argument truth.

Each function references an existing symbol and signature, has zero function
flags and reserved word in v1, owns at least one contiguous block, identifies
an entry inside that slice, and owns an empty or contiguous local slice.
Function slices partition both tables in function order. Blocks point back to
their owner, have zero record flags and reserved word, and carry an optional
valid source location. Their instruction and outgoing-edge ranges are decoded
as signed-31-bit scalars here; the control-flow contract below validates
terminators, edge sets, and range ownership.

Local kinds are `ARGUMENT`, `LOCAL`, `TEMPORARY`, and `MERGE`. Arguments and
ordinary locals require nonempty names; temporaries and merge slots may use
name ID zero. Every local has a non-`VOID` type, zero flags, a zero-based
ordinal in its function slice, and an optional source location. Alignment zero
means natural alignment. A nonzero override is a power of two, is no smaller
than the type alignment, and is no larger than the target stack alignment.
The first locals of every definition exactly mirror all signature parameters
by argument kind, name, and type; no later local may claim argument kind.

Runtime debug codes preserve the existing debugger interface rather than
duplicating canonical type IDs. Scalar codes are exact (`LOGIC` 1, signed i32
2, floats 4/5, signed/unsigned fixed integers 11-17); unsigned one-byte values
accept legacy `BYTE` 3 or `UINT8` 14. `C_STRING` is 6, function is 9, and
by-value aggregates are 100. Ordinary canonical pointers accept source-level
pointer aliases 7, 8, 10, or 100 because alias spelling is intentionally not
part of the representation type table.

Both verifiers decode every scalar field before following semantic references
and stop at the first error in the same order. Native outputs are failure
atomic: string, file, data-layout, type, and function views are copied only
after complete success. The shared corpus contains six valid messages and 105
directed malformed messages, covers all 55 error codes, every scalar field,
all runtime debug codes, packed-protocol prefixes, multiple functions sharing
a signature, poisoned outputs, null routine arguments, and exact error byte
locations. Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-function-signature-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-function-signature-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-function-signature-reds-test.exe `
    tools\self_hosting\tests\wire-function-signature-reds-test.reds
build\self-hosting\wire-function-signature-reds-test.exe
```

### Module lifecycle and object provenance

`compiler/wire-module-lifecycle.red` and
`system/codegen/wire-module-lifecycle.reds` independently validate RSIR module
metadata and RSCG multi-object provenance. RSIR contains exactly one module and
its lifecycle IDs refer to its function table. Each codegen result starts with
one corresponding RSCG module; the merger concatenates those records in input
order, remaps lifecycle symbol IDs, and sets every symbol's one-based
`origin-module`. A merged object may contain several modules but at most one
`GLUE` module. The final-image check happens only after all inputs are known:
an executable requires exactly one glue entry, while a DLL may have no entry or
one entry owned by its sole glue module. Standalone runtime, user, and support
objects therefore remain valid before final-image validation.

All modules in one RSCG use the same image kind. Non-glue modules cannot own an
entry symbol. A glue module owns exactly one entry and no initializer or
finalizer. Non-glue initializer and finalizer fields are independent. RSCG
lifecycle symbols must be owned by the module that names them. The later
function/symbol contract additionally proves that these IDs denote defined
functions with the required linkage and signatures; this verifier deliberately
does not duplicate those checks.

Both implementations validate in the same order and publish no views on
failure: arguments and container, canonical strings and source metadata,
signed scalar decoding, per-module domains and reference bounds, lifecycle
shape and common image kind, then RSCG symbol origins and lifecycle ownership.
The shared corpus has five valid messages and 24 directed malformed messages,
covering every module-lifecycle error code and exact error location. Run both
sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-module-lifecycle-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-module-lifecycle-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-module-lifecycle-reds-test.exe `
    tools\self_hosting\tests\wire-module-lifecycle-reds-test.reds
build\self-hosting\wire-module-lifecycle-reds-test.exe
```

### Symbols, imports, exports, and definition coverage

`compiler/wire-symbol-linkage.red` and
`system/codegen/wire-symbol-linkage.reds` independently validate the RSIR
identity and linkage layer after type, signature, function, and module
verification. This layer does not generate code and does not assign output
sections or final addresses. The native verifier is allocation-free and scans
the sorted tables monotonically; exported-definition lookup is logarithmic.

Symbol IDs are one-based records sorted by `(name-string ID, kind)`. Since the
string table is canonical, this is also bytewise name order. A fully qualified
namespace path uses `>` between source components. Names are nonempty. Kinds
are `FUNCTION`, `GLOBAL`, `CONSTANT`, and `TYPE`. A `TYPE` name may coexist with
one value name because the source language has separate type and value
namespaces. Two `TYPE` records with the same name, or any two value-kind records
with the same name, are duplicates.

Every function symbol names a signature; every other symbol names a non-`VOID`
canonical type. Symbol flags and `owner-symbol` are zero in v1. The source
location is optional. Linkage and visibility pairs are exact:

| Linkage | Visibility | Definition/import rule |
| --- | --- | --- |
| `LOCAL` | `HIDDEN` | function/global definition required |
| `INTERNAL` | `HIDDEN` | function/global definition required |
| `EXTERNAL` | `DEFAULT` | current-module definition or bodyless cross-module declaration |
| `IMPORT` | `DEFAULT` | exactly one import record and no definition |
| `WEAK` | `DEFAULT` | current-module definition required |

`CONSTANT` and `TYPE` symbols are always `LOCAL`. Only functions and globals
may be imports. Function and global definition tables are sorted by symbol ID,
contain no duplicate symbol, agree with the symbol's signature/type, and never
define an imported symbol. This contract verifies the identity prefix of each
global record, its source location, and its reserved word. The following
constants/globals contract owns initializer identity, requested alignment,
storage class, and global flags.

Imports are sorted and unique by local symbol ID. Several local symbols may map
to the same `(library, external-name)` pair, which preserves source aliases.
Library and external names are nonempty canonical strings. A function import's
effective convention must equal its signature and must be `RED_SYSTEM`,
`CDECL`, or `STDCALL`; `SYSCALL` is not a dynamic import convention. A variable
import uses calling convention zero. Import flags are zero in v1 and the source
location is optional.

A `SYSCALL` function is a bodyless `EXTERNAL` declaration, never an import and
never a function definition. Module initializer, finalizer, and entry IDs must
resolve to strong current-module function definitions; weak and imported
lifecycle functions are rejected. This is an ownership check only. The precise
lifecycle ABI and startup call order remain properties of the later glue and
call contracts.

Exports exist only in a `DYNAMIC_LIBRARY` RSIR module. Records are sorted by
external-name string ID; external names are nonempty and unique, while one
symbol may intentionally have several differently named exports. The local
symbol must be an `EXTERNAL` function or global with a current-module
definition. RSIR export ordinals and flags are zero: target-specific ordinal
assignment belongs to the final RSCG merge/linker step. An ordinary exported
function uses `CDECL` or `STDCALL` plus `CALLBACK`. The runtime module may also
export a private `RED_SYSTEM` function without `CALLBACK`, matching the current
`libRedRT` interface.

The `symbols`, `imports`, and `exports` sections carry both `SORTED` and
`DEDUPLICATED`; the global section has zero flags, like the function section,
and this layer proves its symbol-ID order and uniqueness. All fields in those
tables are decoded as signed-31-bit scalars before semantic references are followed. Both verifiers
stop at the same first error and publish string, file, layout, type, function,
module, and symbol views only after complete success. The shared corpus has
eight valid and 95 directed malformed RSIR messages. It covers all 69 status
codes, every field, exact byte locations, function and variable imports,
aliases, namespace names, weak definitions, external declarations, syscalls,
runtime-private and callback exports, lifecycle strength, null arguments, and
poisoned native outputs. Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-symbol-linkage-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-symbol-linkage-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-symbol-linkage-reds-test.exe `
    tools\self_hosting\tests\wire-symbol-linkage-reds-test.reds
build\self-hosting\wire-symbol-linkage-reds-test.exe
```

This verifier consumes RSIR only. Codegen later maps these semantic identities
to RSCG symbols, imports, and exports; RSCG binding resolution, origin-module
remapping, relocation ownership, final ordinals, and image-table construction
remain in the object merger and linker-adapter contracts.

### Constants, storage, and global initializers

`compiler/wire-constant-initializer.red` and
`system/codegen/wire-constant-initializer.reds` independently validate the
constant graph after symbol/linkage validation. This is still semantic RSIR:
it creates no output section, relocation ID, machine code, or legacy-emitter
byte range.

Constant IDs are one-based and topologically ordered. Every `VALUE` part names
a smaller constant ID, which makes by-value cycles impossible in a single
forward pass. A symbolic address edge is a delayed relocation and is not a
constant-graph cycle. There are five constant kinds:

| Kind | Representation |
| --- | --- |
| `ZERO` | typed all-zero value; no bytes, parts, or auxiliary value |
| `SCALAR` | exact type-size bytes for logic, integer, or float |
| `STORAGE` | pointer type plus element count and contiguous pointee bytes |
| `AGGREGATE` | one typed `VALUE` part per struct field, or one active union field |
| `ADDRESS` | one symbolic, constant-storage, or absolute address part |

Logic bytes are canonical little-endian 0 or 1 with the remaining three bytes
zero. Integer and float payloads preserve their exact bits. A `STORAGE`
constant's auxiliary word is a positive element count and its byte size is
exactly `count * pointee-size`. `C_STRING` storage has no parts, contains no
embedded NUL, and ends in one NUL. Other storage may overlay typed parts at
aligned, in-range, nonoverlapping offsets; every raw placeholder byte covered
by such a part is zero.

An aggregate has no direct byte slice. Struct parts follow field order and
match each field's exact type and byte offset. A union has exactly one part;
the auxiliary word is the selected field ID. Tagged-union tags are therefore
derived from the selected field ordinal (`ordinal + 1`), while `ZERO` is the
inactive tag-zero representation. Padding is implicitly zero rather than
serialized as an additional semantic part.

Part kinds are `VALUE`, `SYMBOL_ADDRESS`, `CONSTANT_ADDRESS`, and
`ABSOLUTE_ADDRESS`. A symbol address may target only a function, global, or
constant symbol. Function addresses use a `FUNCTION` type with the target
signature; global and constant addresses use a pointer whose pointee is the
target value type. A constant address targets only an earlier `STORAGE`
constant with the same pointer type. Absolute addresses use a pointer or
function type and must be nonzero; null is represented by `ZERO`.

Every non-`VALUE` part consumes exactly eight bytes from `constant-data` in
part order. Symbol and constant addends are canonical sign-extended 32-bit
values. Absolute addresses may use all 64 bits. These bytes describe an
address expression only; section placement and target relocation selection are
codegen responsibilities.

Constants, storage, and address addends consume one gap-free prefix of
`constant-data` in constant/part order. The constant verifier publishes the
exclusive end of that prefix as `constant-data-owned-size`. If there are no
target-fragment records, the prefix must cover the section. Otherwise the
target-intrinsic verifier requires ordered nonempty fragment slices to start at
that cursor and cover the complete remaining suffix without gaps or overlap.

Named constants use the separate `constant-bindings` table. It carries exactly
`SORTED | DEDUPLICATED`, is strictly ordered by symbol ID, has one entry for
every `CONSTANT` symbol, and preserves exact symbol/constant type equality.
This ordering is independent of the constant graph's topological order.

A global initializer ID of zero means implicit zero initialization. A nonzero
initializer has exactly the global's value type. Alignment zero means natural
type alignment; an explicit alignment is a power of two, is at least natural,
and does not exceed the target maximum aggregate alignment. The only v1 global
storage class is `MUTABLE`, and global flags are zero. A source-level protected
scalar is a frontend constant rather than mutable global storage; protected
addressable storage is represented by constant storage and a constant symbol.

Both verifiers decode every scalar field before following references, consume
their constant-data prefix and the part section without gaps, stop at the same
first error, and publish all lower and local views only after complete success.
The shared corpus contains three valid and 84 directed malformed messages,
covers all 67 status codes, exact byte locations, every scalar field, storage
overlays, struct/raw-union/tagged-union values, all address forms, missing
bindings, zero global initialization, null routine arguments, and poisoned
native outputs.
Run both sides with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-constant-initializer-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-constant-initializer-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-constant-initializer-reds-test.exe `
    tools\self_hosting\tests\wire-constant-initializer-reds-test.reds
build\self-hosting\wire-constant-initializer-reds-test.exe
```

### Values and scalar operations

`compiler/wire-scalar-operation.red` and
`system/codegen/wire-scalar-operation.reds` independently validate the three
tables that form the common instruction substrate, then interpret only scalar
opcodes 1 through 20. Opcodes 21 through 63 receive the common structural
checks here but remain semantically owned by their later feature verifiers.
This layer constructs no MIR, invokes no emitter, and emits no code bytes.

All three section flag words are zero. `VALUE_FLAG` and `OPERAND_FLAG` contain
only `NONE`. The only scalar instruction flag is `CHECKED`; all other bits are
invalid. Every scalar operand auxiliary word is zero. A scalar instruction has
alias `(NONE, 0)`. These closed domains prevent later consumers from assigning
private meanings to reserved words.

The instruction table is partitioned by blocks in block-table order. An empty
block uses `(first-instruction, instruction-count) = (0, 0)`; a nonempty block
starts at the next unowned instruction. Every instruction points back to that
block, and the block ranges cover the table exactly. Operand ranges similarly
partition the operand table in instruction order. Empty result and operand
ranges are always `(0, 0)`; every nonempty range is contiguous and in bounds.

Values are grouped by function in function-table order. A function first owns
one `PARAMETER` value for each signature parameter, in parameter/local ordinal
order. Its definition ID is the corresponding function-owned `ARGUMENT` local,
not a signature-parameter ID, and its result ordinal is zero. Those values are
followed by every instruction result in block/instruction/result order. An
instruction result value names that instruction and its zero-based result
ordinal. Types and function IDs agree in both directions, and the function
groups cover the value table exactly. This deterministic ordering avoids
adding redundant value ranges to function records.

Common operands are references, never embedded host values. `VALUE`, `BLOCK`,
and `LOCAL` references belong to the instruction's function. `CONSTANT`,
`SYMBOL`, `TYPE`, and `FUNCTION` name their respective module tables;
`TARGET_FRAGMENT` names that required section. Scalar operations accept only
`VALUE` operands, except `CONSTANT`, whose sole operand is `CONSTANT`.

The scalar shapes and type rules are:

| Opcode | Operands | Result | Type rule |
| --- | ---: | ---: | --- |
| `CONSTANT` | 1 | 1 | constant and result have the exact same type |
| `COPY` | 1 | 1 | operand and result have the exact same type |
| `CONVERT` | 1 | 1 | legal numeric, truth, or address conversion below |
| `BITCAST` | 1 | 1 | legal representation-preserving conversion below |
| `ADD`, `SUBTRACT` | 2 | 1 or 2 | integer/float arithmetic, or pointer-left address arithmetic |
| `MULTIPLY`, `DIVIDE` | 2 | 1 or 2 | matching integer representations or exact matching floats |
| `REMAINDER`, `MODULO` | 2 | 1 or 2 | matching integer representations only |
| `NEGATE` | 1 | 1 | integer or float |
| `BIT_NOT` | 1 | 1 | integer |
| `LOGIC_NOT` | 1 | 1 | exact canonical `LOGIC` |
| shifts | 2 | 1 or 2 | integer value plus signed i32 count |
| `BIT_AND`, `BIT_OR`, `BIT_XOR` | 2 | 1 | matching integers, or exact `LOGIC` |
| `COMPARE` | 2 | 1 | compatible integer, float, address, or logic pair; result is `LOGIC` |

Integer compatibility means equal size and signedness. GC kind does not change
the numeric representation: a `HANDLE` may be paired with its ordinary signed
i32 representation, but every arithmetic, bitwise, shift, or negate result is
the corresponding `GC_KIND/NONE` integer. No operation manufactures a handle.
Ordinary integer operands otherwise use one canonical representation type.
Floating operands and results have one exact type, f32 or f64; implicit source
coercions are serialized as explicit `CONVERT` instructions.

Canonicality here is the producer-side type-interning invariant defined by the
type-table contract. The scalar verifiers treat type IDs as representation
identities after type-layout verification; they do not rescan the table for
structurally duplicate scalar records.

Pointer arithmetic requires a `POINTER` left operand. With an ordinary integer
right operand, `ADD` and `SUBTRACT` multiply that integer by the verified
pointee size. With a `POINTER` right operand they perform raw byte-address
addition or subtraction without scaling. The result has the exact left pointer
type. Function addresses are not arithmetic values. Comparisons accept two
`POINTER` values or two `FUNCTION` values, use unsigned address ordering, and
return canonical `LOGIC`; crossing those categories requires an explicit
`BITCAST`. Logic comparisons permit all six
comparison kinds; `false < true` under its canonical 0/1 representation.

`REMAINDER` follows the dividend sign. `MODULO` is in `[0, abs(divisor))` for
a nonzero divisor. Integer divide, remainder, and modulo by zero are trapping.
Signed minimum divided by `-1` has the fixed-width minimum result, while its
remainder and modulo are zero; a checked form additionally reports overflow.
Float divide follows IEEE-754 rather than the integer trap rule. Float
comparisons are ordered: with a NaN, `NOT_EQUAL` is true and every other kind
is false.

The shift count has the canonical ordinary signed-i32 type. Its effective value
is the low `log2(bit-width)` bits, so counts are reduced modulo 8, 16, 32, or 64
for the left representation. `SHIFT_RIGHT` is arithmetic for signed integers
and logical for unsigned integers. `SHIFT_RIGHT_LOGICAL` always shifts the
fixed-width bit pattern logically. This semantics is independent of a target's
native shift masking.

`CONVERT` performs a value conversion and rejects identical source/result type
IDs. It permits ordinary integer width changes, logic to ordinary integer,
ordinary integer or address to logic by comparison with zero, signed i32
to/from f32 or f64, f32 to/from f64, and unequal-width ordinary integer to/from
pointer or function address. Narrowing truncates low bits; widening uses the
source integer signedness. Red/System deliberately does not define i64/u64
to/from float conversion. A pointer/function converted to a narrower integer
may therefore truncate.

`BITCAST` preserves bits and rejects identical types. It permits changes among
equal-width ordinary integer signedness, among pointer/function address types,
between an address and an equal-width ordinary integer, and between signed i32
and f32 for source `as ... keep`. Those equal-width cases are not also legal
`CONVERT` forms. `BITCAST` never accepts `LOGIC`, aggregates, unequal widths, or
a `HANDLE` source/result. Consequently neither conversion opcode can create,
discard, or disguise a managed handle.

`CHECKED` is valid only on integer `ADD`, `SUBTRACT`, `MULTIPLY`, `DIVIDE`,
`REMAINDER`, `MODULO`, and `SHIFT_LEFT`. Such an instruction owns two results:
ordinal zero is the ordinary fixed-width result and ordinal one is canonical
`LOGIC`, true exactly when the mathematical result is not representable in the
ordinary result type. Remainder and modulo also report overflow when their
associated signed division is signed-minimum divided by `-1`. Division by zero
remains a trap, not a checked result. The
frontend implements lexical `overflow?` early exit with explicit CFG using
this second result; the instruction flag carries no hidden control-flow state.

Effects are exact rather than lower bounds. Integer divide, remainder, and
modulo carry only `MAY_TRAP`. Floating arithmetic, floating comparison, and
numeric conversions involving float also conservatively carry only
`MAY_TRAP`, because the source exposes floating-point exception masks and
status. Every other scalar instruction has zero effects. `MAY_TRAP` does not
imply a memory alias, so every scalar alias remains `(NONE, 0)`.

Both verifiers first validate the complete scalar representation of all three
tables, then common references/ownership/ranges, then opcode semantics. They
stop at the same first error and publish lower plus scalar views only after
complete success. The shared corpus covers every status code, scalar record
field, reference domain, ordering rule, opcode family, checked shape, handle
boundary, pointer rule, conversion class, effect, and poisoned native output.
Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-scalar-operation-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-scalar-operation-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-scalar-operation-reds-test.exe `
    tools\self_hosting\tests\wire-scalar-operation-reds-test.reds
build\self-hosting\wire-scalar-operation-reds-test.exe
```

### Memory and aggregate operations

`compiler/wire-memory-aggregate.red` and
`system/codegen/wire-memory-aggregate.reds` consume the fully verified scalar
views and independently validate opcodes 21 through 31 plus 57 and 58. All
other non-scalar opcodes remain structurally valid but are deferred to their
own feature verifiers. This layer also constructs no MIR, invokes no emitter,
and emits no direct or machine-code bytes.

Every owned instruction has subopcode zero and instruction flags zero. Its
shape, exact base effect, and alias are:

| Opcode | Operands | Result | Effect | Alias |
| --- | --- | --- | --- | --- |
| `LOAD_LOCAL` | local | stored type | `READ` | `(LOCAL, local ID)` |
| `STORE_LOCAL` | local, value | none | `WRITE` | `(LOCAL, local ID)` |
| `ADDRESS_LOCAL` | local | ordinary pointer to stored type | none | `(NONE, 0)` |
| `LOAD_GLOBAL` | global symbol | stored type | `READ` | `(GLOBAL, symbol ID)` |
| `STORE_GLOBAL` | global symbol, value | none | `WRITE` | `(GLOBAL, symbol ID)` |
| `ADDRESS_GLOBAL` | global symbol | ordinary pointer to stored type | none | `(NONE, 0)` |
| `LOAD_INDIRECT` | pointer value | pointee type | `READ` | `(UNIVERSAL, 0)` |
| `STORE_INDIRECT` | pointer value, stored value | none | `WRITE` | `(UNIVERSAL, 0)` |
| `ADDRESS_FIELD` | aggregate pointer plus field auxiliary | pointer to field type | none | `(NONE, 0)` |
| `AGGREGATE_BUILD` | ordered field values | aggregate value | none | `(NONE, 0)` |
| `AGGREGATE_COPY` | destination pointer, source pointer | destination pointer | `READ + WRITE` | `(UNIVERSAL, 0)` |
| `LOAD_UNION_TAG` | tagged-union pointer | declared tag type | `READ` | `(UNIVERSAL, 0)` |
| `SET_UNION_VARIANT` | tagged-union pointer plus field auxiliary | none | `WRITE` | `(UNIVERSAL, 0)` |

Local operands use `OPERAND_KIND/LOCAL`; global operands use
`OPERAND_KIND/SYMBOL`; every other operand is a `VALUE`. Operand auxiliary is
zero except on `ADDRESS_FIELD`, `AGGREGATE_BUILD`, and `SET_UNION_VARIANT`,
where it is a one-based field ID. A global operand must name a symbol whose kind
is `GLOBAL`, not merely an arbitrary symbol with a compatible type.

Storage normally requires exact type identity. The sole representation bridge
is between two equal-size, equal-signedness integer types when either side has
`GC_KIND/HANDLE`. This permits the frontend's explicit managed-handle slot
boundary without allowing arithmetic or conversion operations to manufacture a
handle. Loads always return the exact declared local, global, or pointee type.

Address formation has one canonical decomposition. Pointer indexing is scalar
`ADD` and therefore uses the scalar pointer-scaling rule. Each member step is a
separate `ADDRESS_FIELD` whose input pointer's pointee owns the named field and
whose result is an ordinary pointer to that field's exact type. Indirect
load/store has no fused byte-offset field. Nested paths compose these operations
in order; a later MIR may fold them after verification, but RSIR never carries a
frontend-selected displacement or direct-code fragment.

`AGGREGATE_BUILD` constructs a by-value aggregate. A struct has exactly one
operand for every owned field in ordinal order. A raw or tagged union has
exactly one operand, and that operand's auxiliary field ID selects the active
variant. `AGGREGATE_COPY` requires two values with the exact same pointer type,
whose pointee is a struct or union, and returns that same destination pointer
type. Its runtime semantics are overlap-safe, equivalent to `memmove`; neither
size, frame placement, ABI class, nor alignment hints are serialized.

Tagged-union state is explicit. `LOAD_UNION_TAG` accepts only a pointer to a
`TAGGED` union and returns the union record's declared tag type.
`SET_UNION_VARIANT` accepts a field owned by that same union and updates only the
active tag; it does not address, initialize, or clear the payload. A frontend
union payload write is represented by the explicit tag update followed by
`ADDRESS_FIELD` and a typed store. `ADDRESS_FIELD` has no hidden tag side effect,
and payload reads remain unchecked unless the frontend emits
`LOAD_UNION_TAG` and an explicit comparison/control-flow check.

Effects are exact. `VOLATILE` may be added only to local, global, or indirect
loads/stores and to the two union-tag operations. It preserves the base
`READ`/`WRITE` effect and ordering requirement but does not imply atomicity.
`AGGREGATE_COPY` deliberately rejects `VOLATILE` in v1 because one instruction
bit cannot state whether the source, destination, or both are volatile.
Address formation and aggregate construction are pure.

Both readers first run the scalar verifier into private output structs, then
check owned instructions in table order, and publish all lower views only after
complete success. The shared corpus contains two valid modules and 26 directed
malformed modules covering every memory/aggregate status, nested scalar errors,
exact section/byte locations, volatile forms, nested field paths, handles,
tagged unions, and poisoned native outputs. Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-memory-aggregate-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-memory-aggregate-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-memory-aggregate-reds-test.exe `
    tools\self_hosting\tests\wire-memory-aggregate-reds-test.reds
build\self-hosting\wire-memory-aggregate-reds-test.exe
```

### Atomic operations

`compiler/wire-atomic.red` and `system/codegen/wire-atomic.reds` consume the
verified scalar tables and independently validate opcodes 32 through 36. They
construct no MIR, call neither `machine-ir/verify-current` nor the legacy
emitter, and produce no direct or machine-code bytes. Atomic instructions use
the common instruction and operand tables; v1 adds no atomic section and
serializes no target instruction choice.

The instruction `FLAGS` field is opcode-specific. Its low three bits contain
one `ATOMIC_ORDER` value directly, selected with `ATOMIC_FLAG/ORDER_MASK` (7).
`ATOMIC_FLAG/RETURN_OLD` (8) is the only additional bit. `ATOMIC_RMW` uses its
`SUBOPCODE` for one of `ADD`, `SUBTRACT`, `BIT_AND`, `BIT_OR`, or `BIT_XOR`;
every other atomic opcode has subopcode zero. `INSTRUCTION_FLAG/CHECKED` has no
meaning on an atomic instruction.

Legal orders are:

| Opcode family | Legal `ATOMIC_ORDER` values |
| --- | --- |
| `ATOMIC_LOAD` | `RELAXED`, `ACQUIRE`, `SEQUENTIAL` |
| `ATOMIC_STORE` | `RELAXED`, `RELEASE`, `SEQUENTIAL` |
| `ATOMIC_RMW`, `ATOMIC_CAS` | all five values |
| `ATOMIC_FENCE` | `ACQUIRE`, `RELEASE`, `ACQUIRE_RELEASE`, `SEQUENTIAL` |

A relaxed fence is invalid because it creates no synchronization event. The
single CAS order is its success order. Codegen derives the failure order:
`RELEASE` becomes `RELAXED`, `ACQUIRE_RELEASE` becomes `ACQUIRE`, and the other
three orders remain unchanged. The current `system/atomic` source forms emit
`SEQUENTIAL`; the complete wire domain is frozen so later source syntax does
not require a schema redesign.

Every memory operand is a `VALUE`, has auxiliary zero, and uses one exact
ordinary pointer to a canonical signed i32. The pointee has size and alignment
four, `SIGNED`, and `GC_KIND/NONE`. Stored, RMW, expected, and desired values
have that exact pointee type. A source pointer with another pointee type must be
made explicit with a legal scalar conversion or bitcast before the atomic
instruction; codegen never guesses the access width from source spelling.

| Opcode | Operands | Result | Exact effect |
| --- | --- | --- | --- |
| `ATOMIC_LOAD` | address | signed i32 | `READ + ATOMIC` |
| `ATOMIC_STORE` | address, value | none | `WRITE + ATOMIC` |
| `ATOMIC_RMW` | address, value | optional signed i32 | `READ + WRITE + ATOMIC` |
| `ATOMIC_CAS` | address, expected, desired | optional logic success value | `READ + WRITE + ATOMIC` |
| `ATOMIC_FENCE` | none | none | `ATOMIC` |

All five opcodes use alias `(UNIVERSAL, 0)`, including a fence. `VOLATILE` is
rejected because `ATOMIC` already states the stronger observable operation;
unknown, trap, call, stack, control, and opaque effects are rejected too.
`ATOMIC_LOAD` keeps one SSA result even when the source expression discards it,
because the atomic read itself remains observable. CAS may omit its success
result. An RMW with a result returns the pre-operation value when `RETURN_OLD`
is set and the post-operation value otherwise. An unused RMW has no result and
must clear `RETURN_OLD`, canonicalizing the unobservable source refinement.

The frontend guarantees that every runtime address is naturally four-byte
aligned. That fact follows from the canonical pointee layout and is not repeated
as an unprovable operand hint. The verifier checks the pointer and pointee type;
it cannot prove an arbitrary runtime pointer value. Native codegen may assume
the producer contract and need not synthesize a bytewise or lock-based fallback
for a misaligned address.

Both readers run the scalar verifier into private outputs, scan owned
instructions in table order, and publish lower views only after complete
success. The shared corpus contains two valid modules and 21 directed malformed
modules. It covers all 17 atomic status codes, every RMW operation, every legal
order family, old/new/unused results, exact effects and aliases, nested scalar
errors, exact section/byte locations, and poisoned native outputs. Run both
implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-atomic-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-atomic-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-atomic-reds-test.exe `
    tools\self_hosting\tests\wire-atomic-reds-test.reds
build\self-hosting\wire-atomic-reds-test.exe
```

### Control flow

`compiler/wire-control-flow.red` and
`system/codegen/wire-control-flow.reds` consume the verified scalar tables and
independently validate the block/edge graph plus the branch, jump, switch,
return, and unreachable terminators. They do not construct MIR, call the
legacy `machine-ir/verify-current`, invoke the emitter, or produce direct or
machine-code bytes.

The edge section has zero flags. Every edge word is first decoded as a
signed-31-bit scalar. Source and target are nonzero blocks in the same function;
edge flags are zero. `SWITCH_CASE` alone has a nonzero selector constant, while
all other accepted kinds have selector zero. `EDGE_KIND_UNREACHABLE` remains a
reserved schema value and is rejected in v1.

Block edge slices partition the complete edge table in block order. An empty
slice is `(0, 0)`; a nonempty slice starts at the next unowned edge. Every edge
in the slice names that source block and has its zero-based slice ordinal.
Ordinary edges precede an optional suffix of `EXCEPTION` edges. The ordinary
prefix must exactly mirror the final terminator. Exception source regions,
handler targets, stack state, and `THROW` operands/effects belong to the later
exception contract; this layer admits the suffix without assigning those
missing semantics.

Every block is nonempty and contains exactly one terminator as its final
instruction. An earlier terminator is invalid. The owned terminators have
subopcode zero, instruction flags zero, no results, exact `CONTROL` effect, and
alias `(NONE, 0)`. Their operands and ordinary edge prefixes are:

| Terminator | Operands | Ordinary edges |
| --- | --- | --- |
| `JUMP` | `BLOCK target` | one `NORMAL` edge to target |
| `BRANCH` | `VALUE logic`, `BLOCK true`, `BLOCK false` | `TRUE`, then `FALSE`, to those targets |
| `SWITCH` | ordinary integer value, one or more `(CONSTANT, BLOCK)` cases, final `BLOCK` default | one `SWITCH_CASE` per case, then `DEFAULT` |
| `RETURN` | none for `VOID`, otherwise one exact return-typed `VALUE` | none |
| `UNREACHABLE` | none | none |

Switch case constants have the selector's exact ordinary integer type. Cases
remain in source order, and each case edge repeats the operand's constant ID.
Two cases with the same fixed-width byte value are invalid even when they use
different constant records or one uses canonical `ZERO`; no sorting or target
jump-table decision is serialized. A signature with `NO_RETURN` rejects every
`RETURN`. `THROW` is recognized as a final terminator and must have no ordinary
edge, but its complete shape is intentionally deferred to exception
verification.

Parameter values dominate every block in their function. An instruction value
used in the same block must be defined by an earlier instruction. Across
blocks, its definition block must dominate the use in the ordinary CFG. The
dominance graph has a synthetic root whose successors are the declared entry
block and every block with zero ordinary in-degree. This treats detached
unreachable continuations and exception-only handlers conservatively as roots.
A closed detached cycle has no such root and is rejected, preventing vacuous
dominance. Non-dominating branch merges use explicit typed mutable or `MERGE`
locals; RSIR serializes no phi nodes, predecessor lists, dominator sets, or
optimizer state.

The native verifier is allocation-free and accepts caller-owned writable
scratch. It requires at least one byte for every block in the module, indexed by
global block ID, and may overwrite all those bytes. Null scratch or a negative
size is `INVALID_ARGUMENTS`; a smaller nonnull buffer reports
`INSUFFICIENT_WORKSPACE` after local wire/terminator checks and before graph
closure. The Red verifier owns its temporary marks internally, so this status
is native-call state rather than malformed RSIR.

Both readers stop at the same first semantic error and publish all lower and
control views only after complete success. The shared corpus contains three
valid modules and 34 directed malformed modules covering control errors 1
through 35, exact byte locations, edge partitions, every terminator shape,
switch duplicates, virtual roots, direct-value dominance, deferred exception
forms, and poisoned native outputs. The native test additionally covers error
36 and every null output pointer. Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-control-flow-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-control-flow-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-control-flow-reds-test.exe `
    tools\self_hosting\tests\wire-control-flow-reds-test.reds
build\self-hosting\wire-control-flow-reds-test.exe
```

### Calls and Win64 ABI

`compiler/wire-call-abi.red` and
`system/codegen/wire-call-abi.reds` consume the verified control-flow tables
and freeze the logical call contract. They do not lower arguments to registers,
insert a hidden return pointer, or serialize stack/shadow-space facts. Those
facts are derived by native codegen from the canonical type layout and the
signature at the call site. The verifier chain currently accepts only
`X86_64`, `WIN64`, little-endian, eight-byte-pointer messages. Data-layout
verification rejects every other header before call validation; the call reader
repeats those checks defensively.

Every `CALL` instruction owns exactly one `RSIR_CALL` record, and every call
record names a `CALL` instruction. The records are sorted by instruction ID and
cover the complete CALL opcode set. `RSIR_CALL/CALLEE_REFERENCE` is an operand
ID, not a function/import index. It must be the first operand of the CALL
instruction; `FIRST_ARGUMENT_OPERAND` and `ARGUMENT_COUNT` describe the suffix
after that descriptor. An empty argument suffix is `(0, 0)`. Argument operands
are logical source values, never ABI-expanded slots or a hidden return pointer.

The descriptor operand kind is the target-domain discriminator:

| Call kind | Descriptor kind and reference | Required target |
| --- | --- | --- |
| `DIRECT` | `SYMBOL`, function symbol ID | local/internal/external/weak function symbol, not an import |
| `IMPORT` | `SYMBOL`, imported function symbol ID | exactly one matching import record |
| `INDIRECT` | `VALUE`, value ID | `FUNCTION` type whose detail is the call signature |
| `SYSCALL` | `CONSTANT`, constant ID | signed i32 syscall number, nonnegative |
| `SUBROUTINE` | `SUBROUTINE`, subroutine ID | same-host subroutine with the declared effective signature |

`CALL_KIND_CUSTOM` is reserved and rejected. Custom forwarding is a signature
mode (`FUNCTION_FLAG/CUSTOM`) that uses one ordinary signed-i32 count operand
and the `STACK` effect; the values already pushed by explicit stack operations
are not duplicated in the call slice. `CALL_KIND_SUBROUTINE` instead uses a
`SUBROUTINE` descriptor operand and no logical argument operands in v1; the
subroutine verifier checks host ownership and exact signature identity. This
keeps target provenance and dynamic forwarding orthogonal and supports direct,
imported, and indirect custom targets without a second target encoding.

The call record itself has zero flags and reserved words. A CALL has subopcode
zero, instruction flags zero, one result exactly when the signature return type
is non-`VOID`, and a result type exactly equal to that return type. Its alias is
`(UNIVERSAL, 0)`. Calls conservatively require `CALL | READ | WRITE |
MAY_TRAP | SAFEPOINT`; a custom call additionally requires `STACK`, and a
signature marked `MAY_THROW` additionally requires `THROW`. Unknown effect bits,
`CONTROL`, `ATOMIC`, `VOLATILE`, and `OPAQUE` are rejected. A non-throwing
signature may not claim `THROW`.

Fixed calls have exactly the signature parameter count and exact canonical
argument types. `CDECL VARIADIC` calls have at least the named prefix; the
prefix is exact and each tail value is non-`VOID` (a `float32` tail must already
be promoted to the canonical 64-bit float). Private `VARIADIC` and `TYPED`
calls carry any number of packable scalar/pointer/function values. `CUSTOM`
calls carry exactly one signed-i32 count; a statically known negative count is
invalid. Aggregate values are legal for fixed and C-variadic calls, but never
for packed typed/private-variadic protocols.

For the Windows x64 header (`X86_64` + `WIN64`), scalar, pointer, and function
values occupy one ABI slot. A by-value struct/union of size 1, 2, 4, or 8 is an
integer-class slot; larger external-ABI aggregates are passed indirectly by a
codegen-created temporary. The same external rule makes a return aggregate
larger than 8 bytes a hidden-return-pointer case. No such physical decision is
written into RSIR, and the semantic result remains the canonical aggregate
type. Syscalls accept only logic, integer, or pointer arguments and returns.
Callback bits are checked through the target signature and remain valid only
for CDECL/STDCALL function types; indirect callback calls use the same exact
signature rule.

Both readers first run the control-flow verifier, then apply these call rules
with failure-atomic output views. The corpus covers direct runtime symbols,
imports, indirect and callback values, syscalls, scalar and aggregate
Win64-return/argument classes, C and private variadics, typed calls, and direct,
imported, and indirect custom calls. It deliberately does not invoke
`machine-ir/verify-current`, the legacy emitter, or any direct-code path.

Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-call-abi-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-call-abi-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-call-abi-reds-test.exe `
    tools\self_hosting\tests\wire-call-abi-reds-test.reds
build\self-hosting\wire-call-abi-reds-test.exe
```

### Subroutines

`compiler/wire-subroutine.red` and `system/codegen/wire-subroutine.reds`
consume the verified call/ABI and control-flow views. They model named
Red/System subroutines as additional execution roots inside one host function;
they do not serialize copied prologs, frame offsets, selected instructions, or
machine bytes.

The `subroutines` and `subroutine-blocks` sections have zero flags. Subroutine
records are ordered by host function and then by strictly increasing entry
block. Names are nonempty and unique within a host. Every subroutine owns one
nonempty contiguous membership slice, the slices partition the membership
table, members are strictly ordered, and a block belongs to at most one
subroutine. A host function's blocks outside those slices form its main
execution region.

The host entry and each subroutine entry are distinct CFG roots. A subroutine
entry has no ordinary incoming edge, every member is reachable from that entry,
and an ordinary edge stays wholly inside host-main or one subroutine region.
Calls are the only transfer into a subroutine and are not represented as CFG
edges. A `SUBROUTINE` call must target a subroutine owned by the caller's host,
name its exact effective signature, and have no logical arguments. Direct self
recursion is rejected; calls between different subroutines, including mutual
recursion, are valid. A `SUBROUTINE` operand is legal only as that call's callee
descriptor, so v1 has no subroutine address-taking convention.

An effective subroutine signature uses the `RED_SYSTEM` convention, has no
parameters or logical arity, and may carry only `MAY_THROW`. Its return is
`VOID` or a nonaggregate canonical type. `SUBROUTINE_RETURN` has zero
subopcode, flags, and results, exact `CONTROL` effect, and alias `(NONE, 0)`.
It has no operand for `VOID` or one auxiliary-zero `VALUE` operand of the exact
return type otherwise, has no outgoing edges, and is legal only in the matching
subroutine region. Every declared subroutine has at least one such return.

The shared Red and Red/System corpus covers empty, single and multiple roots,
typed returns, mutual recursion, all 27 status values, nested verifier errors,
exact byte locations, and failure-atomic output views. Run both implementations
with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-subroutine-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-subroutine-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-subroutine-reds-test.exe `
    tools\self_hosting\tests\wire-subroutine-reds-test.reds
build\self-hosting\wire-subroutine-reds-test.exe
```

### Exceptions

`compiler/wire-exception.red` and `system/codegen/wire-exception.reds` consume
the verified subroutine, call/ABI, control-flow, scalar, type, function, and
constant views. They validate exception regions and edges only; they construct
no MIR, call no legacy verifier or emitter, and produce no direct or
machine-code bytes.

The `exception-regions` and `exception-blocks` sections have zero flags. Every
record word is a signed-31-bit wire scalar. A region owns one nonempty,
contiguous slice of the complete membership table. Slices partition that table
in region order; each member repeats its region ID, names a non-entry block in
the same function, and is strictly ordered by block ID. A handler is a unique
block in the same function, is outside its own protected set, and has no
ordinary incoming edge.

Regions are ordered by function and then by their unique `CATCH_ENTER`
instruction. Two regions in one function are either disjoint or strictly
nested; partial overlap is invalid. The handler of an inner region is inside
exactly every proper outer region and no other region. A `FUNCTION` region may
not overlap another region. These rules make reverse region order the canonical
innermost-to-outermost handler order without serializing a second nesting tree.

`CATCH_ENTER` and `CATCH_LEAVE` have subopcode, flags, and result count zero,
exact `CONTROL` effect, and alias `(NONE, 0)`. Their first operand is `BLOCK`
and names the region's handler; every catch operand has auxiliary zero.

| Region/instruction | Remaining operands | Required region flag |
| --- | --- | --- |
| `FILTER` `CATCH_ENTER` | one signed-i32 `VALUE` threshold | `CATCH_ALL` exactly when the value is a direct scalar constant with raw bytes `FFFFFFFF` (`-1`) |
| `FUNCTION` `CATCH_ENTER` | none | `CATCH_ALL` |
| either `CATCH_LEAVE` | none | unchanged |

A dynamic or non-`-1` filter is not guaranteed to catch and therefore clears
`CATCH_ALL`, even if it may evaluate to `-1` at runtime. `FUNCTION` carries no
threshold operand. It represents the source `[catch]` attribute, so codegen
derives its internal `FFFFFFFEh` threshold and resumes after the throwing call;
the runtime-only `FFFFFFFFh` root catch value is not serialized as that
threshold.

Every entry is the penultimate instruction of a two-instruction preheader and
is followed by `JUMP` from outside the region to a member block. An ordinary
edge may enter only that one region from its matching preheader. An ordinary
edge that exits regions enters a distinct leave block whose prefix contains
exactly one `CATCH_LEAVE` per exited region, innermost first. Extra, late, or
misordered leaves are invalid, as are a mixed enter/exit edge, entry into two
regions at once, or `RETURN` from inside a protected region. Every protected
member has an ordinary predecessor from its region, its entry preheader, or, for
a nested handler, the corresponding proper inner region.

A `FUNCTION` region has one protected member block containing exactly one
void-result throwing `CALL` followed by `JUMP`. Its entry preheader has two
instructions. Its distinct normal-leave and handler blocks each contain
`CATCH_LEAVE` followed by `JUMP`, and both jumps name the same continuation.
This is the complete v1 `[catch]` call wrapper; it does not encode legacy frame
offsets or copied prolog/epilog bytes.

`THROW` has subopcode and flags zero, no result, and one auxiliary-zero `VALUE`
operand of canonical signed-i32 type. Its exact effects are `CONTROL | THROW |
WRITE`, and its alias is `(UNIVERSAL, 0)`. It is the final terminator. A throwing
`CALL` is immediately before its block terminator. A block contains at most one
instruction with `THROW` effect.

The exception edges of a throwing block are the suffix after its ordinary
edges. Their targets list active handlers innermost to outermost and stop at the
first `CATCH_ALL` region. A block with no throwing instruction has no exception
edge. If no active catch-all exists, the owning signature must declare
`MAY_THROW`; for a subroutine block this is the subroutine's effective
signature rather than the host signature. A throwing call is limited in v1 to
`DIRECT`, `INDIRECT`, or same-host `SUBROUTINE` with a `RED_SYSTEM` signature.
Imported, syscall, C-ABI, and custom throw paths are rejected rather than
assigned an implicit unwind convention.

An exception region is wholly inside one execution region: host-main or one
subroutine. Its protected blocks and handler may not cross that boundary.
Consequently, a subroutine may catch locally or propagate through a
`MAY_THROW` effective signature without introducing an ordinary CFG edge to
the caller.

A signature cannot combine `CALLBACK` and `MAY_THROW`. A callback may still
contain exceptions that are fully caught before its external boundary. A
function with any region, catch/throw instruction, or `THROW` effect may not
contain `STACK_ALLOC` through `POP_ALL`; a throwing call may not carry the
`STACK` effect. This conservative v1 rule prevents a catch from bypassing an
unserialized dynamic stack state. The explicit-stack verifier retains this
function-wide exclusion even though stack joins are now independently checked.

The native reader is allocation-free and reuses the control-flow reader's
caller-owned workspace of at least one byte per block; exception verification
requires no additional bytes. Both readers stop at the same first error and
publish all lower plus exception views only after complete success. The shared
corpus contains four valid modules and 55 directed malformed modules. Together
with success and invalid arguments it covers all 54 exception status values,
exact nested errors and byte locations, region nesting and boundaries, handler
edge order, both `FUNCTION` overlap and shape failures, poisoned outputs, and
null native arguments.

Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-exception-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-exception-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-exception-reds-test.exe `
    tools\self_hosting\tests\wire-exception-reds-test.reds
build\self-hosting\wire-exception-reds-test.exe
```

### Explicit stack

`compiler/wire-stack.red` and `system/codegen/wire-stack.reds` consume the
verified exception and subroutine views. This is a protocol verifier and
abstract-state pass only: it emits no MIR, direct bytes, or machine code, and
it does not call `machine-ir/verify-current` or the legacy emitter.

All counts are target stack slots, not bytes. On Windows x64 one slot is eight
bytes. The v1 instruction shapes are:

| Opcode | Subopcode | Operands | Results | Exact effects |
| --- | --- | --- | --- | --- |
| `STACK_ALLOC` | `UNINITIALIZED` or `ZEROED` | one auxiliary-zero `VALUE` or `CONSTANT`, canonical signed i32 slot count | pointer to canonical signed i32 | `STACK` |
| `STACK_FREE` | zero | one auxiliary-zero `VALUE` or `CONSTANT`, canonical signed i32 slot count | none | `STACK` |
| `STACK_PUSH` | zero | one auxiliary-zero `VALUE` or `CONSTANT` of logic, integer, float, pointer, or function type | none | `STACK` |
| `STACK_POP` | zero | none | canonical signed i32 | `STACK` |
| `PUSH_ALL` | zero | none | none | `STACK | OPAQUE` |
| `POP_ALL` | zero | none | none | `STACK | OPAQUE` |
| `STACK_TOP`, `STACK_FRAME` | zero | none | ordinary pointer to canonical signed i32 | `STACK` |

Every instruction has zero flags and alias `(NONE, 0)`. A statically known
negative count is invalid. Static knowledge includes both a direct constant and
a value produced by the canonical `CONSTANT` instruction; any other count is
dynamic rather than guessed.

The analysis domain at each block entry is an exact nonnegative slot depth or
dynamic depth, plus an optional active `PUSH_ALL` identity and its saved outer
state. Exact depth disagreement at a join widens to dynamic. Different active
save identities, or active versus inactive paths, are a hard state mismatch.
No stack or frame state is serialized in RSIR.

`STACK_ALLOC` and `STACK_PUSH` increase depth; `STACK_FREE`, `STACK_POP`, and a
custom call's explicit count decrease it. An unknown count makes the depth
dynamic. Ordinary calls leave this abstract depth unchanged. A standard ABI
call at nonzero depth is valid RSIR; native codegen is responsible for dynamic
call alignment and shadow space.

`PUSH_ALL` saves the outer state and starts an exact-zero relative region.
Nesting is rejected in v1. `POP_ALL` requires exact relative depth zero and
restores the saved state. Every terminal path rejects an active unmatched
save. Host-function termination may otherwise retain a nonzero or dynamic
relative depth because the generated function epilog restores the host stack;
`SUBROUTINE_RETURN` instead requires exact depth zero.

The native verifier is allocation-free. After the lower verifier chain it
reuses caller-owned workspace and requires exactly 24 bytes per block for this
pass; byte-wise little-endian state access permits an unaligned workspace.
Insufficient capacity is stack error 23. All output views remain poisoned until
the complete verification chain succeeds.

The shared corpus has six valid and 23 directed malformed modules. Red covers
all semantic statuses, while the native cases add exact, unaligned, and short
workspace checks so all 25 stack status values are exercised. Run both
implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-stack-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-stack-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-stack-reds-test.exe `
    tools\self_hosting\tests\wire-stack-reds-test.reds
build\self-hosting\wire-stack-reds-test.exe
```

### Windows x64 target intrinsics

`compiler/wire-target-intrinsic.red` and
`system/codegen/wire-target-intrinsic.reds` consume the complete explicit-stack
verification chain and validate the remaining Windows x64 target escapes. They
decode no fragment instruction bytes, construct no MIR, invoke neither
`machine-ir/verify-current` nor the legacy emitter, and emit no direct or
machine-code bytes.

The `target-fragments` section has zero flags. Its records are in instruction-use
order, match the message target and ABI exactly, and own consecutive nonempty
slices beginning at the constant verifier's `constant-data-owned-size`. Those
slices must cover the complete remaining `constant-data` suffix. A fragment
return type is `VOID`, `LOGIC`, `INTEGER`, `FLOAT`, `POINTER`, or `FUNCTION`;
aggregate returns are rejected. Every record has the exact effects `READ |
WRITE | MAY_TRAP | CONTROL | OPAQUE`, clobber class `WIN64_VOLATILE`, and a
valid source location.

Every fragment is referenced exactly once, in record order, by one
`TARGET_FRAGMENT` instruction with one auxiliary-zero `TARGET_FRAGMENT`
operand. The instruction repeats the descriptor's exact effects, uses alias
`(UNIVERSAL, 0)`, and has the same source location. A `VOID` fragment has no
result; every other allowed fragment has one result of the descriptor's exact
type. The absence of a `STACK` effect fixes the v1 stack-depth contract as
unchanged. Codegen must spill live values for `WIN64_VOLATILE` and respect the
opaque barrier before it may copy the verified bytes to its own native arena.
`WIN64_VOLATILE` invalidates RAX, RCX, RDX, R8-R11, XMM0-XMM5, and arithmetic
condition codes. The fragment must preserve RBX, RBP, RSI, RDI, R12-R15,
XMM6-XMM15, and its entry RSP value; changing that set requires a new clobber
class rather than reinterpretation of ID 1.

The other target-owned instruction shapes are:

| Opcode | Subopcode | Operands | Results | Exact effects and alias |
| --- | --- | --- | --- | --- |
| `PORT_READ` | zero | ordinary pointer to plain u8 or signed i32 | exact pointee value | `READ | VOLATILE | MAY_TRAP`, `(NONE, 0)` |
| `PORT_WRITE` | zero | the same legal pointer plus an exact-pointee value | none | `WRITE | VOLATILE | MAY_TRAP`, `(NONE, 0)` |
| `GET_PC` | zero | none | ordinary pointer to plain u8 | `OPAQUE`, `(NONE, 0)` |
| `CPU_REGISTER_READ` | `RAX` through `R15` | none | ordinary pointer to signed i32 | `OPAQUE`, `(NONE, 0)` |
| `CPU_REGISTER_WRITE` | `RAX` through `R15`, except `RSP` and `RBP` | ordinary pointer to signed i32 | none | `OPAQUE`, `(NONE, 0)` |

All rows have zero instruction flags. Non-fragment operands are auxiliary-zero
`VALUE` or `CONSTANT` references. Rejecting writes to `RSP` and `RBP` preserves
the abstract stack/frame state for native frame construction; reads remain
legal. `PORT_READ` and `PORT_WRITE` deliberately freeze only the source widths
present on Windows x64 rather than accepting an arbitrary integer size.

`SYSCALL` remains a `CALL_KIND`, so the lower call/ABI verifier owns its
nonnegative signed-i32 number, legal logic/integer/pointer types, logical
argument slice, and conservative call effects. The target verifier adds the
x64 limit of zero through six logical arguments. V1 accepts every nonnegative
signed-i32 syscall number; it carries no OS-version-specific allow-list.

The native verifier is allocation-free and reuses the caller-owned stack
workspace. Both implementations preserve poisoned output views until the full
lower and target chain succeeds. The shared corpus has three valid and 31
directed malformed modules and, with success and invalid arguments, covers all
33 target-intrinsic status values, nested failures, exact byte locations,
constant/fragment data ownership, every target opcode, and native workspace
boundaries. Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-target-intrinsic-test.red
D:\EE\QTool\red-console.exe `
    tools\self_hosting\generate-wire-target-intrinsic-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-target-intrinsic-reds-test.exe `
    tools\self_hosting\tests\wire-target-intrinsic-reds-test.reds
build\self-hosting\wire-target-intrinsic-reds-test.exe
```

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
  definition; non-dominating merge values pass through typed mutable/merge
  slots;
- instruction operands/results and constant parts satisfy opcode type rules;
- call arguments match the signature, including variadic, typed, custom,
  callback, indirect-call, and aggregate-return attributes;
- aggregate fields have canonical natural offsets and sizes; initializer parts
  fit that verified type layout without overlap;
- effect/alias annotations agree with the opcode and cannot understate a call,
  volatile access, atomic, trap, throw, or safepoint;
- explicit stack joins preserve compatible save identities, exact depth
  conflicts widen to dynamic, and subroutine returns restore exact depth zero;
- pointer GC identity changes only through an explicit address conversion;
  handle GC identity is never created, removed, or disguised by conversion;
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
| 12 | file-checksum-data | 1 | raw source checksum bytes |
| 13 | debug-lines | 20 | function-relative code positions |
| 14 | debug-parameters | 16 | runtime argument type metadata |
| 15 | gc-frames | 24 | final frame bitmap location and flags |
| 16 | modules | 32 | input-module lifecycle and symbol ownership |
| 17 | unwind-functions | 24 | optional platform unwind record ranges |

Record shapes:

- `output-sections`: name string, class, flags, alignment, data offset, file
  size, memory size, reserved. BSS has file size zero. Platform sections allow
  later `.pdata`, `.xdata`, `.eh_frame`, and similar data without changing the
  container model.
- `symbols`: name string, kind, binding, visibility, output section, section
  offset, size, alignment, flags, origin-module ID. Section zero denotes an
  absolute or unresolved symbol as determined by flags.
- `modules`: optional name string, module kind, image kind, initializer/finalizer/
  entry symbol IDs, zero flags, and zero reserved word. The section is required
  and nonempty. RSCG contains one record for every merged RSIR/object input in
  merge order; symbol `origin-module` and lifecycle symbol IDs are one-based
  references into this table. All module image kinds must agree, and at most one
  `GLUE` module may own an entry. After standalone objects have been merged, an
  executable requires that glue entry and the adapter must not fall back to the
  legacy start-of-CODE default. An entryless DLL remains valid; when a DLL entry
  exists, the sole glue module owns it.
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
required order and owns the final `***_start` or runtime-enabled DLL entry
symbol. Lifecycle fields make those functions discoverable and auditable;
neither the merger nor linker derives hidden calls or ordering from module-table
position.
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

RSDG is a failure result, not a successful-compilation log. A successful
`codegen-module` call returns `WIRE_STATUS_SUCCESS` and leaves the diagnostics
binary empty. When detailed diagnostics are enabled, a nonzero return may
append one complete RSDG message. `max-diagnostic-bytes = 0` permits a nonzero
status without that message.

The `strings` section carries exactly SORTED and DEDUPLICATED, while
`string-data` and `diagnostics` carry zero flags. Diagnostic records remain in
producer order; they are neither sorted nor deduplicated because a primary
error followed by its notes is an ordered causal sequence. Every 40-byte record
contains status, severity, phase, message string ID, file ID, line, column,
function symbol ID, instruction ID, and presence flags.

The first record is the primary diagnostic and has ERROR or FATAL severity.
Later records may use NOTE, WARNING, ERROR, or FATAL. Every record has the same
nonzero status, and that status equals the routine return. SUCCESS is invalid
inside RSDG. Each message string ID is in range and names a nonempty canonical
UTF-8 string. Status and phase combinations are restricted as follows:

| Status | Permitted phases |
| --- | --- |
| `INVALID_ARGUMENTS` | BRIDGE |
| `INVALID_CONFIGURATION` | CONFIGURATION |
| `INVALID_RSIR` | DECODE, VERIFY |
| `UNSUPPORTED_TARGET` | CONFIGURATION, DECODE, VERIFY, SELECT, ENCODE |
| `CODEGEN_FAILURE` | OPTIMIZE, SELECT, ALLOCATE, ENCODE |
| `INVALID_ARTIFACT` | ARTIFACT |

Context uses four presence bits. A field governed by an absent bit is zero; a
field governed by a present bit is nonzero.

| Flag | Fields and dependency |
| --- | --- |
| FILE | `file`; a file-only diagnostic leaves line and column zero |
| SOURCE | `line` and `column`, both at least 1; requires FILE |
| FUNCTION | `function-symbol` |
| INSTRUCTION | `instruction`; requires FUNCTION |

Any record with context flags requires a nonzero target tuple in the RSDG
header. File, function, and instruction values are references into the input
RSIR, not tables copied into RSDG. The standalone RSDG verifier checks their
presence representation. The later bridge/RSIR verifier checks file bounds,
that a function symbol denotes the owning function, and that an instruction ID
exists in that function. This separation lets diagnostics report an RSIR that
failed before all of those tables could be trusted.

`compiler/wire-diagnostics.red` and
`system/codegen/wire-diagnostics.reds` implement the semantic checks
independently. The native verifier is allocation-free and changes its string
and diagnostic views only after complete success. The shared corpus covers nine
valid messages and 30 malformed messages, including every diagnostic error,
nested container/string failures, exact error locations, scalar validation
precedence, producer order, all context dependencies, and poisoned outputs on
failure. Run both implementations with:

```powershell
D:\EE\QTool\red-console.exe tools\self_hosting\tests\wire-diagnostics-test.red
D:\EE\QTool\red-console.exe tools\self_hosting\generate-wire-diagnostic-fixtures.red
build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe -r -d `
    -t Windows-X86-64 `
    -o build\self-hosting\wire-diagnostics-reds-test.exe `
    tools\self_hosting\tests\wire-diagnostics-reds-test.reds
build\self-hosting\wire-diagnostics-reds-test.exe
```

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
