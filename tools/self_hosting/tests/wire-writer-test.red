Red [
	Title: "Hybrid compiler Red wire writer tests"
]

do %../../../compiler/wire-rscf.red
do %../../../compiler/wire-writer.red

schema: compiler-wire-schema
writer-api: compiler-wire-writer

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

writer: writer-api/new
	schema/WIRE_MAGIC_RSCF
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 1 160 160
assert writer/error = writer-api/ERROR-SUCCESS "valid writer initialization failed"
assert (writer-api/start-section writer schema/WIRE_RSCF_SECTION_CONFIG 0)
	= writer-api/ERROR-SUCCESS "config section start failed"
assert (writer-api/words writer [
	0 0 1 1 0 1 0 0 1048576 65536 1 0 0 0 0 0
]) = writer-api/ERROR-SUCCESS "config payload write failed"
assert (writer-api/end-section writer) = writer-api/ERROR-SUCCESS
	"config section end failed"
assert (writer-api/finish writer) = writer-api/ERROR-SUCCESS "writer finish failed"
assert (length? writer/output) = 160 "writer did not honor the exact measured size"
result: compiler-wire-rscf/verify writer/output
assert result/valid? ["writer produced invalid RSCF: " result/error]

limited: writer-api/new
	schema/WIRE_MAGIC_RSCF
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 1 159 159
assert (writer-api/start-section limited schema/WIRE_RSCF_SECTION_CONFIG 0)
	= writer-api/ERROR-SUCCESS "bounded writer section start failed"
assert (writer-api/words limited [
	0 0 1 1 0 1 0 0 1048576 65536 1 0 0 0 0 0
]) = writer-api/ERROR-LIMIT "bounded writer did not reject overflow"
assert (length? limited/output) <= 159 "bounded writer exceeded its limit"

misaligned: writer-api/new
	schema/WIRE_MAGIC_RSCF
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 1 160 160
assert (writer-api/start-section misaligned schema/WIRE_RSCF_SECTION_CONFIG 0)
	= writer-api/ERROR-SUCCESS "misalignment test section start failed"
assert (writer-api/bytes misaligned #{00}) = writer-api/ERROR-SUCCESS
	"misalignment test byte write failed"
assert (writer-api/end-section misaligned) = writer-api/ERROR-RECORD-SIZE
	"writer accepted a partial record"

empty-bytes: writer-api/new
	schema/WIRE_MAGIC_RSIR
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 schema/WIRE_RSIR_REQUIRED_SECTION_COUNT 1152 1152
assert (writer-api/start-section empty-bytes schema/WIRE_RSIR_SECTION_MODULE 0)
	= writer-api/ERROR-SUCCESS "empty byte test section start failed"
assert (writer-api/bytes empty-bytes #{}) = writer-api/ERROR-SUCCESS
	"empty byte append failed"
assert empty-bytes/section-start = -1
	"empty byte append created a nonempty section"

wrong-order: writer-api/new
	schema/WIRE_MAGIC_RSIR
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 schema/WIRE_RSIR_REQUIRED_SECTION_COUNT 1152 1152
assert (writer-api/start-section wrong-order schema/WIRE_RSIR_SECTION_DATA_LAYOUT 0)
	= writer-api/ERROR-SECTION "writer accepted a skipped required section"

wrong-flags: writer-api/new
	schema/WIRE_MAGIC_RSIR
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 schema/WIRE_RSIR_REQUIRED_SECTION_COUNT 1152 1152
assert (writer-api/start-section wrong-flags schema/WIRE_RSIR_SECTION_MODULE
	schema/WIRE_SECTION_FLAG_OPTIONAL)
	= writer-api/ERROR-FLAGS "writer accepted OPTIONAL on a required section"

unfinished: writer-api/new
	schema/WIRE_MAGIC_RSIR
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8 schema/WIRE_RSIR_REQUIRED_SECTION_COUNT 1152 1152
assert (writer-api/finish unfinished) = writer-api/ERROR-FINISH
	"writer accepted an incomplete directory"

print "PASS: Red wire container writer"
