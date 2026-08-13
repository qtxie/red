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

In v1.0, all 29 listed RSIR sections are required even when empty. RSCF requires
its config section. RSCG requires kinds 1 through 15; kind 16
`unwind-functions` is known optional and carries the OPTIONAL flag when present.
RSDG requires all three listed sections to be nonempty, including at least one
string, one byte of string data, and one diagnostic record. Its smallest valid
v1 message is therefore 212 bytes.

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
two forward-compatibility positives, 38 directed malformed cases, and every
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

The first v1 backend accepts only this target configuration:

- header tuple `X86_64`, `WIN64`, `LITTLE`, pointer size 8;
- optimization level `O0`, `O1`, or `O2`;
- the four defined config flag bits and no others;
- code model `SMALL`, relocation model `STATIC` or `PIC`, and debug format
  `NONE` or `RED`;
- CPU baseline `X86_64_BASE`.

The config feature masks must equal the header feature masks. Both masks are
zero in v1 until individual x86-64 feature bits and their legality rules are
specified; a matching nonzero pair is therefore unsupported rather than
silently ignored. `DEBUG` is set exactly when the debug format is `RED`, and
`PIC` is set exactly when the relocation model is `PIC`. `DETERMINISTIC` and
`RUNTIME_MODULE` are accepted independently. Worker count is 1, deterministic
seed is 0, and all four reserved words are zero.

`max-output-bytes` is at least `WIRE_RSCG_MINIMUM_SIZE` (currently 576).
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
| 13 | constant-data | 1 | raw scalar and aggregate bytes |
| 14 | constant-parts | 32 | nested values and symbolic address parts |
| 15 | globals | 32 | storage class and initializer |
| 16 | imports | 24 | library/external name/symbol mapping |
| 17 | exports | 16 | external name/symbol/ordinal mapping |
| 18 | functions | 40 | signature and owned record ranges |
| 19 | locals | 32 | arguments, locals, temporaries, GC kind |
| 20 | blocks | 32 | instruction and outgoing-edge ranges |
| 21 | edges | 24 | source, target, edge kind, case value |
| 22 | values | 24 | typed single-definition temporary results |
| 23 | instructions | 48 | opcode, results, operands, effects, source |
| 24 | operands | 16 | typed references with opcode-specific aux |
| 25 | calls | 32 | callee, signature, call attributes |
| 26 | target-fragments | 32 | target-bound `#inline` byte slices |
| 27 | source-locations | 16 | file, line, column, byte offset |
| 28 | exception-regions | 24 | protected set, handler, and semantics |
| 29 | exception-blocks | 8 | region-to-block membership |

The important record shapes are:

- `module`: name string, flags, initializer function, finalizer function, entry
  function, initialization priority, source location, reserved. Runtime, user,
  and startup-glue modules therefore expose composable lifecycle functions.
- `types`: kind, flags, size, alignment, reserved, kind-specific detail ID,
  reserved, first field, field count, GC kind. Signedness is a type flag;
  source names and aliases are not part of a representation record.
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
- aggregate fields have canonical natural offsets and sizes; initializer parts
  fit that verified type layout without overlap;
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
| 12 | file-checksum-data | 1 | raw source checksum bytes |
| 13 | debug-lines | 20 | function-relative code positions |
| 14 | debug-parameters | 16 | runtime argument type metadata |
| 15 | gc-frames | 24 | final frame bitmap location and flags |
| 16 | unwind-functions | 24 | optional platform unwind record ranges |

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
